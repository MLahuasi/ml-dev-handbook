# 🌐 HTTP en Node.js: HTTP/1.1 vs HTTP/2

`HTTP` es el protocolo que permite la comunicación entre `clientes` (como navegadores) y `servidores web`.

Con Node.js podemos crear servidores básicos usando tanto `HTTP/1.1` como `HTTP/2`.

Este apunte resume las diferencias, características y ejemplos de uso de ambos.

## 📖 HTTP/1.1

> - Publicado inicialmente en **1997 (RFC 2068)** y consolidado en **1999 (RFC 2616)**.
> - Se basa en **texto plano** : las peticiones (GET, POST…) y las respuestas se envían como texto.
> - **Limitación**: cada conexión solo maneja una petición a la vez → puede generar lentitud en páginas con muchos recursos.

### 🚀 Crear un servidor básico

```ts
import http from "http";

const server = http.createServer((req, res) => {
  console.log(req.url);

  // Definir respuesta
});

server.listen(8080, () => {
  console.log(`Server running: http://localhost:8080`);
});
```

Al acceder a `http://localhost:8080/mensaje`, el servidor recibe la ruta `/mensaje`.

### 📝 Ejemplos de respuestas

#### 🔹 Texto o HTML

```ts
const server = http.createServer((req, res) => {
  console.log(req.url);

  res.writeHead(200, { "Content-Type": "text/html" });
  res.write(`<h1>URL ${req.url}</h1>`);
  res.end();
});
```

#### 🔹 JSON

```ts
const server = http.createServer((req, res) => {
  console.log(req.url);

  const data = { name: "John Doe", age: 30, city: "New York" };
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
});
```

#### 🌍 Manejo básico de rutas

```ts
import fs from "fs";

/*
    .....
*/

const server = http.createServer((req, res) => {
  if (req.url === "/") {
    const htmlFile = fs.readFileSync("./public/index.html", "utf-8");
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(htmlFile);
  } else {
    res.writeHead(404, { "Content-Type": "text/html" });
    res.end("Página no encontrada");
  }
});
```

---

# 📖 HTTP/2

> - Basado en `SPDY` (un proyecto experimental de Google).
> - Publicado como **RFC 7540 en 2015**.
> - Mantiene la `misma semántica` de **HTTP/1.1** (métodos, códigos, URIs, headers).
> - Mejoras clave:
>   > - `Multiplexación`: varias solicitudes en una sola conexión TCP.
>   > - Compresión de cabeceras.
>   > - Priorización de solicitudes.
>   > - Server Push (el servidor puede enviar recursos sin que el cliente los pida).

## 🔐 Crear un servidor seguro

`HTTP/2` en Node requiere un **servidor seguro** con certificados.

```ts
import http2 from "http2";
import fs from "fs";

const server = http2.createSecureServer(
  {
    key: fs.readFileSync("./keys/server.key"),
    cert: fs.readFileSync("./keys/server.crt"),
  },
  (req, res) => {
    console.log(req.url);
    // Definir operaciones
  }
);

server.listen(8443, () => {
  console.log("HTTP/2 server running on https://localhost:8443");
});
```

### 🔑 Generar certificados

#### Linux / macOS

```bash
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
```

#### Windows

1. Instalar [Git](https://git-scm.com/downloads/win) (incluye `OpenSSL`).
2. Ubicar `openssl.exe` en `Program Files\Git\usr\bin`.
3. Agregar esa ruta al `PATH`.
4. Ejecutar el mismo comando anterior en PowerShell.

```bash
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
```

5. Esto genera:

> > - `server.key`
> > - `server.crt`

**NOTA**: 👉 Se recomienda guardarlos en una carpeta keys/.
