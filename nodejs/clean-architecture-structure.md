# 🏗️ Architecture en Node.js

La **Arquitectura Limpia** separa tu app en capas con responsabilidades claras y dependencias dirigidas hacia adentro (el dominio).
Meta: `código mantenible`, `testeable` y `fácil de evolucionar`.

---

## 🎯 Estructura base

> - **Domain**: reglas de negocio puras (no depende de frameworks).
> - **Infrastructure**: implementaciones técnicas (DB, correos, FS, APIs).
> - **Presentation**: expone la app al exterior (HTTP/CLI/colas) y orquesta casos de uso.
> - **Config**: variables de entorno y settings transversales.
> - **Composition root** (`app.ts`): “arma” la app e inicia el servidor.

---

## 📂 Estructura recomendada

```txt
      src/
        config/
          plugins/
            envs.plugin.ts
        domain/
          entities/
          dtos/  (opcional, ver la nota más abajo)
          repositories/
          use-cases/
        infrastructure/
          repositories/
          adapters/
        presentation/
          <modulo>/
            controller.ts
            dto/
          routes.ts
          server.ts
      app.ts
      tests/
          domain/
          infrastructure/
          presentation/
```

Usar nombres de módulos reales: user/, email/, product/ (evitar nombres genéricos que no representen un dominio real).

```txt
========================
LIMITE DE CAPAS (VISTA 1)
========================
Regla de Dependencias: las dependencias apuntan HACIA ADENTRO (→ Domain).

+------------------------------+
| Presentation                 |  Ej.: Express server, routes, controllers
| (HTTP)                       |  src/presentation/server.ts
|                              |  src/presentation/routes.ts
|                              |  src/presentation/user/controller.ts
+--------------→---------------+

+------------------------------+
| Application / Use Cases      |  Orquestan acciones del dominio
|                              |  src/domain/use-cases/user/*.use-case.ts
+--------------→---------------+

+------------------------------+
| Domain (Core)                |  Entidades + Puertos (interfaces) + DTOs
|                              |  src/domain/entities/*.ts
|                              |  src/domain/repositories/*.repository.ts
|                              |  src/domain/dtos/*.ts
+------------------------------+

+------------------------------+
| Infrastructure (Adapters)    |  Implementaciones de puertos
|                              |  src/infrastructure/repositories/*.impl.ts
|                              |  src/infrastructure/datasources/json/
|                              |    users.datasource.ts, users.json
+------------------------------+

[Config (Transversal)] .env → src/config/plugins/envs.plugin.ts (usado por app e infra)
[Composition Root]     src/app.ts  (inyecta adaptadores y arranca el server)

```

---

```txt
========================================
FLUJO DE UNA PETICIÓN (VISTA 2 - RUNTIME)
========================================
(→ llamadas en tiempo de ejecución)   (⋯ inyección/ensamblado en app.ts)

Cliente HTTP
   |
   v
[Express Router]  →  [Controller]  →  [UseCase]  →  [UserRepository (PORT, interfaz)]
                                                     |
                                                     ⋯  Inyectado en app.ts:
                                                     v
                                       [UserRepositoryImpl (ADAPTER)]
                                                     |
                                                     v
                                          [JSON Datasource (FS)]
                                                     |
                                                     v
                                            [users.json en disco]

Respuesta HTTP (200/201 JSON)  ←  Controller  ←  UseCase  ←  RepoImpl/Datasource

Notas:
- El Controller NO conoce Infra directamente; llama al UseCase.
- El UseCase conoce solo el PORT (UserRepository). La implementación concreta (UserRepositoryImpl)
  se inyecta en app.ts (Composition Root).
- Configuración (HOST, PORT, etc.): .env → envs.plugin.ts → usado por server/adapters.

```

---

## 🧱 Capas

### 1) `config/` (transversal)

> - Propósito: centralizar `variables de entorno` y `configuración`.

```bash
# .env
HOST=127.0.0.1
PORT=3000
```

```bash
# .env.template
HOST=127.0.0.1
PORT=3000
```

```ts
// src/config/plugins/envs.plugin.ts
import "dotenv/config";
import env from "env-var";

export const envs = {
  HOST: env.get("HOST").default("127.0.0.1").asString(),
  PORT: env.get("PORT").default("3000").asPortNumber(),
  NODE_ENV: env.get("NODE_ENV").default("development").asString(),
};
```

---

### 2) `domain/` (reglas de negocio puras)

> - `entities/`: entidades de negocio.

```ts
// src/domain/entities/user.entity.ts
export class UserEntity {
  constructor(
    public readonly id: number,
    public name: string,
    public email: string
  ) {}
}
```

> - `dtos/ (opcional)`: Contratos de negocio independientes del transporte. Útiles para testear dominio sin tocar HTTP ni frameworks

```ts
// src/domain/dtos/create-user.dto.ts
export interface CreateUserDto {
  name: string;
  email: string;
}
```

> - `repositories/`: `interfaces` de repositorio orientadas al dominio.

```ts
// src/domain/repositories/user.repository.ts
import { CreateUserDto } from "../dtos";
import { UserEntity } from "../entities";

export interface UserRepository {
  createUser(dto: CreateUserDto): Promise<UserEntity>;
  getUsers(): Promise<UserEntity[]>;
}
```

> - `use-cases/`: acciones concretas orquestadas (crear/listar/actualizar/borrar).

```ts
// src/domain/use-cases/user/create-user.use-case.ts
import { CreateUserDto } from "../../dtos";
import { UserEntity } from "../../entities";
import { UserRepository } from "../../repositories";

export class CreateUserUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(dto: CreateUserDto): Promise<UserEntity> {
    return this.userRepo.createUser(dto);
  }
}
```

---

### 3) `infrastructure/` (implementaciones técnicas)

> - `repositories/`: implementan interfaces de `domain/repositories` usando datasources.

```ts
// src/infrastructure/repositories/user.repository.impl.ts
import { CreateUserDto } from "../../domain/dtos";
import { UserEntity } from "../../domain/entities";
import { UserRepository } from "../../domain/repositories";
import { UserJsonDatasource } from "../datasources/json/users.datasource";

export class UserRepositoryImpl implements UserRepository {
  async createUser(dto: CreateUserDto): Promise<UserEntity> {
    const users = await UserJsonDatasource.load();
    const nextId = (users.reduce((m, u) => Math.max(m, u.id), 0) || 0) + 1;

    const raw = { id: nextId, name: dto.name, email: dto.email };
    users.push(raw);
    await UserJsonDatasource.save(users);

    return new UserEntity(raw.id, raw.name, raw.email);
  }

  async getUsers(): Promise<UserEntity[]> {
    const users = await UserJsonDatasource.load();
    return users.map((u) => new UserEntity(u.id, u.name, u.email));
  }
}
```

> - `adapters/ (si es necesario)`: integraciones con servicios (correo, S3, Redis, etc.).

Ejemplo:

> > > - Contrato

```ts
// src/domain/ports/email.service.ts
export interface EmailMessage {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  from?: string;
}

export interface EmailService {
  send(message: EmailMessage): Promise<void>;
}
```

> > > - Se crea Adapter para nodemailer. instalar `npm i nodemailer`

```ts
//src/infrastructure/adapters/email.adapter.ts

import nodemailer, { Transporter } from "nodemailer";
import { EmailMessage, EmailService } from "../../domain/ports/email.service";

export type NodemailerOptions = {
  host: string;
  port: number;
  secure?: boolean; // true para 465, false para otros
  auth?: { user: string; pass: string };
  defaultFrom?: string; // opcional para usar como remitente por defecto
};

export class NodemailerEmailAdapter implements EmailService {
  private readonly transporter: Transporter;
  private readonly defaultFrom?: string;

  constructor(opts: NodemailerOptions) {
    this.transporter = nodemailer.createTransport({
      host: opts.host,
      port: opts.port,
      secure: opts.secure ?? false,
      auth: opts.auth,
    });
    this.defaultFrom = opts.defaultFrom;
  }

  async send(message: EmailMessage): Promise<void> {
    await this.transporter.sendMail({
      from: message.from ?? this.defaultFrom,
      to: Array.isArray(message.to) ? message.to.join(",") : message.to,
      subject: message.subject,
      html: message.html,
      text: message.text,
    });
  }
}
```

> > > - Uso `Adapter`:

```ts
// src/app.ts
import { createServer } from "./presentation/server";
import { NodemailerEmailAdapter } from "./infrastructure/adapters/email.adapter";

async function bootstrap() {
  // Email
  const email = new NodemailerEmailAdapter({
    host: process.env.SMTP_HOST!,
    port: Number(process.env.SMTP_PORT || 587),
    secure: false,
    auth: { user: process.env.SMTP_USER!, pass: process.env.SMTP_PASS! },
    defaultFrom: process.env.MAIL_FROM,
  });

  // Aquí podrías inyectar estas dependencias a tus repositorios/use-cases
  // ya sea manualmente o vía un contenedor DI.

  const app = createServer();
  const port = Number(process.env.PORT || 3000);
  app.listen(port, () => console.log(`🚀 HTTP listening on :${port}`));
}

bootstrap().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
```

### 4) `presentation/` (interfaz con el exterior)

Un directorio por **módulo** (p. ej., email/, user/, product/).

> - `dto/`: **DTOs de transporte** (HTTP/CLI) cerca del controller.

```ts
// src/presentation/user/dto/create-user.request.dto.ts
export interface CreateUserRequestDto {
  name: string;
  email: string;
}
```

> - `controller.ts`: recibe request, valida datos y llama a casos de uso.

```ts
// src/presentation/user/controller.ts
import type { Request, Response } from "express";
import { UserRepository } from "../../domain/repositories";
import { CreateUserUseCase } from "../../domain/use-cases/user";

export class UserController {
  constructor(private readonly userRepo: UserRepository) {}

  create = async (req: Request, res: Response) => {
    try {
      const useCase = new CreateUserUseCase(this.userRepo);
      const user = await useCase.execute(req.body);
      res.status(201).json(user);
    } catch (err: any) {
      res.status(400).json({ error: err.message });
    }
  };

  list = async (_req: Request, res: Response) => {
    try {
      const users = await this.userRepo.getUsers();
      res.json(users);
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  };
}
```

> - `routes.ts`: define endpoints y enlaza con controller. **NOTA**: Se pueden definir un archivo `routes.ts` en cada módulo o uno global. En este caso se va a definir uno global.

```ts
// src/presentation/routes.ts
import { Router } from "express";
import { UserRepositoryImpl } from "../infrastructure/repositories";
import { UserController } from "./user";

const router = Router();
const repo = new UserRepositoryImpl();
const controller = new UserController(repo);

router.get("/users", controller.list);
router.post("/users", controller.create);

export default router;
```

> - `server.ts`: registra middlewares y rutas.

```ts
// src/presentation/server.ts
import express from "express";
import router from "./routes";

export function createServer() {
  const app = express();
  app.use(express.json()); // <-- necesario para POST JSON

  app.use("/api", router);

  app.get("/health", (_req, res) => res.json({ ok: true }));

  return app;
}
```

### 5) `app.ts` (composition root)

> - Ensambla dependencias, registra implementaciones y arranca el server.

```ts
// src/app.ts
import { envs } from "./config/plugins/envs.plugin";
import { createServer } from "./presentation/server";

async function bootstrap() {
  const app = createServer();
  app.listen(envs.PORT, envs.HOST, () => {
    console.log(`🚀 Server running at http://${envs.HOST}:${envs.PORT}`);
  });
}

bootstrap().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
```

## 🧭 Convenciones de nombres (resumen rápido)

> > - Entidades: `*.entity.ts`
> > - Use cases: `*.use-case.ts`
> > - Repositories (interfaces): `*.repository.ts`
> > - Implementacion de Repositorios: `*.repository.impl.ts`
> > - Adaptadores: `*.adapter.ts`
> > - DTOs de dominio (opcionales): `*.dto.ts`
> > - DTOs de presentación: `*.request.dto.ts`
> > - Config: `*.plugin.ts`, `*.config.ts`
> > - Rutas/controladores dentro del módulo: `controller.ts`, `routes.ts` (o `user.controller.ts`/`user.routes.ts` si separas por responsabilidad)

#### [!DESCARGAR APP BASE!](./assets/ml-dev-nodejs-example.zip)

[INICIO](./README.md) | - | [ANTERIOR](./clean-architecture-ini.md) | - | [SIGUIENTE](./clean-arch-logging-and-errors.md)
