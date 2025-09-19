# ⚠️ Crosscutting Concerns: Manejo de Errores

El manejo de errores es un aspecto transversal de la aplicación que asegura que **todas las excepciones** se gestionen de forma consistente, registren un log con su `requestId` y devuelvan una respuesta estandarizada al cliente.  
Este mecanismo se integra con el sistema de logging para garantizar trazabilidad.

---

## 🏷️ Definición de `AppError`

Se define una clase `AppError` que encapsula información esencial del error:

- `message` → descripción del error.
- `statusCode` → código HTTP asociado (400, 404, 500, etc.).
- `code` → código de error de negocio o validación (opcional).

```ts
// src/shared/errors/app-error.ts

// Define un tipo de código con categorías comunes
export type AppErrorCode =
  | "VALIDATION"
  | "NOT_FOUND"
  | "CONFLICT"
  | "INVARIANT"
  | "INTERNAL";

// Expone opciones para adjuntar cause (error original), meta (datos extra) y retryable.
export interface AppErrorOptions {
  code: AppErrorCode;
  cause?: unknown; // Error original (si aplica)
  meta?: Record<string, unknown>; // Datos útiles (sin PII)
  retryable?: boolean; // ¿Tiene sentido reintentar?
}

/**
 * Callback global (hook) que se ejecuta automáticamente
 * cada vez que se crea un AppError. Permite enganchar logging/metricas
 * sin repetir código en cada throw o catch.
 */
export type AppErrorHook = (err: AppError) => void;

export class AppError extends Error {
  // Se llama “hook” porque actúa como un punto de enganche para lógica externa.
  // Es un lugar donde se puede “colgar” una función que reaccione a un evento.
  // En este caso, el evento es: “se creó un AppError”
  static hook?: AppErrorHook;

  // Informacionn del error
  readonly code: AppErrorCode;
  readonly meta?: Record<string, unknown>;
  readonly retryable: boolean;

  constructor(message: string, opts: AppErrorOptions) {
    // Crear Error, similar a: throw new Error("No se pudo procesar la respuesta", { cause: e });
    super(message, { cause: opts.cause as any }); // Node 16+/TS 4.6+
    // Establecer valores del error
    this.name = "AppError";
    this.code = opts.code;
    this.meta = opts.meta;
    this.retryable = opts.retryable ?? false;

    // Normaliza el prototipo y captura stack-trace si está disponible.
    // Donde:
    // new.target es una referencia a la clase concreta que invocó el constructor (AppError).
    // new.target.prototype es el prototype real de esa clase.
    // Object.setPrototypeOf(this, ...) fuerza a que la instancia (this) apunte al prototipo correcto.
    // IMPORTANTE: Asegura que el error custom se comporte como instancia de la clase.
    Object.setPrototypeOf(this, new.target.prototype);

    // En navegadores y Node.js modernos, un Error incluye una stack trace (el listado de funciones que llevaron al error). Pero su captura puede ser inconsistente.
    // Donde:
    // Error.captureStackTrace es una función propia de V8 (el motor de Node.js/Chrome).
    // IMPORTANTE: Mejora la legibilidad de la traza. captura una stack trace clara y útil para debugging/logging.
    if (Error.captureStackTrace) Error.captureStackTrace(this, AppError);

    // Dispara el hook si está configurado
    // Dentro del constructor de AppError, this hace referencia a la instancia recién creada de AppError.
    // Es decir, el objeto completo del error que acabas de construir con todas sus propiedades (message, code, meta, retryable, stack, etc.).
    // Ejemplo: const err = new AppError("Usuario no encontrado", { code: "NOT_FOUND" });
    //          this apunta a err.
    AppError.hook?.(this);
  }

  // Dispara el hook si está configurado
  static setHook(h: AppErrorHook) {
    AppError.hook = h;
  }
  static clearHook() {
    AppError.hook = undefined;
  }

  // Expone helpers estáticos para crear errores tipificados
  static validation(message: string, meta?: Record<string, unknown>) {
    return new AppError(message, {
      code: "VALIDATION",
      meta,
      retryable: false,
    });
  }
  static notFound(message: string, meta?: Record<string, unknown>) {
    return new AppError(message, { code: "NOT_FOUND", meta, retryable: false });
  }
  static conflict(message: string, meta?: Record<string, unknown>) {
    return new AppError(message, { code: "CONFLICT", meta, retryable: false });
  }
  static invariant(message: string, meta?: Record<string, unknown>) {
    return new AppError(message, { code: "INVARIANT", meta, retryable: false });
  }
  static internal(message = "Internal Error", cause?: unknown) {
    return new AppError(message, { code: "INTERNAL", cause, retryable: false });
  }

  // Serializa el error en un payload seguro para logging (reduce el cause a {name,message} si es Error).
  toLog() {
    const cause = (this as any).cause;
    const safeCause =
      cause instanceof Error
        ? { name: cause.name, message: cause.message }
        : cause;

    return {
      name: this.name,
      code: this.code,
      message: this.message,
      retryable: this.retryable,
      meta: this.meta,
      cause: safeCause,
      stack: this.stack,
    };
  }

  // Sobrescribe toJSON() para que el error sea serializable (útil en respuestas y logs).
  toJSON() {
    return this.toLog();
  }
}

// Provee un type guard
export function isAppError(err: unknown): err is AppError {
  return err instanceof AppError;
}
```

Esto permite lanzar errores de forma semántica y controlada desde cualquier parte de la aplicación.

---

## 🛡️ Middleware `errorHandler`

El `errorHandler` centraliza el manejo de excepciones en `Express`.
Siempre debe ubicarse al final del pipeline de `middlewares`.

```ts
// Centraliza la conversión AppError → HTTP status + respuesta.
// Además, envuelve los errores desconocidos en AppError.internal(...)
// para que el hook del bridge también los loguee.

// src/presentation/http/error.middleware.ts
import { NextFunction, Request, Response } from "express";
import { AppError, isAppError } from "../../../shared/errors";

// Mapeo recomendado: AppErrorCode -> HTTP status
export function getHttpStatusForAppError(code: AppError["code"]): number {
  switch (code) {
    case "VALIDATION":
      return 400;
    case "NOT_FOUND":
      return 404;
    case "CONFLICT":
      return 409;
    case "INVARIANT":
      return 422; // o 500 si prefieres
    case "INTERNAL":
    default:
      return 500;
  }
}

/**
 * Middleware de manejo de errores central.
 * - Si no es AppError, lo envuelve en AppError.internal (dispara hook y log).
 * - Devuelve un JSON estable (problem-like) sin PII.
 */
export function errorHandler() {
  return (err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    const appErr = isAppError(err)
      ? err
      : AppError.internal("Unhandled error", err);

    const status = getHttpStatusForAppError(appErr.code);
    const body = {
      error: {
        code: appErr.code,
        message: appErr.message,
        retryable: appErr.retryable,
        // meta: appErr.meta, // incluir sólo si no se usa PII
      },
    };

    res.status(status).json(body);
  };
}
```

---

## 🌐 Integración en `server.ts`

El `errorHandler` debe añadirse después de las rutas y siempre al final del servidor:

```ts
// src/presentation/server.ts
import express, { Request, Response, NextFunction } from "express";
import router from "./routes";
// Errors and Logs

import { randomUUID } from "node:crypto";
import type { ILogger } from "@jmlq/logger";
import { errorHandler } from "./middlewares/http/error.middleware";

// --- Middleware para adjuntar logger por request (con contexto útil) ---
function attachLogger(base: ILogger) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    req.logger = base;
    req.requestId = (req.headers["x-request-id"] as string) ?? randomUUID();
    next();
  };
}

export function createServer(base: ILogger) {
  const app = express();
  app.use(express.json());
  app.use(attachLogger(base));

  app.use("/api", router);

  app.get("/health", (_req, res) => res.json({ ok: true }));

  // IMPORTANTE: Siempre errorHandler se coloca al último
  app.use(errorHandler());

  return app;
}
```

---

## 🚀 Configuración de errors en `app.ts`

```ts
// src/app.ts
import { envs } from "./config/plugins/envs.plugin";
import { createServer } from "./presentation/server";
import { disposeLogs, flushLogs, loggerReady } from "./config/logger";

// Importa el bridge una sola vez → inicializa el hook de AppError
// Cada vez que se construya un AppError, se loggea automáticamente
import "./shared/errors/app-error-logger-bridge";

async function bootstrap() {
  // 1) Inicializa el logger global (singleton)
  const logger = await loggerReady;

  // 2) Crea la app de Express inyectando el logger
  const app = createServer(logger);

  // 3) Levanta el servidor HTTP
  const server = app.listen(envs.PORT, envs.HOST, () => {
    console.log(`🚀 Server running at http://${envs.HOST}:${envs.PORT}`);
    logger.info("http.start", { host: envs.HOST, port: envs.PORT });
  });

  // 4) Captura errores al intentar escuchar en el puerto/host
  server.on("error", async (err: any) => {
    logger.error("http.listen.error", {
      message: err?.message,
      stack: err?.stack,
    });
    await flushLogs().catch(() => {});
    await disposeLogs().catch(() => {});
    process.exit(1);
  });

  // 5) Función para apagado limpio (graceful shutdown)
  const shutdown = async (reason: string, code = 0) => {
    logger.info("app.shutdown.begin", { reason });
    server.close(async () => {
      try {
        await flushLogs(); // Vacía logs pendientes
      } catch {}
      try {
        await disposeLogs(); // Libera recursos (files, conexiones, etc.)
      } catch {}
      logger.info("app.shutdown.end", { code });
      process.exit(code);
    });
  };

  // 6) Señales del SO → apaga de forma controlada
  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // 7) Fallos globales no controlados
  process.on("unhandledRejection", async (err) => {
    const e = err as any;
    logger.error("unhandled.rejection", {
      message: e?.message,
      stack: e?.stack,
    });
    await shutdown("unhandledRejection", 1);
  });

  process.on("uncaughtException", async (err) => {
    logger.error("uncaught.exception", {
      message: err.message,
      stack: err.stack,
    });
    await shutdown("uncaughtException", 1);
  });
}

// 8) Bootstrap de la aplicación con captura de errores fatales
bootstrap().catch(async (err) => {
  const logger = await loggerReady.catch(() => null);

  if (logger) {
    logger.error("bootstrap.fatal", {
      message: (err as Error)?.message,
      stack: (err as Error)?.stack,
    });
    await flushLogs().catch(() => {});
    await disposeLogs().catch(() => {});
  } else {
    // Último recurso si el logger no llegó a inicializar
    console.error("Fatal error (no logger):", err);
  }

  process.exit(1);
});
```

---

# 🧾 Ejemplos de uso de Logger y Errores

A continuación se documenta cómo se integran **logs estructurados** y **manejo de errores** dentro de un caso de uso (`CreateUserUseCase`) y en un controlador (`UserController`).

---

## 📌 Caso de uso: `CreateUserUseCase`

Archivo: `src/domain/use-cases/user/create-user.use-case.ts`

```ts
import { ILogger } from "@jmlq/logger";
import { AppError } from "../../../shared/errors";
import { CreateUserDto } from "../../dtos";
import { UserEntity } from "../../entities";
import { UserRepository } from "../../repositories";

export class CreateUserUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly logger?: ILogger
  ) {}

  async execute(dto: CreateUserDto): Promise<UserEntity> {
    // 1. Log de inicio de validación
    this.logger?.info("createUser.validate", { email: dto.email });

    // 2. Validación de datos obligatorios
    if (!dto.email) {
      this.logger?.warn("createUser.invalid", { dto });
      // Se lanza un error de validación (400)
      throw AppError.validation("Email inválido");
    }

    // 3. Operación principal (persistencia)
    return this.userRepo.createUser(dto);
  }
}
```

✅ Beneficios

> - Cada paso queda registrado en los logs.
> - Los errores esperados (ej. validación) quedan loggeados y viajan al `errorHandler` para generar respuesta estándar.

---

## 📌 Controlador: `UserController`

Archivo: `src/presentation/user/controller.ts`

```ts
import type { NextFunction, Request, Response } from "express";
import { UserRepository } from "../../domain/repositories";
import { CreateUserUseCase } from "../../domain/use-cases/user";

export class UserController {
  constructor(private readonly userRepo: UserRepository) {}

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // 1. Log de inicio de request
      req.logger?.info("user.create.start", {
        requestId: req.requestId,
        body: req.body,
      });

      // 2. Ejecución del caso de uso
      const useCase = new CreateUserUseCase(this.userRepo);
      const user = await useCase.execute(req.body);

      // 3. Log de éxito
      req.logger?.info("user.create.success", {
        requestId: req.requestId,
        userId: user.id,
      });

      res.status(201).json(user);
    } catch (err: any) {
      return next(err); // Delega al errorHandler
    }
  };

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // 1. Log de inicio de request
      req.logger?.info("user.list.start", { requestId: req.requestId });

      // 2. Lógica principal
      const users = await this.userRepo.getUsers();

      // 3. Log de éxito con metadata (count)
      req.logger?.info("user.list.success", {
        count: users.length,
        requestId: req.requestId,
      });

      res.json(users);
    } catch (err: any) {
      return next(err);
    }
  };
}
```

🔎 Explicación

1. **Logs al inicio de cada request**

> - Incluyen el `requestId` generado en el middleware `attachLogger`.
> - Ayudan a correlacionar logs entre middleware, casos de uso y controlador.

2. **Logs de éxito**

> - `"user.create.success"` con `userId` creado.
> - `"user.list.success"` con cantidad de usuarios devueltos.

3. **Errores propagados con `next(err)`**

> - Cualquier error (incluyendo `AppError`) será capturado por el `errorHandler`.
> - Este middleware generará la respuesta JSON estándar con `{ error, code, requestId }`.

---

#### [!DESCARGAR APP CON LOGGIN Y ERRORS!](./assets/ml-dev-nodejs-example-with-logger-errors.zip)

[INICIO](./README.md) | - | [ANTERIOR](./clean-arch-logging-and-errors.md) | - | [SIGUIENTE](./)
