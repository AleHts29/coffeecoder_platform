# DESIGN — CoffeeCoder · Sistema "Grafito"

Aprobado por el dueño del proyecto tras comparación de variantes.
Fuente de verdad de tokens: `web/src/styles/tokens.css`. Este documento
explica cómo usarlos. Nada de este sistema se cambia sin aprobación.

## Filosofía

Base gris neutra absoluta (sin temperatura — el error a evitar es que
la UI parezca "Night Shift"); toda la identidad vive en el acento
caramelo, la tipografía y los micro-detalles de marca. La calidez de
"café" se expresa en momentos de marca, no en el color de fondo.

## Paleta

| Token | Hex | Uso |
|---|---|---|
| surface-0 | `#141414` | fondo de página |
| surface-1 | `#1B1B1D` | cards, sidebar, paneles |
| surface-2 | `#242426` | hover, item activo, secundarios |
| border | `#2C2C2E` | bordes por defecto (0.5px) |
| border-strong | `#3A3A3C` | bordes con énfasis |
| ink | `#EDEDEB` | texto primario |
| ink-soft | `#9A9A97` | texto secundario |
| ink-faint | `#7A7A78` | metadatos, terciario |
| ink-disabled | `#48484A` | deshabilitado |
| accent | `#E08E33` | caramelo: acción primaria, progreso, activo |
| accent-hover | `#EDA04D` | hover del acento |
| on-accent | `#141414` | texto sobre caramelo |
| danger | `#E2695C` | destructivo (solo admin) |
| danger-border | `#7A3B34` | borde destructivo |
| danger-border-hover | `#A04A40` | hover borde destructivo |
| danger-surface | `#3A211D` | fondo hover destructivo |

Semántica del acento: caramelo = "tu atención va acá". Progreso,
acción primaria, estado activo, checks de completado. No usar verde
de éxito: el completado también es caramelo (monocromía cálida).

## Tipografía

- **Space Grotesk** (400/500): UI, títulos, prosa. Nunca 600+.
- **JetBrains Mono** (400/500): TODO dato — duraciones, timestamps,
  porcentajes, numeración de módulos/lecciones, precios, métricas,
  badges técnicos. Esta regla es la firma visual de la marca.
- Wordmark: `coffeecoder_` en JetBrains Mono 500, con el cursor `_`
  en caramelo, precedido del ícono de café (Tabler `ti-coffee`) en
  caramelo.

## Radios y bordes

- Controles (botones, inputs, pills): 8px.
- Cards y paneles: 12px.
- Bordes de 0.5px por defecto; la elevación se expresa con cambio de
  superficie (surface-1 → surface-2), no con sombras. Sin box-shadow.

## Jerarquía de botones (variante A aprobada)

1. **Primario**: fondo accent, texto on-accent, hover accent-hover.
   **Máximo uno por vista.** Comprar, Continuar, Guardar.
2. **Secundario**: fondo surface-2, borde border-strong, texto ink;
   hover aclara fondo (`#2E2E30`) y borde (`#48484A`). Relleno sólido,
   no outline hueco. Acciones de soporte frecuentes.
3. **Ghost**: transparente, texto ink-soft; hover fondo surface-2 y
   texto ink. Cancelar, navegación, terciarias.
4. **Destructivo**: transparente, borde danger-border, texto danger;
   hover fondo danger-surface. **Solo admin.** Es el único rojo de la
   plataforma. La versión rellena (fondo danger, texto on-accent)
   existe únicamente como confirmación final dentro de un diálogo.

Disabled (todos los niveles): fondo surface-1, borde border, texto
ink-disabled, cursor not-allowed.

Implementación: componente `Button` con prop `variant` que mapea 1:1
a estos niveles. La jerarquía la fuerza el componente, no la disciplina.

## Nomenclatura de niveles

Dificultad como tueste de café: **suave / medio / intenso**
(coincide con el CHECK de la base). Se muestra como badge outline en
mono, ej: `carrera · tueste medio`.

## Layouts de referencia (aprobados en mockups)

**Player (layout teatro):** grid de dos columnas, video 16:9
protagonista a la izquierda; sidebar derecha ~320px en desktop,
colapsable a modo cine. Sidebar: nombre del curso, barra de progreso +
`42% · 12/28 lecciones` en mono, módulos como acordeones (completados
colapsados con check caramelo), lección activa con fondo surface-2 y
borde izquierdo caramelo de 2px, duraciones en mono a la derecha.
Bajo el video: eyebrow en mono (`módulo 02 · lección 07`), título,
fila de acciones (Marcar completada secundario a la izquierda,
Siguiente lección primario a la derecha), tabs con subrayado caramelo.
En mobile: sidebar como bottom sheet.

**Página de carrera:** hero con badge de tueste, título, promesa,
metadatos en mono; card de compra a la derecha (precio grande en mono,
CTA primario, tres promesas con íconos caramelo: acceso de por vida,
actualizaciones, certificado; nota de cuotas). Debajo, "El camino":
lista vertical con línea conectora de 2px y nodos de estado por curso
(check relleno caramelo / anillo caramelo con play + barra + CTA
Continuar / círculo vacío border-strong).

**Dashboard:** saludo + `racha de N días · X h esta semana` en mono;
card hero "seguí donde quedaste" (thumbnail, lección, curso, barra,
posición `mm:ss / mm:ss` en mono, CTA Continuar primario); "Mis
carreras" con barra general + segmentos por curso (lleno = completado,
55% opacidad = en curso, surface-2 = pendiente); "Cursos sueltos" en
grid de cards con barra fina.

## Voz y microcopy

Español rioplatense neutro profesional (voseo: "seguí", "comprá",
"reintentá"). Directo, sin exclamaciones gratuitas, sin diminutivos.
Errores accionables: qué pasó y qué hacer, nunca códigos crudos.
Estados vacíos con invitación a actuar, no con lamento. Los momentos
de marca (bienvenida, curso completado) pueden usar guiños de café
con sobriedad — un guiño por pantalla como máximo.

## Accesibilidad

Contraste AA mínimo en todos los pares (la paleta ya lo cumple:
verificar al crear combinaciones nuevas). Focus visible con ring
caramelo. Targets táctiles ≥ 44px en mobile. `prefers-reduced-motion`
respetado: las transiciones son cortas (120–150 ms) y solo de
background/color; nada se anima solo.
