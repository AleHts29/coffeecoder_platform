## De una voz a varias

En el módulo anterior trabajamos en **monofonía**: una nota por vez. La
**polifonía** es lo contrario: varias voces sonando a la vez, independientes
entre sí. En términos musicales es la textura de varias melodías o notas
simultáneas —lo que te permite tocar un acorde o dejar una nota colgada
mientras entra otra—. En términos del sinte, cada nota que suena ocupa una
**voz**, y el instrumento tiene un número finito de ellas.

::demo[mono-vs-poli]

Probá los dos modos. En mono, cada nota nueva **corta** la anterior: por eso
un bajo mono es tan directo, pero no te deja tocar acordes. En poli, cada
nota abre su propia voz; y cuando se te acaban las voces disponibles, el
sinte apaga la más vieja para dar lugar a la nueva —eso se llama **note
stealing**—. Más voces = más CPU, así que se elige según lo que el sonido
necesite.

## Sumar osciladores para sonidos más gordos

Analog tiene dos osciladores. Podés usar solo uno, o **sumarlos** para
construir timbres más ricos. Para sumar el segundo, lo activás junto con su
módulo **Amp** correspondiente; por defecto se combinan de forma **aditiva**.

Un ejemplo clásico de bajo: una **onda cuadrada en el OSC 1** para el cuerpo,
complementada con una **sinusoidal en el OSC 2** para reforzar el
fundamental. Los dos pasan por el **Filtro 1** con un pasa-bajos alrededor de
**220 Hz**, y te queda un bajo gordo y con peso, sin frecuencias de más.

## Oscillator Sync

El modo **Sync** (en el selector Sub/Sync) reinicia la forma de onda del
oscilador audible con la fase de un oscilador interno, cuya velocidad
controlás con **Ratio**. Al **0%** ambos coinciden y no pasa nada. A medida
que subís el Ratio, el oscilador interno va más rápido y **reinicia** al
audible una y otra vez, lo que le agrega armónicos y le cambia el timbre sin
cambiar la altura de la nota.

::demo[oscillator-sync]

Barré el Ratio en la demo: ese sonido metálico y "rasgado" que aparece es el
clásico *sync sweep*, muy usado en leads.
