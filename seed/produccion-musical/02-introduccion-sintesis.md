## Qué es sintetizar

Sintetizar es **generar sonido por medios electrónicos**, sin instrumentos
acústicos ni mecánicos de por medio. El que hace el trabajo es el
**oscilador**: un circuito que produce una señal eléctrica que se repite
muchas veces por segundo. Esa repetición es la que percibimos como altura
(la nota), y la **forma** de esa repetición es la que percibimos como
timbre (el color del sonido).

Un oscilador puede producir varias formas de onda básicas:

- **Sinusoidal (sine)**
- **Triangular (triangle)**
- **Diente de sierra (sawtooth)**
- **Cuadrada (square)**
- **Ruido (noise)**

::demo[formas-de-onda]

Movete entre las formas y mirá dos cosas al mismo tiempo: la forma en el
tiempo (izquierda) y su **espectro de armónicos** (derecha). El timbre no
es otra cosa que qué armónicos están presentes y con qué fuerza.

## Los tipos de onda, uno por uno

**Sinusoidal.** La más simple. Es una sola frecuencia, sin armónicos: solo
la fundamental. Suena redonda y hueca, como un silbido o un diapasón. Es la
materia prima; todas las demás se pueden pensar como sumas de sinusoides.

**Triangular.** Tiene solo **armónicos impares** (la fundamental, el 3°, el
5°…), pero cada uno cae muy rápido en amplitud (proporcional a 1/n²). Por eso
suena parecida a la sinusoidal, apenas un poco más brillante. Buena para
sub-bajos y sonidos suaves.

**Diente de sierra.** Es la más **rica** de las básicas: contiene **todos**
los armónicos, pares e impares, con amplitud que cae 1/n. Ese espectro
completo la hace ideal para síntesis sustractiva: como trae de todo, tenés
material de sobra para filtrar. Es el punto de partida clásico de bajos y
leads.

**Cuadrada.** Su espectro son **solo armónicos impares** (f, 3f, 5f…) con
amplitud 1/n. Ojo con un mito: la cuadrada **no** es "la más compleja" —la
sierra tiene más armónicos. Lo que la distingue es ese sonido hueco y
"amaderado" (pensá un clarinete o un chiptune). Dato de color: en
electrónica digital la onda cuadrada es la base de las señales de pulso
(los 1 y 0); de ahí que también se la llame generador de pulsos.

**Ruido (noise).** Es **inarmónico**: no tiene una fundamental definida ni
relación tonal entre sus componentes, es energía repartida por todo el
espectro. No sirve para tocar melodías, pero es oro para percusión,
transientes, hi-hats, vientos y efectos.

## Cómo se sintetiza: dos caminos

- **Síntesis sustractiva.** Arrancás de una onda rica en armónicos (típico:
  sierra o cuadrada) y **le sacás** frecuencias con filtros —pasa-bajos,
  pasa-altos, pasa-banda, notch— hasta llegar al sonido que buscás. Es el
  método más común y el que vas a usar en Analog.

- **Síntesis FM (frecuencia modulada).** Desarrollada por John Chowning en
  1973. La idea: si a un oscilador (la portadora) lo modulás en frecuencia
  con otro oscilador (el modulador) y llevás esa modulación al rango audible
  (por encima de 20 Hz), dejás de escuchar un vibrato y empiezan a aparecer
  **bandas laterales**: frecuencias nuevas que no estaban en ninguna de las
  dos ondas. Con solo dos osciladores generás timbres muy complejos. Es otro
  mundo respecto a la sustractiva y lo vemos más adelante.
