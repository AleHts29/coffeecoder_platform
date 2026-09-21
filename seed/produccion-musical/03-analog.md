## El instrumento Analog

Analog es el sintetizador **analógico virtual** de Ableton, hecho junto a
Applied Acoustics Systems. No usa samples ni tablas de onda: **modela la
física** de los circuitos de un sinte analógico y resuelve esas ecuaciones
en tiempo real en la CPU, parámetro por parámetro. De ahí la calidez y el
dinamismo que tiene: cada nota se calcula, no se reproduce.

Para diseñar un sonido con Analog necesitás entender dos cosas que ya
tenemos a mano: la **forma de onda** del oscilador (lección anterior) y su
**envolvente**.

## La envolvente de volumen (ADSR)

Un sonido no aparece y desaparece de golpe: tiene un recorrido en el
tiempo. La envolvente ADSR describe ese recorrido en cuatro etapas:

- **Attack** — cuánto tarda en llegar del silencio al volumen máximo apenas
  apretás la tecla.
- **Decay** — cuánto tarda en bajar del pico al nivel de sostén.
- **Sustain** — el nivel al que se queda mientras mantenés la tecla apretada
  (ojo: es un **nivel**, no un tiempo).
- **Release** — cuánto tarda en apagarse hasta el silencio cuando soltás.

::demo[envolvente-adsr]

Tocá la nota en la demo y mirá cómo la misma onda se convierte en cosas
distintas según la envolvente. Attack corto + sustain bajo + release corto
= un pluck percusivo. Attack largo + sustain alto = un pad que respira.

## Modular la afinación: Pitch Env y Pitch Mod

La envolvente de volumen tiene una hermana que afecta la **afinación** en
vez del volumen. Con **Initial** ajustás el tono de arranque del oscilador y
con **Time** cuánto tarda en deslizarse hasta su valor final; podés moverlo
con los sliders o arrastrando los breakpoints en el display. Sirve, por
ejemplo, para ese "pow" de afinación al inicio de un kick o un tom.

El parámetro **LFO** define cuánto un LFO modula el tono (recordá activar el
LFO o no hace nada). Y **Key** controla cuánto afecta al oscilador la altura
de las notas MIDI que tocás: al **100%** el oscilador sigue la escala
temperada normal; al **0%** no responde a la nota (siempre suena igual).
Valores intermedios estiran o comprimen el espaciado entre notas —un truco:
dejá un oscilador en 100% y el otro apenas distinto, y vas a escuchar cómo se
desafinan entre sí a medida que te alejás de C3.

## El sub-oscilador

El parámetro **Sub** agrega un oscilador extra afinado **una octava por
debajo** del principal, para dar cuerpo y peso —clave en bajos—. Con el modo
en **Sub**, el slider **Level** define cuánto suena. El sub genera una onda
cuadrada cuando el oscilador principal está en rectangle o sawtooth, y una
senoidal cuando está en sine. Queda deshabilitado si el oscilador principal
está en ruido blanco.

Con esto —forma de onda, ADSR, un poco de pitch y el sub— ya tenés todo para
empezar a diseñar tus propios sonidos.
