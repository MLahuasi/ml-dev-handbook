# 📚 Temario

## 1) n8n (guía principal)

- [¿Qué es n8n?](./01-n8n.md#qué-es-n8n)
  - [Características principales](./01-n8n.md#características-principales)
  - [Arquitectura simplificada](./01-n8n.md#arquitectura-simplificada)
  - [¿Por qué es tan popular?](./01-n8n.md#por-qué-es-tan-popular)
  - [Comparativa con otras herramientas](./01-n8n.md#comparativa-con-otras-herramientas)
  - [Casos de uso](./01-n8n.md#casos-de-uso)
  - [Recursos adicionales](./01-n8n.md#recursos-adicionales)
  - [Beneficios para empresas y equipos](./01-n8n.md#beneficios-para-empresas-y-equipos)
  - [Buenas prácticas recomendadas](./01-n8n.md#buenas-prácticas-recomendadas)
  - [¿Cuándo elegir n8n?](./01-n8n.md#cuándo-elegir-n8n)
- [¿Qué puedo hacer con n8n?](./01-n8n.md#qué-puedo-hacer-con-n8n)
- [Crear una cuenta y usar la prueba gratuita](./01-n8n.md#crear-una-cuenta-en-n8n-y-usar-la-prueba-gratuita)
- [Ejecutar n8n localmente mediante NPX](./01-n8n.md#ejecutar-n8n-localmente-mediante-npx)
- [Ejecutar n8n localmente mediante Docker](./01-n8n.md#ejecutar-n8n-localmente-mediante-docker)
- [Ejemplo: Configurar ambiente local](./01-n8n.md#️-ejemplo-configurar-ambiente-local)
- [Ejemplo: Crear contenedor n8n (Docker Compose)](./01-n8n.md#️-ejemplo-crear-contenedor-n8n)

---

## 2) Introducción a n8n (conceptos)

- [Introducción a n8n](./02-INTRO.md#introducción-a-n8n)
  - [Temario](./02-INTRO.md#temario)
  - [Nodos en n8n](./02-INTRO.md#-nodos-en-n8n)
    - [¿Qué son y cómo funcionan?](./02-INTRO.md#-qué-son-los-nodos-y-cómo-funcionan-dentro-de-un-workflow)
  - [Diferencia entre tipos de nodos](./02-INTRO.md#-diferencia-entre-tipos-de-nodos-en-n8n)
    - [Trigger Nodes (disparadores)](./02-INTRO.md#1%EF%B8%8F⃣-trigger-nodes-nodos-disparadores)
      - [Ejemplo: nodos de entrada (Trigger + Google Sheets Read)](./02-INTRO.md#-ejemplo-práctico-configuración-de-nodos-de-entrada)
    - [Nodos de procesamiento / transformación](./02-INTRO.md#2%EF%B8%8F⃣-nodos-de-procesamiento--transformación)
      - [Ejemplo: Edit Fields (Set)](./02-INTRO.md#-ejemplo-práctico-editar-agregar-y-transformar-datos)
      - [Ejemplo: Filter](./02-INTRO.md#-ejemplo-práctico-filtrar-información)
      - [Ejemplo: Aggregate](./02-INTRO.md#-ejemplo-práctico-consolidar-información-aggregate)
    - [Nodos de salida](./02-INTRO.md#3%EF%B8%8F⃣-nodos-de-salida)
      - [Ejemplo: HTTP Request (API externa)](./02-INTRO.md#-ejemplo-práctico-integración-con-api-externa)
      - [Ejemplo: Google Sheets Update](./02-INTRO.md#-ejemplo-práctico-actualizar-datos-en-google-sheets)
      - [Ejemplo: Gmail (un correo por registro)](./02-INTRO.md#-ejemplo-práctico-notificación-por-correo-gmail)
      - [Ejemplo: Gmail + Aggregate (consolidado)](./02-INTRO.md#-ejemplo-práctico-enviar-consolidado-por-correo-gmail--aggregate)
  - [Resumen general](./02-INTRO.md#-resumen-general)
  - [Nodos prácticos (más usados)](./02-INTRO.md#-nodos-prácticos-ejemplos-más-usados)
  - [Buenas prácticas en nodos](./02-INTRO.md#-buenas-prácticas-en-nodos)

---

## 3) Accesos rápidos

- **Google Sheets (Read):** [guía](./tool-n8n-node-google-sheet-read.md)
- **Google Sheets (Update):** [guía](./tool-n8n-node-google-sheet-update.md)
- **HTTP Request:** [guía](./tool-n8n-node-http-request.md)
- **Gmail (Send a Message):** [guía](./tool-n8n-node-gmail-send-message.md)
- **Edit Fields (Set):** [guía](./tool-n8n-node-edit-fields-set.md)
- **Filter:** [guía](./tool-n8n-node-filter.md)
- **Aggregate:** [guía](./tool-n8n-node-aggregate.md)
- **Trigger → Manually:** [guía](./tool-n8n-node-trigger-manually.md)
