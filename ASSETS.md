# Gestión de assets (imágenes y archivos)

## Estructura recomendada
```
assets/
 ┣ images/            # PNG, JPG, SVG
 ┣ diagrams/          # Mermaid, PlantUML, draw.io (fuentes + exportados)
 ┣ snippets/          # Fragmentos de código reutilizables
 ┗ downloads/         # PDFs y adjuntos pesados
```

## Reglas
- Usa **rutas relativas** en los Markdown: `![alt](../assets/images/diagrama.png)`
- Nombra en **kebab-case** y descriptivo: `clean-architecture-layers.png`
- Versiona la **fuente editable** del diagrama junto al exportado (ej: `.drawio` + `.png`).
- Prefiere diagramas en **Mermaid** dentro del Markdown cuando sea posible.
- Evita archivos > 10MB; si hace falta, colócalos en `downloads/` y enlázalos.
- No incluir `.git` al compartir el repo como ZIP.
