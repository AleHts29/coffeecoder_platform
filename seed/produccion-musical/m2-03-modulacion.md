## El LFO de Analog

Un **LFO** (oscilador de baja frecuencia) es una onda lenta que no
escuchamos directamente: sirve para **mover otros parámetros** en el tiempo.
Analog trae dos. Los activás con los interruptores LFO 1 / LFO 2, y con
**Rate** ajustás su velocidad; el interruptor de al lado cambia entre
**Hz** (velocidad libre) y **divisiones sincronizadas al tempo**.

Con el selector **Wave** elegís la forma del LFO: sine, triangle, rectangle y
dos tipos de ruido —uno que salta a pasos entre valores aleatorios y otro que
se mueve por rampas suaves—. Si elegís **Tri** o **Rect**, el deslizador
**Width** deforma la onda:

- En **Tri**: valores bajos la llevan a una sierra ascendente, valores altos
  a una descendente, y en 50% es un triángulo perfecto.
- En **Rect**: 50% es una cuadrada perfecta; hacia los costados obtenés
  pulsos más finos, positivos o negativos.

(Width queda desactivado en modo sine o noise.)

::demo[lfo-forma]

Otros controles útiles: **Retrig** reinicia la fase del LFO en cada nota
(clave para que la modulación arranque siempre igual); **Offset** ajusta esa
fase de arranque; **Delay** demora el inicio del LFO tras la nota; y
**Attack** define cuánto tarda en llegar a su amplitud plena. La frecuencia de
corte y la resonancia del filtro se pueden modular por el LFO, por la altura
de la nota y por la envolvente del filtro, con los deslizadores de **Freq Mod**
y **Res Mod** (positivo suma, negativo resta).

## Modulación de amplitud (AM)

Si en vez de mover el filtro le asignás un LFO al **volumen**, estás haciendo
**modulación de amplitud**: la amplitud de la señal sube y baja siguiendo al
modulador. Es exactamente el principio del sidechain (ahí el modulador es el
kick en lugar de un LFO).

::demo[lfo-amplitud]

> Dato de color: a mediados de la década de 1870, una forma temprana de AM
> —las "corrientes ondulatorias"— fue el primer método que logró enviar audio
> por líneas telefónicas con calidad aceptable. La misma idea que ves en la
> demo.

## Vibrato

El **vibrato** de Analog es, en el fondo, un LFO extra pero **ligado al tono**
de ambos osciladores. Lo activás con **Vib** y ajustás su intensidad con el
porcentaje al lado; **Rate** define la velocidad. Al activarlo se habilitan:

- **Delay** y **Attack**: cuándo arranca y cuánto tarda en llegar a full.
- **Error**: agrega una desviación aleatoria a Rate, Amount, Delay y Attack
  por cada voz, para que suene más orgánico y menos "de máquina".
- **Amt<MW**: cuánto la rueda de modulación afecta la intensidad del vibrato.
