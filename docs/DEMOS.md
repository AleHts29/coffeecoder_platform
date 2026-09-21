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

## Audio (opcional, y cuando corresponde)

En cursos donde el sonido enseña —producción musical, DSP— la demo puede
sumar una capa de audio que reproduce en vivo lo mismo que dibuja. Reglas:

1. **Motor: Web Audio API nativa.** Todo se sintetiza en el cliente
   (`OscillatorNode`, `GainNode`, `BiquadFilterNode`, `DelayNode`,
   `ConvolverNode`, `DynamicsCompressorNode`, `PeriodicWave`, buffers
   generados por código). Sin archivos de audio, sin samples, sin
   librerías: la demo sigue siendo autocontenida y sin red.
2. **Opt-in, sin autoplay.** Carga en silencio. El `AudioContext` se crea
   y se reanuda recién en el primer gesto del alumno sobre el control de
   sonido.
3. **El audio es complemento, no requisito.** La demo se entiende sin
   sonido; el visual alcanza. Nunca es la única vía al concepto.
4. **Nivel prudente.** Master gain ≈ 0.15 por defecto, con volumen y mute.
5. **Anti-click.** Toda nota entra y sale con rampa de gain de 5–15 ms
   (`setTargetAtTime` / `linearRampToValueAtTime`). Nunca cortar en seco.
6. **Sin drones eternos.** Los tonos sostenidos suenan mientras el alumno
   mantiene el control, o tienen auto-stop.
7. **Una sola fuente de verdad.** El audio lee los mismos controles que
   alimentan el dibujo.
8. **Limpieza.** `suspend()` del contexto cuando la pestaña se oculta o
   la demo se va, para no dejar audio corriendo en mobile.

### Helper canónico

Va inline en cada demo con sonido, **idéntico**, para que se mantenga
fácil. No lo reescribas: copialo tal cual.

```html
<div class="audio">
  <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
  <label for="vol" class="label">Volumen</label>
  <input id="vol" type="range" min="0" max="100" step="1" value="15">
  <span class="value" id="volOut">15%</span>
</div>
```

```js
// --- audio: patrón compartido de docs/DEMOS.md (no modificar) ---
function createAudio() {
  var ctx = null, master = null, on = false;
  function ensure() {
    if (!ctx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.15;
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }
  return {
    on: function () { return on; },
    ctx: function () { return ctx; },
    master: function () { return master; },
    // Habilita o silencia. Devuelve el estado nuevo. Es el gesto que
    // crea el AudioContext (política de autoplay de los browsers).
    toggle: function () {
      on = !on;
      if (on) ensure(); else if (ctx) ctx.suspend();
      return on;
    },
    setVolume: function (v) { if (master) master.gain.value = v; },
    suspend: function () { if (ctx && ctx.state === 'running') ctx.suspend(); },
    // Rampa anti-click: nunca asignar .value de un gain que está sonando.
    ramp: function (param, value, seconds) {
      var t = ctx ? ctx.currentTime : 0;
      param.cancelScheduledValues(t);
      param.setValueAtTime(param.value, t);
      param.linearRampToValueAtTime(value, t + (seconds || 0.01));
    }
  };
}
var audio = createAudio();
document.addEventListener('visibilitychange', function () {
  if (document.hidden) audio.suspend();
});
window.addEventListener('pagehide', function () { audio.suspend(); });
```

El botón de sonido usa la jerarquía de siempre: activo en caramelo
`#E08E33` con texto `#141414`, en reposo `#242426` con borde `#3A3A3C`.
Sirve además de indicador de "suena ahora", para no depender del oído.

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
- `seed/demos/envolvente-adsr.html`: envolvente con gate y audio
  sintetizado (referencia del helper de audio).
