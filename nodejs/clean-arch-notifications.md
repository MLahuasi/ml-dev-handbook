# 📬 ⚠️ Crosscutting Concerns: Notificaciones

En este módulo se va a configurar el envío de emails para reportar errores, notificaciones, etc usando el componente [`@jmlq/mailer`](https://www.npmjs.com/package/@jmlq/mailer) que usa `nodemailer`.

## 📦 Instalación de dependencias

Instala el paquete core `@jmlq/mailer` (que internamente usa `nodemailer`) y la utilidad `env-var` para normalizar variables de entorno.

```bash
# Librería de correo (core) + transport
npm i @jmlq/mailer nodemailer
```

---

## 1) 🔐 Variables de entorno (`.env`)

Declara todas las variables que controlan el envío: driver, servicio u host SMTP, credenciales y destinatarios por defecto para reportes y alertas.

```ini
# @jmlq/mailer
# Driver (opcional, default nodemailer)
MAIL_DRIVER=nodemailer
# Servicio elegido
MAILER_SERVICE=gmail
# Credenciales
MAILER_EMAIL=mail@gmail.com
# Crear key en gmail
# https://myaccount.google.com/apppasswords
# Se genera una clave con la siguiente estructura: xxxx xxxx xxxx xxxx
# Se usa esa clave en lugar de la contraseña de gmail
# Se elimina los espacios en blanco
MAILER_SECRET_KEY=xxxxxxxxxxx
# Enviar notificaciones de errores graves por email
# SMTP explícito (opcional si usas MAILER_SERVICE conocido)
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_SECURE=false

# NOTIFICACIONES
# Mail Servivicio Tecnico
MAILER_FROM=mail@hotmail.com
MAILER_ALERTS_ENABLED=true
# INFO|WARN|ERROR
MAILER_ALERTS_MIN_LEVEL= ERROR

```

---

### 2) ⚙️ Config: `envs.plugin.ts` (sección mailer)

**Archivo**: `src/config/plugins/envs.plugin.ts`.

Centraliza y normaliza variables de entorno usando `env-var`, resolviendo servicio → host SMTP y activando banderas de alertas.

`Agrega`/`normaliza` todas las claves del `mailer` en un bloque `envs.mailer`.

```ts
// src/config/plugins/envs.plugin.ts
import "dotenv/config";
import env from "env-var"; // <- default import

export const envs = {
  //   Otras Variables ....
  mailer: {
    MAIL_DRIVER: resolveDriver(
      env.get("MAIL_DRIVER").default("nodemailer").asString()
    ),
    MAILER_FROM: env.get("MAILER_FROM").asString(),
    MAIL_HOST: env
      .get("MAIL_HOST")
      .default(
        resolveHost(env.get("MAILER_SERVICE").default("gmail").asString())
      )
      .asString(),
    MAIL_PORT: env.get("MAIL_PORT").default("587").asIntPositive(),
    MAIL_SECURE: env.get("MAIL_SECURE").default("false").asBool(),

    MAILER_EMAIL: env.get("MAILER_EMAIL").required().asString(),
    MAILER_SECRET_KEY: env.get("MAILER_SECRET_KEY").required().asString(),
    MAILER_ALERTS_ENABLED: env
      .get("MAILER_ALERTS_ENABLED")
      .default("true")
      .asBool(),
    MAILER_ALERTS_MIN_LEVEL: env
      .get("MAILER_ALERTS_MIN_LEVEL")
      .default("ERROR")
      .asString(), // INFO|WARN|ERROR
  },
};

// Mapea el servicio a un host SMTP conocido
function resolveHost(service: string): string {
  switch (service.toLowerCase()) {
    case "gmail":
      return "smtp.gmail.com";
    case "outlook":
      return "smtp.office365.com";
    case "yahoo":
      return "smtp.mail.yahoo.com";
    default:
      return service; // permite custom host
  }
}

function resolveDriver(service: string): string {
  switch (service.toLowerCase()) {
    case "nodemailer":
      return "nodemailer";
    default:
      return service; // permite custom mailer
  }
}
```

---

## 3) Mapper de ENV → `IMailerEnv`

**Archivo**: `src/config/mappers/mailer-env.mapper.ts`.

Transforma `envs.mailer` al **contrato exacto** que espera `@jmlq/mailer` (`IMailerEnv`), resolviendo servicio → host.

```ts
import { IMailerEnv } from "@jmlq/mailer"; // o tu tipo local
import { envs } from "../plugins/envs.plugin";

export function mapMailerEnv(): IMailerEnv {
  return {
    MAIL_DRIVER:
      envs.mailer.MAIL_DRIVER === "nodemailer" ? "nodemailer" : undefined,
    MAIL_FROM: envs.mailer.MAILER_FROM,
    MAIL_HOST: envs.mailer.MAIL_HOST,
    MAIL_PORT: envs.mailer.MAIL_PORT,
    MAIL_SECURE: envs.mailer.MAIL_SECURE,
    MAIL_USER: envs.mailer.MAILER_EMAIL,
    MAIL_PASS: envs.mailer.MAILER_SECRET_KEY,
  };
}
```

---

## 4) 🧰 Helpers reutilizables

### 4.1) 🧾 `toCSV` (CSV)

**Archivo**: `src/shared/helpers/csv.ts`

Convierte un arreglo de objetos a CSV con encabezados, escapando comillas, comas y saltos de línea.

```ts
/**
 * Util simple para convertir a CSV (encabezado + filas).
 * Mantiene la misma lógica que tu función original.
 */
export function toCsv<T extends Record<string, any>>(data: T[]): string {
  if (!data.length) return "id,name,email\n"; // cabecera básica si no hay datos
  const headers = Object.keys(data[0]);
  const escape = (val: unknown) => {
    if (val === null || val === undefined) return "";
    const s = String(val);
    // Si contiene comillas, coma o salto de línea → encierra en comillas y duplica comillas internas
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const headerLine = headers.join(",");
  const lines = data.map((row) => headers.map((h) => escape(row[h])).join(","));
  return [headerLine, ...lines].join("\n");
}
```

---

### 4.2 helpers

**Carpeta**: `src/infrastructure/notifications/helpers/`

#### 4.2.1) 📧 Direcciones de correo (Address/Recipients)

Define los tipos de dirección y normaliza `Address` | `Address[]` a un arreglo `{email,name?}` listo para enviar.

```ts
// src/infrastructure/notifications/helpers/email-address.ts

/** Direcciones de correo (mismo shape que tenías en notify.ts) */
export type Address = string | { email: string; name?: string };
export type Addresses = Address | Address[];

/** Normaliza Address|Address[] a {email,name?}[] */
export function toRecipients(
  addr: Addresses
): { email: string; name?: string }[] {
  const arr = Array.isArray(addr) ? addr : [addr];
  return arr.map((a) => (typeof a === "string" ? { email: a } : a));
}
```

---

#### 4.2.3) 🧱 HTML rendering (escape, KV, tabla, JSON)

Provee utilidades para escapar `HTML`, renderizar pares `clave`/`valor`, tablas (arrays de objetos) y JSON en bloques `<pre>`.

```ts
// src/infrastructure/notifications/helpers/html.ts

/** Escapa caracteres peligrosos para HTML */
export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function trunc(s: unknown, max = 120): string {
  const str = String(s ?? "");
  return str.length > max ? str.slice(0, max) + "…" : str;
}

/** Renderiza pares clave/valor en una tabla simple */
export function renderKV(
  title: string,
  payload?: Record<string, unknown>,
  truncate = 120
): string {
  if (!payload || typeof payload !== "object") return "";
  const rows = Object.entries(payload)
    .map(
      ([k, v]) =>
        `<tr><td><b>${escapeHtml(k)}</b></td><td>${escapeHtml(
          trunc(v, truncate)
        )}</td></tr>`
    )
    .join("");

  return `
    <section style="margin-top:12px">
      <h3>${escapeHtml(title)}</h3>
      <table border="1" cellspacing="0" cellpadding="6">${rows}</table>
    </section>
  `;
}

/** Renderiza un array de objetos como tabla (con límite de filas opcional) */
export function renderTable(opts: {
  title?: string;
  subtitle?: string;
  rows?: Record<string, unknown>[];
  maxRows?: number; // default 20
  truncate?: number; // default 120
}): string {
  const { title, subtitle, rows = [], maxRows = 20, truncate = 120 } = opts;
  if (!rows.length) {
    return `
      <section style="margin-top:12px">
        ${title ? `<h3>${escapeHtml(title)}</h3>` : ""}
        ${subtitle ? `<p>${escapeHtml(subtitle)}</p>` : ""}
        <p><i>Sin filas</i></p>
      </section>
    `;
  }

  const headers = Object.keys(rows[0]);
  const headerRow = headers.map((h) => `<th>${escapeHtml(h)}</th>`).join("");
  const bodyRows = rows
    .slice(0, maxRows)
    .map((r) => {
      const cols = headers
        .map((h) => `<td>${escapeHtml(trunc((r as any)[h], truncate))}</td>`)
        .join("");
      return `<tr>${cols}</tr>`;
    })
    .join("");

  const foot =
    rows.length > maxRows
      ? `<p><i>Mostrando ${maxRows} de ${rows.length} filas</i></p>`
      : "";

  return `
    <section style="margin-top:12px">
      ${title ? `<h3>${escapeHtml(title)}</h3>` : ""}
      ${subtitle ? `<p>${escapeHtml(subtitle)}</p>` : ""}
      <table border="1" cellspacing="0" cellpadding="6">
        <thead><tr>${headerRow}</tr></thead>
        <tbody>${bodyRows}</tbody>
      </table>
      ${foot}
    </section>
  `;
}

/** Renderiza JSON en <pre> escapado */
export function renderJSON(title: string, data: unknown): string {
  const body = escapeHtml(JSON.stringify(data, null, 2));
  return `
    <section style="margin-top:12px">
      <h3>${escapeHtml(title)}</h3>
      <pre>${body}</pre>
    </section>
  `;
}
```

---

#### 4.2.4) 📎 Adjuntos (filename seguro, buffer)

Genera nombres de archivo con timestamp y normaliza contenido a `Buffer` para evitar problemas de encoding.

```ts
// src/infrastructure/notifications/helpers/attachments.ts

export type NotifyAttachment = {
  filename: string;
  path?: string; // archivo local
  content?: string | Buffer; // contenido en memoria
  contentType?: string;
};

/** Nombre de archivo con timestamp seguro para FS/clients */
export function withIsoTimestamp(basename: string, ext: string): string {
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  return `${basename}_${ts}.${ext.replace(/^\./, "")}`;
}

/** Normaliza contenido a Buffer para evitar issues de encoding */
export function toBufferContent(content: string | Buffer): Buffer {
  return Buffer.isBuffer(content) ? content : Buffer.from(content, "utf-8");
}
```

---

#### 4.2.5) 🧭 Niveles de Log (string → LogLevel)

Mapea strings a `LogLevel` del logger para decidir el **umbral de alertas** por email.

```ts
// src/infrastructure/notifications/helpers/log-errors.ts
import { LogLevel } from "@jmlq/logger";

/** Mapea string a LogLevel */
export function toErrorLogLevel(s: string): LogLevel {
  const x = (s ?? "").trim().toUpperCase();
  switch (x) {
    case "INFO":
      return LogLevel.INFO;
    case "WARN":
    case "WARNING":
      return LogLevel.WARN;
    case "ERROR":
    default:
      return LogLevel.ERROR;
  }
}

// Comparación consistente (por si el enum no es 0/1/2)
export function levelErrorRank(l: LogLevel): number {
  switch (l) {
    case LogLevel.INFO:
      return 1;
    case LogLevel.WARN:
      return 2;
    case LogLevel.ERROR:
    default:
      return 3;
  }
}
```

---

#### 4.2.6) 🖼️ Auto-render HTML para notificaciones

Genera un `HTML` **por defecto** (título, contexto KV y datos como tabla/JSON) cuando no se provee `html`/`text` manual a `notify()`.

```ts
// src/infrastructure/notifications/helpers/auto-render.ts
import { escapeHtml, renderKV, renderTable, renderJSON } from "./html";
import type { NotifyAttachment } from "./attachments";
import { Addresses } from ".";

export type NotifyOptions = {
  subject: string;
  html?: string;
  text?: string;

  title?: string;
  context?: Record<string, unknown>;
  data?: unknown;
  maxRows?: number;
  truncate?: number;

  to: Addresses;
  cc?: Addresses;
  bcc?: Addresses;

  attachments?: NotifyAttachment[];
};

export function autoRenderHtml(opts: NotifyOptions): string {
  const title = opts.title ?? "Notificación";

  const contextBlock = opts.context
    ? renderKV("Contexto", opts.context, opts.truncate ?? 120)
    : "";

  let dataBlock = "";
  if (Array.isArray(opts.data)) {
    dataBlock = renderTable({
      title: "Datos",
      rows: opts.data as Record<string, unknown>[],
      maxRows: opts.maxRows ?? 20,
      truncate: opts.truncate ?? 120,
    });
  } else if (opts.data !== undefined) {
    dataBlock = renderJSON("Datos", opts.data);
  }

  return `
    <h2>${escapeHtml(title)}</h2>
    ${contextBlock}
    ${dataBlock}
  `;
}
```

---

## 5) 🧱 Puerto de dominio (contrato estable)

**Archivo**: `src/domain/ports/mailer.port.ts`

Define el **contrato** que el dominio espera para enviar emails, sin depender de la implementación concreta.

```ts
// src/domain/ports/mailer.port.ts
export type MailAddress = { name?: string; email: string };

export type SendEmailAttachment = {
  filename: string;
  path?: string;
  content?: string | Buffer;
  contentType?: string; // opcional
};

export type SendEmailOptions = {
  to: MailAddress | MailAddress[];
  subject: string;
  html: string;
  text: string;
  cc?: MailAddress | MailAddress[];
  bcc?: MailAddress | MailAddress[];
  attachments?: SendEmailAttachment[];
};

export interface MailerPort {
  send(options: SendEmailOptions): Promise<{ messageId: string }>;
}
```

---

## 6) 🏗️ Adapter de infraestructura

**Archivo**: `src/infrastructure/adapters/mailer/mailer.adapter.ts`

Implementa `MailerPort` usando `@jmlq/mailer`, mapeando el `SendEmailOptions` de dominio al `MailMessage` que entiende la librería.

```ts
// src/infrastructure/adapters/mailer.adapter.ts

import { mailerReady, type MailMessage } from "@jmlq/mailer";
import {
  MailerPort,
  SendEmailOptions,
} from "../../../domain/ports/mailer.port";
import { mapMailerEnv } from "../../../config/mappers";

export class MailerAdapter implements MailerPort {
  private service!: {
    sendEmail: (msg: MailMessage) => Promise<{ messageId: string }>;
  };
  private initialized = false;

  async init(): Promise<void> {
    // envs.mailer ya cumple IMailerEnv (MAIL_DRIVER, MAIL_HOST, etc.)
    this.service = await mailerReady(mapMailerEnv());
    this.initialized = true;
  }

  private ensureInit() {
    if (!this.initialized) {
      throw new Error(
        "MailerAdapter no inicializado. Llama a init() antes de usar."
      );
    }
  }

  async send(options: SendEmailOptions): Promise<{ messageId: string }> {
    this.ensureInit();

    // Normaliza destinatarios al tipo MailAddress (string | {email,name?})
    const to = Array.isArray(options.to) ? options.to : [options.to];
    const toAsMailAddress = to.map((a) =>
      typeof a === "string" ? a : { email: a.email, name: a.name }
    );

    const ccAsMailAddress = options.cc
      ? (Array.isArray(options.cc) ? options.cc : [options.cc]).map((a) =>
          typeof a === "string" ? a : { email: a.email, name: a.name }
        )
      : undefined;

    const bccAsMailAddress = options.bcc
      ? (Array.isArray(options.bcc) ? options.bcc : [options.bcc]).map((a) =>
          typeof a === "string" ? a : { email: a.email, name: a.name }
        )
      : undefined;

    const attachments = options.attachments?.map((a) =>
      a.path
        ? { filename: a.filename, path: a.path, contentType: a.contentType }
        : {
            filename: a.filename,
            content: a.content,
            contentType: a.contentType,
          }
    );

    const res = await this.service.sendEmail({
      subject: options.subject,
      htmlBody: options.html,
      textBody: options.text,
      to: toAsMailAddress,
      cc: ccAsMailAddress,
      bcc: bccAsMailAddress,
      attachments,
    });

    return { messageId: res.messageId ?? "unknown" };
  }
}
```

---

## 7) 📨 Notificaciones por correo (API de alto nivel)

### 7.1 `notify.ts` (render automático + adjuntos)

**Archivo**: `src/infrastructure/notifications/notify.ts`

Provee una **API única** para enviar emails. Si no pasas `html`/`text`, usa `autoRenderHtml`. Normaliza adjuntos y resuelve credenciales con `mapMailerEnv()`.

```ts
// src/infrastructure/notifications/notify.ts

import { envs } from "../../config/plugins/envs.plugin";
import { mapMailerEnv } from "../../config/mappers";
import {
  toRecipients,
  escapeHtml,
  renderKV,
  renderTable,
  renderJSON,
  toBufferContent,
  NotifyOptions,
  autoRenderHtml,
} from "./helpers";
import { mailerReady } from "@jmlq/mailer";

// ---------- API principal ----------------------------------------------------

export async function notify(opts: NotifyOptions): Promise<void> {
  const recipients = toRecipients(opts.to);
  if (!recipients.length) return; // sin destinatarios, no envía

  const subject = `[${envs.NODE_ENV ?? "dev"}] ${opts.subject}`;
  const html = opts.html ?? autoRenderHtml(opts);

  const attachments = opts.attachments?.map((a) =>
    a.path
      ? { filename: a.filename, path: a.path, contentType: a.contentType }
      : {
          filename: a.filename,
          content: a.content ? toBufferContent(a.content) : undefined,
          contentType: a.contentType,
        }
  );

  // Mapeo directo de tus MAILER_* a IMailerEnv que espera @jmlq/mailer
  const mailer = await mailerReady(mapMailerEnv());

  await mailer.sendEmail({
    to: recipients, // MailAddress[]
    subject,
    htmlBody: html,
    textBody: opts.text,
    cc: opts.cc ? toRecipients(opts.cc) : undefined,
    bcc: opts.bcc ? toRecipients(opts.bcc) : undefined,
    attachments,
  });
}

/** Helpers exportados por si quieres usarlos fuera */
export const NotifyRender = {
  escapeHtml,
  renderKV,
  renderTable,
  renderJSON,
};
```

---

### 7.2 `error-notifier.ts` (alertas de error críticas)

**Archivo**: `src/infrastructure/notifications/error-notifier.ts`.

Envía correos de **alerta** si `MAILER_ALERTS_ENABLED` está activo y el `LogLevel` supera el umbral. No rompe el flujo si el envío falla.

```ts
// src/infrastructure/notifications/error-notifier.ts

import { mailerReady } from "@jmlq/mailer";
import { envs } from "../../config/plugins/envs.plugin";
import { LogLevel } from "@jmlq/logger";
import { mapMailerEnv } from "../../config/mappers";
import { levelErrorRank, toErrorLogLevel } from "./helpers";

export type ErrorContext = {
  requestId?: string;
  route?: string;
  method?: string;
  ip?: string;
  userAgent?: string;
  extra?: Record<string, unknown>;
};

export async function notifyCriticalError(
  level: LogLevel,
  title: string,
  error: unknown,
  ctx: ErrorContext = {}
) {
  // Flags opcionales de alertas
  const alertsEnabled = Boolean(envs.mailer.MAILER_ALERTS_ENABLED);
  if (!alertsEnabled) return;

  const minLevel = toErrorLogLevel(
    String(envs.mailer.MAILER_ALERTS_MIN_LEVEL ?? "ERROR")
  );
  // Se envía si el nivel es >= MAILER_ALERTS_MIN_LEVEL
  if (levelErrorRank(level) < levelErrorRank(minLevel)) return;

  // Lista de destinatarios desde ENV (coma-separado)
  const toList = String(envs.mailer.MAILER_FROM ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  if (!toList.length) return;

  const message = (error as any)?.message ?? String(error);
  const stack = (error as any)?.stack;
  const subject = `[${envs.NODE_ENV ?? "dev"}] ${title}`;

  const html = `
    <h2>${title}</h2>
    <ul>
      <li><b>Nivel:</b> ${LogLevel[level]}</li>
      <li><b>Entorno:</b> ${process.env.NODE_ENV ?? "dev"}</li>
      ${ctx.requestId ? `<li><b>RequestId:</b> ${ctx.requestId}</li>` : ""}
      ${ctx.method ? `<li><b>Método:</b> ${ctx.method}</li>` : ""}
      ${ctx.route ? `<li><b>Ruta:</b> ${ctx.route}</li>` : ""}
      ${ctx.ip ? `<li><b>IP:</b> ${ctx.ip}</li>` : ""}
      ${ctx.userAgent ? `<li><b>UA:</b> ${ctx.userAgent}</li>` : ""}
    </ul>
    <h3>Mensaje</h3>
    <pre>${String(message)}</pre>
    ${
      stack
        ? `<h3>Stack</h3><pre style="white-space:pre-wrap">${String(stack)
            .slice(0, 10000)
            .replace(/</g, "&lt;")}</pre>`
        : ""
    }
    ${
      ctx.extra
        ? `<h3>Contexto</h3><pre style="white-space:pre-wrap">${JSON.stringify(
            ctx.extra
          ).slice(0, 10000)}</pre>`
        : ""
    }
  `;

  try {
    const mailer = await mailerReady(mapMailerEnv());
    await mailer.sendEmail({
      to: toList.map((email) => ({ email })),
      subject,
      htmlBody: html,
    });
  } catch (sendErr) {
    // no romper el flujo de la app por el notifier
    console.error("[notifyCriticalError] send failed:", sendErr);
  }
}
```

---

## 8) 🧪 (Opcional) Facade de inicialización de mailer

**Archivo**: `src/config/mailer/index.ts`.

Expone un **singleton** para inicializar el mailer una sola vez y **fallar temprano** si hay mala configuración.

```ts
// src/config/mailer/index.ts

import { MailerAdapter } from "../../infrastructure/adapters/mailer";

let _mailer: MailerAdapter | null = null;

export function getMailer() {
  if (!_mailer) {
    throw new Error(
      "Mailer no inicializado. Llama a mailerReady() en el arranque."
    );
  }
  return _mailer;
}

export async function mailerReady() {
  if (_mailer) return _mailer;
  _mailer = new MailerAdapter();
  await _mailer.init();
  return _mailer;
}

/** Azúcar sintáctico para usar desde cualquier lugar */
export const mail = () => getMailer();
```

---

## 9) 🎛️ Presentation: enviar CSV adjunto en `list`

**Archivo**: `src/presentation/user/controller.ts`

En el controller, tras recuperar usuarios, **arma un CSV en memoria** y lo envía por email **sin bloquear** la respuesta HTTP.

```ts
// src/presentation/user/controller.ts
import type { NextFunction, Request, Response } from "express";
import { UserRepository } from "../../domain/repositories";
import { CreateUserUseCase } from "../../domain/use-cases/user";
import { notify } from "../../infrastructure/notifications/notify";
import { MailAddress } from "@jmlq/mailer";
import { toCsv } from "../../shared/helpers";
import { renderTable } from "../../infrastructure/notifications/helpers";

export class UserController {
  constructor(private readonly userRepo: UserRepository) {}

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Usa el logger con contexto
      req.logger?.info("user.create.start", {
        requestId: req.requestId,
        body: req.body,
      });
      const useCase = new CreateUserUseCase(this.userRepo);
      const user = await useCase.execute(req.body);

      req.logger?.info("user.create.success", {
        requestId: req.requestId,
        userId: user.id,
      });
      res.status(201).json(user);
    } catch (err: any) {
      return next(err);
    }
  };

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      req.logger?.info("user.list.start", { requestId: req.requestId });

      const users = await this.userRepo.getUsers();

      // ---- Envío de correo con el listado ----
      // 1) Definir destinatario(s)
      const to: MailAddress[] = [
        {
          email: "jmlahuasiq@hotmail.com",
          name: "MLahuasi",
        },
        {
          email: "maurojre@hotmail.com",
          name: "MLahuasi",
        },
      ];

      // 2) Armar contenido
      const rows = users.map((u) => ({
        ID: u.id,
        Name: (u as any).name ?? "",
        Email: (u as any).email ?? "",
      }));

      const html =
        typeof renderTable === "function"
          ? renderTable({
              title: "Listado de Usuarios",
              subtitle: `Total: ${users.length}`,
              rows, // [{ID, Name, Email}]
            })
          : // Fallback simple si no tienes renderTable exportado:
            `<h2>Listado de Usuarios</h2>
             <p>Total: ${users.length}</p>
             <table border="1" cellspacing="0" cellpadding="6">
               <thead><tr><th>ID</th><th>Name</th><th>Email</th></tr></thead>
               <tbody>
                 ${rows
                   .map(
                     (r) =>
                       `<tr><td>${r.ID}</td><td>${r.Name}</td><td>${r.Email}</td></tr>`
                   )
                   .join("")}
               </tbody>
             </table>`;

      const subject = `Reporte: ${users.length} usuarios encontrados`;

      // Generar adjunto CSV
      const csv = toCsv(rows);
      const fileName = `users_${new Date()
        .toISOString()
        .replace(/[:.]/g, "-")}.csv`;

      // 3) Disparar el correo SIN bloquear la respuesta
      //    (loggea si falla, pero no rompas la petición)
      notify({
        to,
        subject,
        html,
        text: `Total: ${users.length} usuarios`,
        attachments: [
          {
            filename: fileName,
            content: Buffer.from(csv, "utf-8"), // también puede ser string, según tu adapter
            contentType: "text/csv",
          },
        ],
      }).catch((e) => {
        req.logger?.warn("user.list.email_failed", {
          error: (e as Error).message,
          requestId: req.requestId,
        });
      });
      // ---- fin envío de correo ----

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

---

## 10) 🚀 `app.ts`: inicialización temprana (opcional)

Durante el boot, **inicializa el mailer** (y el logger). Maneja señales y errores no controlados; en dichos casos se **notifica** por correo.

```ts
// src/app.ts
import { envs } from "./config/plugins/envs.plugin";
import { createServer } from "./presentation/server";
import { disposeLogs, flushLogs, loggerReady } from "./config/logger";
// Importar el bridge una sola vez inicializa el hook de AppError
import "./shared/errors/app-error-logger-bridge";
import { mailerReady } from "./config/mailer";
import { notifyCriticalError } from "./infrastructure/notifications";
import { LogLevel } from "@jmlq/logger";

async function bootstrap() {
  const logger = await loggerReady;

  // Asegura que el mailer esté listo ANTES de levantar el server
  await mailerReady();

  const app = createServer(logger);
  const server = app.listen(envs.PORT, envs.HOST, () => {
    console.log(`🚀 Server running at http://${envs.HOST}:${envs.PORT}`);
    logger.info("http.start", { host: envs.HOST, port: envs.PORT });
  });

  server.on("error", async (err: any) => {
    logger.error("http.listen.error", {
      message: err?.message,
      stack: err?.stack,
    });
    await flushLogs().catch(() => {});
    await disposeLogs().catch(() => {});
    process.exit(1);
  });

  // 3) Señales de apagado limpio
  const shutdown = async (reason: string, code = 0) => {
    logger.info("app.shutdown.begin", { reason });
    server.close(async () => {
      try {
        await flushLogs();
      } catch {}
      try {
        await disposeLogs();
      } catch {}
      logger.info("app.shutdown.end", { code });
      process.exit(code);
    });
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // Fallos no controlados
  process.on("unhandledRejection", async (err) => {
    const e = err as any;
    logger.error("unhandled.rejection", {
      message: e?.message,
      stack: e?.stack,
    });
    // email
    await notifyCriticalError(LogLevel.ERROR, "unhandled.rejection", e).catch(
      () => {}
    );
    await shutdown("unhandledRejection", 1);
  });

  process.on("uncaughtException", async (err) => {
    logger.error("uncaught.exception", {
      message: err.message,
      stack: err.stack,
    });
    // email
    await notifyCriticalError(LogLevel.ERROR, "uncaught.exception", err).catch(
      () => {}
    );
    await shutdown("uncaughtException", 1);
  });
}

bootstrap().catch(async (err) => {
  // Falla durante el bootstrap
  const logger = await loggerReady.catch(() => null);
  if (logger) {
    logger.error("bootstrap.fatal", {
      message: (err as Error)?.message,
      stack: (err as Error)?.stack,
    });
    await flushLogs().catch(() => {});
    await disposeLogs().catch(() => {});
  } else {
    // último recurso si el logger no llegó a inicializar
    console.error("Fatal error (no logger):", err);
  }
  process.exit(1);
});
```

---

#### [!DESCARGAR APP CON NOTIFICACIONES!](./assets/ml-dev-nodejs-example-with-notifications.zip)

---

[INICIO](./README.md) | - | [ANTERIOR](./clean-arch-errors.md) | - | [SIGUIENTE](./)
