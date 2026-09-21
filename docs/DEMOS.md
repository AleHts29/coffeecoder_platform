# DEMOS — gráficos interactivos dentro de las lecciones

Una demo es un archivo HTML autocontenido que el alumno manipula
(sliders, botones) para ver un concepto en movimiento. Vive en la
biblioteca de demos de un curso y se inserta en el texto de una lección
con una línea `::demo[slug]`. La plataforma la muestra dentro de una
card con el rótulo "demo interactiva", en un iframe aislado.

Este documento es el contrato: cualquier demo nueva (hecha a mano o
generada con Claude) tiene que cumplirlo. Si Claude genera una demo,
pasale este archivo como consigna.

## Qué es una buena demo

- Muestra UNA idea y su control principal. Si necesita más de 3
  controles, probablemente son dos demos.
- El movimiento explica algo que una imagen quieta no puede (un
  bloqueo, una modulación, un orden de ejecución). Si no, alcanza con
  una imagen en el texto.
- La explicación va en el texto de la lección, no dentro de la demo.
  Dentro solo van rótulos cortos de los controles y de cada gráfico.

## Reglas técnicas (obligatorias)

1. **Un solo archivo.** HTML, CSS y JS en línea. Sin `<script src=`,
   sin imports, sin librerías externas. Canvas o SVG a mano.
2. **Sin red.** Nada de `fetch`, `XMLHttpRequest`, `WebSocket`,
   `EventSource`, ni `<iframe>`. La única carga externa permitida es
   la hoja de Google Fonts (Space Grotesk y JetBrains Mono).
3. **Sin storage ni acceso al exterior.** Nada de `localStorage`,
   `sessionStorage`, `document.cookie`, `window.parent`, `window.top`.
   (La plataforma lo bloquea igual con sandbox; si la demo lo usa, se rompe.)
4. **Tamaño:** menos de 200 KB. Imágenes, si hacen falta, como data URI.
5. **Ancho fluido, alto fijo.** Ocupa el 100 % del ancho disponible
   (desde 300 px en mobile hasta ~720 px) y declara su alto en el admin
   (`height_px`). Nada de scroll interno.
6. **`prefers-reduced-motion`:** si está activo, no animar solo; la demo
   se actualiza cuando el alumno toca un control.
7. **Accesible:** cada control con `<label>`, foco visible, y un texto
   `aria-label` o descripción en los canvas.

## Estilo (Grafito)

- Fondo `#1B1B1D` en `body` (la demo se ve sobre la card de la lección),
  `margin: 0`, `padding: 12px`, `color-scheme: dark`.
- Texto `#EDEDEB`; rótulos y metadatos chicos `#8C8C8A`.
- Ejes, grillas y bordes `#2C2C2E`; líneas secundarias `#5A5A5C`.
- Acento caramelo `#E08E33` para lo que el alumno tiene que mirar (la
  señal principal, el valor que cambia, el estado activo). Un solo
  foco de color por demo.
- Tipografía: Space Grotesk para rótulos, JetBrains Mono para valores
  numéricos (Hz, %, ms, contadores). Pesos 400/500.
- Controles: `input[type=range]` con `accent-color: #E08E33`; botones
  con la jerarquía de `DESIGN.md` (el principal en caramelo, el resto
  secundario gris).
- Sin gradientes, sombras ni efectos.

## Plantilla mínima

```html
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .label { font-size: 12px; color: #8C8C8A; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px; }
  input[type=range] { accent-color: #E08E33; width: 100%; }
</style>
</head>
<body>
  <!-- controles, canvas/svg -->
  <script>
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
    // lógica de la demo
  </script>
</body>
</html>
```

## Ejemplos de referencia

- `seed/demos/lfo-amplitud.html`: tres canvas animados y dos sliders.
- `seed/demos/channels-buffer.html`: SVG con estado y botones, sin
  animación continua.
