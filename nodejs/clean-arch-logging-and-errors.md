# 📑 Menú de navegación

- [🛡️ Crosscutting Concerns: Logging](#️-crosscutting-concerns-logging)
  - [⚡ Bootstrap de logger (composición de datasources + PII + nivel mínimo)](#-bootstrap-de-logger-composición-de-datasources--pii--nivel-mínimo)
    - [1) Instalar](#1-instalar)
    - [2) Variables de entorno `.env`](#2-variables-de-entorno-env)
    - [3) Configurar `envsplugin.ts`](#3-configurar-envsplugints)
    - [4) Integración en infraestructura](#4-integración-en-infraestructura)
      - [🔢 toMinLevel – normalizador de niveles de log](#-tominlevel--normalizador-de-niveles-de-log)
      - [🕵️ PII Settings – redacción de datos sensibles](#-pii-settings--redaccion-de-datos-sensibles)
      - [📦 Adapters (FS, MongoDB, PostgreSQL)](#-adapters-fs-mongodb-postgresql)
      - [🚀 Bootstrap del logger](#-bootstrap-del-logger)
  - [🌍 Inicialización única y acceso global](#-inicialización-única-y-acceso-global)
    - [🧩 Singleton con globalThis](#-singleton-con-globalthis)
  - [🧾 Integración con Express](#-integración-con-express)
    - [📝 Extender Request (logger + requestId)](#-extender-request-logger--requestid)
    - [🔗 Middleware attachLogger](#-middleware-attachlogger)
    - [🌐 Conexión en servertS Express](#-conexión-en-servertS-express)

---

# 🛡️ Crosscutting Concerns: Logging

## ⚡ Bootstrap de logger (composición de datasources + PII + nivel mínimo)

[`jmlq/logger`](https://www.npmjs.com/package/@jmlq/logger) es un paquete propietario de logging extensible y desacoplado, diseñado con principios de Arquitectura Limpia. Permite registrar logs en múltiples destinos (archivos, MongoDB, PostgreSQL) mediante plugins y soporta enmascarado de datos sensibles (PII).

### 1) Instalar

```bash
# Instalar el core
npm i @jmlq/logger

# Instalar plugins opcionales según el backend de persistencia
npm i @jmlq/logger-plugin-fs

# En este ejemplo solo se crearán archivos FS
```

---

### 2) Variables de entorno `.env`

La documentación de `@jmlq/logger` especifica que variables de entorno se deben configurar en base a las necesidades del desarrollo.

```bash
# @jmlq/logger
# Nivel mínimo por entorno (dev: debug, prod: warn)
LOGGER_LEVEL=debug
# PII (Personally Identifiable Information)
LOGGER_PII_ENABLED=true
LOGGER_PII_INCLUDE_DEFAULTS=true
# FILESYSTEM @jmlq/logger-plugin-fs
LOGGER_FS_PATH=./logs
```

---

### 3) Configurar `envs.plugin.ts`

Se debe agregar las variables de entorno agregadas al archivo `.env` en `src/config/plugins/envs.plugin.ts`

```ts
import "dotenv/config";
import env from "env-var";

export const envs = {
  // variables anteriormente declaradas
  logger: {
    LOGGER_LEVEL: env.get("LOGGER_LEVEL").default("debug").asString(),
    LOGGER_PII_ENABLED: env.get("LOGGER_PII_ENABLED").default("false").asBool(),
    LOGGER_PII_INCLUDE_DEFAULTS: env
      .get("LOGGER_PII_INCLUDE_DEFAULTS")
      .default("false")
      .asBool(),
    LOGGER_FS_PATH: env.get("LOGGER_FS_PATH").default("./logs").asString(),
  },
};
```

---

### 4) Integración en infraestructura

**NOTA**: Esta configuración se basa en la documentación de [`jmlq/logger`](https://www.npmjs.com/package/@jmlq/logger).

#### 🔢 `toMinLevel` – normalizador de niveles de log

La función `toMinLevel` en `@jmlq/logger` es un normalizador de niveles de log.
Su objetivo es aceptar distintos tipos de entrada (número, string, o clave del enum LogLevel) y convertirlos a un valor seguro del tipo `LogLevel`.

```ts
// infrastructure/adapters/settings/loglevel.settings.ts

import { LogLevel } from "@jmlq/logger";

export function toMinLevel(
  level: LogLevel | keyof typeof LogLevel | string
): LogLevel {
  if (typeof level === "number") return level as LogLevel;
  switch (String(level || "debug").toLowerCase()) {
    case "trace":
      return LogLevel.TRACE;
    case "debug":
      return LogLevel.DEBUG;
    case "info":
      return LogLevel.INFO;
    case "warn":
      return LogLevel.WARN;
    case "error":
      return LogLevel.ERROR;
    case "fatal":
      return LogLevel.FATAL;
    default:
      return LogLevel.DEBUG;
  }
}
```

#### 🕵️ `PII Settings` – redacción de datos sensibles

Implementar la `infraestructura de redacción PII` (`Personally Identifiable Information`) de `@jmlq/logger`.
El objetivo es `detectar y reemplazar datos sensibles` (emails, contraseñas, DNI, secretos, etc.) antes de que un log sea persistido o enviado.

```ts
// infrastructure/adapters/settings/loglevel.settings.ts
export type PiiReplacement = {
  pattern: string;
  replaceWith: string;
  flags?: string; // regex (g, i, m, s, u, y) VER en documentación
};

export interface PiiConfig {
  enabled: boolean;
  whitelistKeys?: string[];
  blacklistKeys?: string[];
  patterns?: PiiReplacement[];
  deep?: boolean;
  includeDefaults?: boolean;
}

// patrones “de fábrica” (del sistema):
export const DEFAULT_PII_PATTERNS: PiiReplacement[] = [
  // {
  //   pattern: String.raw`[^@\n\r ]+@[^@\n\r ]+`,
  //   replaceWith: "[EMAIL]",
  //   flags: "g",
  // },
];

// patrones “del cliente/proyecto”:
export const clientPiiPatterns: PiiReplacement[] = [
  { pattern: String.raw`\b\d{10}\b`, flags: "g", replaceWith: "[EC_DNI]" },
];

// lista negra de nombres de clave que se siempre se ocultan
export const redactKeys: string[] = ["password", "secret"];
// lista blanca de nombres de clave que no se deben ocultar por clave
export const preserveKeys: string[] = ["city"];

// Helpers
// 1. Filtra valores no válidos: elimina null, undefined y "" (cadena vacía).
// 2. Elimina duplicados usando Set.
// 3. Conserva el primero de cada valor repetido (porque Set guarda la primera aparición).
export function dedupeStrings(arr: Array<string | undefined | null>): string[] {
  return [...new Set(arr.filter((x): x is string => !!x && x.length > 0))];
}

// 1. Construye una clave de identidad por patrón: pattern + "__" + replaceWith + "__" + (flags || "").
// 2. Inserta cada elemento en un `Map` usando esa clave. Si la clave ya existe, sobrescribe el anterior (es decir, gana el último).
// 3. Devuelve los valores únicos del `Map`.
export function dedupePatterns(arr: PiiReplacement[]): PiiReplacement[] {
  const m = new Map<string, PiiReplacement>();
  for (const p of arr)
    m.set(`${p.pattern}__${p.replaceWith}__${p.flags ?? ""}`, p);
  return [...m.values()];
}

// Builder unificado
export function buildPiiConfig(
  opts?: PiiConfig
): Required<Omit<PiiConfig, "includeDefaults">> {
  const includeDefaults = opts?.includeDefaults ?? true;

  const patterns = dedupePatterns([
    ...(includeDefaults ? DEFAULT_PII_PATTERNS : []),
    ...clientPiiPatterns,
    ...(opts?.patterns ?? []),
  ]);

  const whitelistKeys = dedupeStrings([
    ...(opts?.whitelistKeys ?? []),
    ...preserveKeys,
  ]);
  const blacklistKeys = dedupeStrings([
    ...(opts?.blacklistKeys ?? []),
    ...redactKeys,
  ]);

  return {
    enabled: !!opts?.enabled,
    whitelistKeys,
    blacklistKeys,
    patterns,
    deep: opts?.deep ?? true,
  };
}
```

#### 📦 Adapters (`FS`, `MongoDB`, `PostgreSQL`)

En este caso solo se va a usar `FS` pero se puede conectar a `MongoDB` y `Postgresql`.

```ts
// infrastructure/adapters/adapters/fs.adapter.ts

import { createFsDatasource } from "@jmlq/logger-plugin-fs";
import type { ILogDatasource } from "@jmlq/logger";

export interface IFsProps {
  basePath: string;
  fileNamePattern: string;
  rotationPolicy: { by: "none" | "day" | "size"; maxSizeMB?: number };
}

export class FsAdapter {
  private constructor(private readonly ds: ILogDatasource) {}
  static create(opts: IFsProps): FsAdapter | undefined {
    try {
      const ds = createFsDatasource({
        basePath: opts.basePath,
        mkdir: true,
        fileNamePattern: opts.fileNamePattern,
        rotation: opts.rotationPolicy,
        onRotate: (oldP, newP) =>
          console.log("[fs] rotated:", oldP, "->", newP),
        onError: (e) => console.error("[fs] error:", e),
      });
      console.log("[logger] Conectado a FS para logs");
      return new FsAdapter(ds);
    } catch (e: any) {
      console.warn("[logger] FS deshabilitado:", e?.message ?? e);
    }
  }
  get datasource(): ILogDatasource {
    return this.ds;
  }
}
```

#### 🚀 Bootstrap del logger

Arranque de `@jmlq/logger`

```ts
import {
  createLogger,
  CompositeDatasource,
  type ILogDatasource,
} from "@jmlq/logger";
import { buildPiiConfig } from "./settings/pii.settings";
import { toMinLevel } from "./settings/loglevel.settings";
// NOTA: Opcionales depende de las necesidades del cliente
import { FsAdapter, type IFsProps } from "./adapters/fs.adapter";

export interface LoggerBootstrapOptions {
  minLevel: string | number;
  pii?: {
    enabled?: boolean;
    whitelistKeys?: string[];
    blacklistKeys?: string[];
    patterns?: any[];
    deep?: boolean;
    includeDefaults?: boolean;
  };
  adapters?: {
    // NOTA: Opcionales depende de las necesidades del cliente
    fs?: IFsProps;
  };
}

export class LoggerBootstrap {
  private constructor(
    private readonly _logger: ReturnType<typeof createLogger>,
    private readonly _ds: ILogDatasource
  ) {}

  static async create(opts: LoggerBootstrapOptions): Promise<LoggerBootstrap> {
    const dsList: ILogDatasource[] = [];

    // NOTA: Opcionales depende de las necesidades del cliente
    if (opts.adapters?.fs) {
      const fs = FsAdapter.create(opts.adapters.fs);
      if (fs) dsList.push(fs.datasource);
    }
    //----

    if (dsList.length === 0)
      throw new Error("[logger] No hay datasources válidos.");
    const datasource =
      dsList.length === 1 ? dsList[0] : new CompositeDatasource(dsList);

    const pii = buildPiiConfig({
      enabled: opts.pii?.enabled ?? false,
      includeDefaults: opts.pii?.includeDefaults ?? true,
      whitelistKeys: opts.pii?.whitelistKeys,
      blacklistKeys: opts.pii?.blacklistKeys,
      patterns: opts.pii?.patterns,
      deep: opts.pii?.deep ?? true,
    });

    const logger = createLogger(datasource, {
      minLevel: toMinLevel(opts.minLevel),
      pii,
    });
    return new LoggerBootstrap(logger, datasource);
  }

  get logger() {
    return this._logger;
  }
  async flush() {
    const any = this._logger as any;
    if (typeof any.flush === "function") await any.flush();
  }
  async dispose() {
    const any = this._logger as any;
    if (typeof any.dispose === "function") await any.dispose();
  }
}
```

## 🌍 Inicialización única y acceso global

### 🧩 Singleton con `globalThis`

Usa un `singleton` basado en `global.__LOGGER_BOOT__` para evitar múltiples boots.
Exporta:

> - `loggerReady`: Promise<ILogger> – promesa al logger listo.
> - `flushLogs()` y d`isposeLogs()` – para `vaciar`/`cerrar` recursos.

```ts
// src/config/logger/index.ts

import { LoggerBootstrap } from "../../infrastructure/adapters/logger/bootstrap";
import { envs } from "../plugins/envs.plugin";

declare global {
  var __LOGGER_BOOT__: Promise<LoggerBootstrap> | undefined;
}

async function init() {
  return LoggerBootstrap.create({
    minLevel: envs.logger.LOGGER_LEVEL ?? "debug",
    pii: {
      enabled: envs.logger.LOGGER_PII_ENABLED,
      includeDefaults: envs.logger.LOGGER_PII_INCLUDE_DEFAULTS,
      deep: true,
    },
    adapters: {
      // NOTA: Opcionales depende de las necesidades del cliente
      fs: envs.logger.LOGGER_FS_PATH
        ? {
            basePath: envs.logger.LOGGER_FS_PATH,
            fileNamePattern: "app-{yyyy}{MM}{dd}.log",
            rotationPolicy: { by: "day" },
          }
        : undefined,
      // ---
    },
  });
}

// 1. Es una promesa singleton de LoggerBootstrap
// 2. usa el operador nullish-coalescing (??) para: Reusar globalThis.__LOGGER_BOOT__ si ya existe. En caso contrario crea y memoriza (= init()) la promesa si no existe aún.
// 3. Garantiza una sola inicialización global del sistema de logging (adapters, datasources, PII, etc.) aunque el módulo se importe múltiples veces
export const bootReady: Promise<LoggerBootstrap> =
  globalThis.__LOGGER_BOOT__ ?? (globalThis.__LOGGER_BOOT__ = init());

// 1. Es una promesa que resuelve directamente al logger
// 2. Hace un map de la promesa anterior: bootReady.then(b => b.logger).
export const loggerReady = bootReady.then((b) => b.logger);

// 1. Espera a bootReady y llama boot.flush(), que a su vez pide al logger/datasources que vacíen buffers pendientes (útil antes de apagar el proceso o en tests).
export async function flushLogs() {
  const boot = await bootReady;
  await boot.flush();
}

// 1. Espera a bootReady y llama boot.dispose(), que cierra recursos (conexiones a Mongo/Postgres, file handles, etc.)
export async function disposeLogs() {
  const boot = await bootReady;
  await boot.dispose();
}
```

---

## 🧾 Integración con Express

### 📝 Extender `Request` (`logger` + `requestId`)

**Objetivo**: que `TypeScript` conozca `req.logger` y `req.requestId`.
Crear el archivo `src/types/express.d.ts`.

```ts
// src/types/express.d.ts
import "express";
import type { ILogger } from "@jmlq/logger";

declare module "express-serve-static-core" {
  interface Request {
    logger?: ILogger;
    requestId?: string;
  }
}
```

**Nota**: asegúrarse de que `src/types` esté bajo include en `tsconfig.json`. No exportes nada en este archivo.

### 🔗 Middleware `attachLogger`

**Objetivo**: inyectar `logger` y `requestId` en cada `request`.

```ts
// src/presentation/server.ts
import express, { Request, Response, NextFunction } from "express";
import { randomUUID } from "node:crypto";
import type { ILogger } from "@jmlq/logger";

function attachLogger(base: ILogger) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    req.logger = base;
    req.requestId = (req.headers["x-request-id"] as string) ?? randomUUID();
    next();
  };
}
```

### 🔌 Bridge AppError ↔ Logger (auto-logging)

Este bridge conecta el sistema de errores (`AppError`) con el `logger` global para loggear automáticamente cada AppError con el nivel correcto, sin repetir código en controladores o middlewares.

```ts
// src/shared/errors/app-error-logger-bridge.ts
import { loggerReady } from "../../config/logger";
import { AppError, AppErrorCode } from "./app-error";
import { LogLevel } from "@jmlq/logger"; // enum/tipos del core

/** Mapeo central: AppErrorCode -> LogLevel */
export function getLogLevelForAppError(code: AppErrorCode): LogLevel {
  switch (code) {
    case "VALIDATION":
      return LogLevel.WARN;
    case "NOT_FOUND":
      return LogLevel.INFO;
    case "CONFLICT":
      return LogLevel.WARN;
    case "INTERNAL":
      return LogLevel.ERROR;
    case "INVARIANT":
      return LogLevel.ERROR;
    default:
      return LogLevel.ERROR;
  }
}

/** Hook global: se registra una vez */
let initialized = false;

async function init() {
  if (initialized) return;
  initialized = true;

  const logger = await loggerReady;

  AppError.setHook((err) => {
    const lvl = getLogLevelForAppError(err.code);
    const eventName = "app.error";
    const payload = err.toLog();

    switch (lvl) {
      case LogLevel.INFO:
        logger.info(eventName, payload);
        break;
      case LogLevel.WARN:
        logger.warn(eventName, payload);
        break;
      case LogLevel.ERROR:
      default:
        logger.error(eventName, payload);
        break;
    }
  });
}

// Side-effect: arranca al importar el módulo.
init().catch((e) => {
  // Último recurso si el logger no inicializa (no rompe la app)
  // eslint-disable-next-line no-console
  console.error("[AppErrorBridge] init failed:", e);
});
```

---

### 🌐 Conexión en `server.ts` (`Express`)

**Objetivo**: que todas las rutas tengan `req.logger` y `req.requestId`.

```ts
// src/presentation/server.ts (continuación)
import express, { Request, Response, NextFunction } from "express";
import router from "./routes";
import { randomUUID } from "node:crypto";
import type { ILogger } from "@jmlq/logger";

export function createServer(base ILogger) {
  const app = express();
  //  Necesario para POST JSON
  app.use(express.json());

  // Inyecta logger + requestId por request
  app.use(attachLogger(base));

  // Rutas
  app.use("/api", router);

  // Healthcheck
  app.get("/health", (_req, res) => res.json({ ok: true }));

  return app;
}
```

---

## 🚀 Configuración de logger en `app.ts`

El archivo `src/app.ts` se encarga de inicializar el servidor Express y configurar el ciclo de vida de la aplicación, incluyendo **logs estructurados** en arranque, apagado y eventos críticos.

```ts
// src/app.ts
import { envs } from "./config/plugins/envs.plugin";
import { createServer } from "./presentation/server";
import { disposeLogs, flushLogs, loggerReady } from "./config/logger";

async function bootstrap() {
  // 1) Espera la inicialización del logger (singleton global).
  const logger = await loggerReady;

  // 2) Crea la instancia del servidor Express con el logger inyectado.
  const app = createServer(logger);

  // 3) Inicia el servidor HTTP en el host y puerto configurados.
  const server = app.listen(envs.PORT, envs.HOST, () => {
    console.log(`🚀 Server running at http://${envs.HOST}:${envs.PORT}`);
    logger.info("http.start", { host: envs.HOST, port: envs.PORT });
  });

  // 4) Captura errores al intentar levantar el servidor (ej: puerto ocupado).
  server.on("error", async (err: any) => {
    logger.error("http.listen.error", {
      message: err?.message,
      stack: err?.stack,
    });
    await flushLogs().catch(() => {});
    await disposeLogs().catch(() => {});
    process.exit(1);
  });

  // 5) Función auxiliar para apagado limpio del servidor.
  const shutdown = async (reason: string, code = 0) => {
    logger.info("app.shutdown.begin", { reason });
    server.close(async () => {
      try {
        await flushLogs(); // Vacía buffers pendientes
      } catch {}
      try {
        await disposeLogs(); // Libera recursos (conexiones, file handles, etc.)
      } catch {}
      logger.info("app.shutdown.end", { code });
      process.exit(code);
    });
  };

  // 6) Manejo de señales del sistema para apagado controlado (Ctrl+C, kill).
  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // 7) Manejo de fallos globales no controlados:
  //    - Promesas rechazadas sin catch
  process.on("unhandledRejection", async (err) => {
    const e = err as any;
    logger.error("unhandled.rejection", {
      message: e?.message,
      stack: e?.stack,
    });
    await shutdown("unhandledRejection", 1);
  });

  //    - Excepciones no capturadas en el event loop
  process.on("uncaughtException", async (err) => {
    logger.error("uncaught.exception", {
      message: err.message,
      stack: err.stack,
    });
    await shutdown("uncaughtException", 1);
  });
}

// 8) Ejecución del bootstrap con captura de errores fatales
//    (por ejemplo, si el logger o el servidor fallan al inicializar).
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
    // Último recurso: mostrar el error en consola si no hay logger.
    console.error("Fatal error (no logger):", err);
  }
  process.exit(1);
});
```

---

[INICIO](./README.md) | - | [ANTERIOR](./clean-architecture-structure.md) | - | [SIGUIENTE](./clean-arch-errors.md)
