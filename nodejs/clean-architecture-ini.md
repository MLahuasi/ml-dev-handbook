# 🚀 Paso a paso para crear una aplicación

## 1) Configuración inicial del entorno

```bash
# Instalar Node con NVM (Windows/Linux)
nvm install v20.19.0
nvm use v20.19.0
# Se puede instalar cualquier versión actualizada de node.js
```

## 2) Crear estructura base de la aplicación

Ejecutar el archivo [`bootstrap-structure.ps1`](./assets/bootstrap-structure.ps1) con `PowerShell`:

> - Crear un directorio raíz.
> - Descargar el archivo en el directorio raíz.
> - Ingresar al directorio con `PowerShell` y ejecutar:

```bash
  Set-ExecutionPolicy -Scope Process Bypass -Force; .\bootstrap-structure.ps1
```

## 3) Configurar el proyecto

### 3.1) Instalación de dependencias

> - Crear proyecto `Node.js` (`package.json`)

```bash
npm init -y
```

> - **Instalar de dependencias proyecto:**

> > `Dependencias de runtime`

```bash
npm install express dotenv env-var
```

> > `Dependencias de desarrollo`

```bash
npm install -D typescript @types/node @types/express ts-node-dev rimraf jest @types/jest ts-jest supertest @types/supertest

# NOTA: Esta instalación actualmente (16-09-2025) presenta warns por dependencias deprecated(inflight y glob) por lo que se ejecutó con la versión jest@^29
npm install -D typescript @types/node @types/express ts-node-dev rimraf jest@^29 @types/jest@^29 ts-jest@^29 supertest @types/supertest
```

> > **NOTA**: Si se quiere saber que paquetes dependen de `inflight` y `glob`:

```bash
npm ls inflight
npm ls glob
```

#### 📦 Las dependencias de producción son:

> > > - `express` → Framework minimalista para Node.js que facilita la creación de servidores web y APIs REST.
> > >   > > - Proporciona enrutamiento (definir rutas como GET /users), middlewares (para parsear JSON, autenticación, logging, etc.), y manejo de respuestas HTTP.
> > >   > > - Es la base de la mayoría de proyectos backend con Node.js.
> > > - `dotenv` → Carga las variables de entorno definidas en un archivo .env dentro de process.env.
> > >   > > - Permite mantener configuraciones sensibles o específicas por entorno (puertos, claves API, URLs de BD) fuera del código fuente.
> > >   > > - Ejemplo: en `.env` defines `PORT=3000`, y luego en código accedes con `process.env.PORT`.
> > > - `env-var` → Librería que valida y convierte las variables de entorno de forma segura.
> > >   > > - Se complementa con `dotenv`: después de cargar las variables, con `env-var` se pueden asegurar tipos (números, booleanos, arrays) y establecer valores por defecto si no están definidos.
> > >   > > - Evitar errores típicos como que `PORT` llegue como texto `"3000"` en lugar de número.

#### 📦 Las dependencias de desarrollo son:

> > > - `typescript` → compilador de TypeScript.
> > > - `@types/node` → tipados de Node.js.
> > > - `@types/express` → tipados para Express.
> > > - `ts-node-dev` → ejecuta proyectos TypeScript en modo desarrollo con recarga en caliente.
> > > - `rimraf` → utilidad para limpiar la carpeta dist antes del build.
> > > - `jest` → framework de testing ampliamente usado en Node.js.
> > > - `@types/jest` → tipados de Jest para usar en proyectos TypeScript.
> > > - `ts-jest` → transformador que permite ejecutar directamente código TypeScript dentro de Jest.
> > > - `supertest` → librería para pruebas de integración con aplicaciones Express/HTTP.
> > > - `@types/supertest` → tipados para supertest.

> - Añadir a scripts para básicos (`package.json`):

```json
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only src/app.ts",
    "build": "rimraf dist && tsc -p tsconfig.json",
    "start": "npm run build && node dist/app.js",
  }
```

### 3.3) Configurar Jest (Pruebas Unitarias)

> - Pegar configuración de `Jest` en el archivo `jest.config.cjs`:

```js
/** @type {import('@jest/types').Config.InitialOptions} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/__tests__/**/*.(test|spec).ts", "**/?(*.)+(test|spec).ts"],
  moduleFileExtensions: ["ts", "js", "json"],
  testPathIgnorePatterns: ["/node_modules/", "/dist/"],
  // Evita la cadena de cobertura Istanbul (y sus deps viejas):
  coverageProvider: "v8",
};
```

> - Añadir a scripts para pruebas (`package.json`):

```json
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
```

### 3.2) Configuración de TypeScript

> - Pegar configuración de `TypeScript` en el archivo `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "Node",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "types": ["node", "jest"]
  },
  "include": ["src", "**/*.test.ts", "**/*.spec.ts"]
}
```

## 4) Cargar datos iniciales (dummy)

> - Actualizar los siguientes archivos para que funcione el modelo default:

```json
// src/infrastructure/datasources/json/users.json
[
  { "id": 1, "name": "Alice Doe", "email": "alice@example.com" },
  { "id": 2, "name": "Bob Roe", "email": "bob@example.com" }
]
```

```ts
// src/infrastructure/datasources/json/users.datasource.ts
import { promises as fs } from "node:fs";
import path from "node:path";

export type RawUser = { id: number; name: string; email: string };

// En CJS __dirname existe
const JSON_FILE = path.resolve(__dirname, "users.json");

export class UserJsonDatasource {
  static async load(): Promise<RawUser[]> {
    const content = await fs.readFile(JSON_FILE, "utf8");
    return JSON.parse(content) as RawUser[];
  }
  static async save(users: RawUser[]): Promise<void> {
    await fs.writeFile(JSON_FILE, JSON.stringify(users, null, 2), "utf8");
  }
}
```

[INICIO](./README.md) | - | [SIGUIENTE](./clean-architecture-structure.md)
