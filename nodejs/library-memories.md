# 📑 Índice

- [🌐 HTTP / Networking](#🌐-http--networking)
  - [Axios](#axios)
- [🗄️ Bases de Datos / ORM](#🗄️-bases-de-datos--orm)
  - [Prisma](#prisma)
- [⏳ Utilidades / Fechas](#⏳-utilidades--fechas)
  - [get-age](#get-age)
- [🆔 Identificadores Únicos](#🆔-identificadores-únicos)
  - [uuid](#uuid)
- [🟢 Logging](#🟢-logging)
  - [winston](#winston)

# 📚 Memorias de Librerías (Proyecto Actual)

Estas son las librerías instaladas en este proyecto y su documentación rápida para recordar cómo usarlas.

---

## 🌐 HTTP / Networking

### [Axios](https://axios-http.com/)

- **Descripción:** Cliente HTTP basado en Promesas para Node.js y navegadores.
- **Casos de uso:** Hacer llamadas a APIs REST, manejar requests/response con interceptores.
- **Instalación:**

```bash
npm install axios
```

- **Ejemplo rápido:**

```ts
import axios from "axios";

async function fetchUser() {
  const res = await axios.get("https://jsonplaceholder.typicode.com/users/1");
  console.log(res.data);
}

fetchUser();
```

[📑 ÍNDICE](#📑-índice)

---

### 🗄️ Bases de Datos / ORM

### [Prisma](https://www.prisma.io/docs/orm/overview/introduction/what-is-prisma)

- **Descripción:** ORM moderno para Node.js y TypeScript. Permite trabajar con bases de datos relacionales usando modelos en lugar de queries SQL manuales.
- **Casos de uso:**

> > - Modelar entidades en un archivo `schema.prisma`.

```ts
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("POSTGRES_URL")
}

model todo {
  id          Int       @id @default(autoincrement())
  text        String    @db.VarChar
  createdAt   DateTime? @db.Timestamp()
  completedAt DateTime? @db.Timestamp()
}
```

> > - Generar migraciones automáticas hacia la base de datos.

```bash
    npx prisma migrate dev
```

> > - Sincronizar modelos desde una BDD existente.
> > - Integrarse fácilmente con controladores y DTOs para validación de datos.

- **Instalación:**

```bash
npm install prisma --save-dev
npx prisma init --datasource-provider postgresql
```

- **Comandos útiles:**

> - Crear modelos desde una BDD existente:

```bash
npx prisma db pull
```

> - Crear migraciones en desarrollo:

```bash
npx prisma migrate dev
```

> - Migraciones en producción (ejemplo con [Neon](https://neon.com/)):

```json
// package.json
"scripts": {
"prisma:migrate:prod": "prisma migrate deploy"
}
```

```bash
npm run prisma:migrate:prod
```

- **Ejemplo rápido:**

```ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // Crear un TODO
  const newTodo = await prisma.todo.create({
    data: {
      text: "Estudiar Prisma",
      createdAt: new Date(),
    },
  });
  console.log("Nuevo TODO:", newTodo);

  // Obtener todos los TODOs
  const allTodos = await prisma.todo.findMany();
  console.log("Lista de TODOs:", allTodos);

  // Actualizar un TODO (marcar como completado)
  const updatedTodo = await prisma.todo.update({
    where: { id: newTodo.id },
    data: { completedAt: new Date() },
  });
  console.log("TODO actualizado:", updatedTodo);

  // Eliminar un TODO
  const deletedTodo = await prisma.todo.delete({
    where: { id: newTodo.id },
  });
  console.log("TODO eliminado:", deletedTodo);
}

main()
  .catch((e) => console.error(e))
  .finally(async () => await prisma.$disconnect());
```

[📑 ÍNDICE](#📑-índice)

---

## ⏳ Utilidades / Fechas

### [get-age](https://www.npmjs.com/package/get-age)

- **Descripción:** Calcula edad a partir de una fecha de nacimiento.
- **Casos de uso:** Mostrar edad de usuarios en perfiles o reportes.
- **Instalación:**

```bash
npm install get-age
```

- **Ejemplo rápido:**

```ts
import getAge from "get-age";

const age = getAge("1981-03-21"); // formato ISO recomendado
console.log(`Edad: ${age}`); // Ej: Edad: 44
```

[📑 ÍNDICE](#📑-índice)

---

## 🆔 Identificadores Únicos

### [uuid](https://www.npmjs.com/package/uuid)

- **Descripción:** Genera identificadores únicos universales (UUID).
- **Casos de uso:** IDs para usuarios, sesiones, transacciones, archivos.
- **Instalación:**

```bash
npm install uuid
```

- **Ejemplo rápido:**

```ts
import { v4 as uuidv4 } from "uuid";

const id = uuidv4();
console.log("Nuevo UUID:", id);
```

[📑 ÍNDICE](#📑-índice)

---

## 🟢 Logging

### [winston](https://github.com/winstonjs/winston)

- **Descripción:** Logger popular para Node.js con múltiples niveles y destinos..
- **Casos de uso:** Guardar logs en consola y archivos en aplicaciones Node.js.
- **Instalación:**

```bash
npm install winston
```

- **Ejemplo rápido:**

```ts
import winston from "winston";

const logger = winston.createLogger({
  level: "info",
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "app.log" }),
  ],
});

logger.info("Servidor iniciado con Winston");
logger.error("Algo salió mal...");
```

[📑 ÍNDICE](#📑-índice)

📌 _Este documento forma parte de **ml-dev-handbook**._
