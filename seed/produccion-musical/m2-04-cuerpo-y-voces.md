## Global y volumen

En la sección **Global** ajustás cómo responde Analog al MIDI y los controles
de interpretación (vibrato, glide). **Volume** es el nivel maestro del
instrumento: amplifica o atenúa la salida de las secciones de amplificador.

## Unísono: engordar cada nota

El botón **Uni** activa el **Unison**, que apila varias voces por cada nota
que tocás. El deslizador **Detune** controla cuánto se desafinan esas voces
entre sí. El resultado: cada nota suena con más cuerpo, más "gorda". Es el
secreto detrás de los supersaws y de casi cualquier lead ancho.

::demo[unisono-detune]

Subí las voces y después el detune: con una sola voz el sonido es fino; al
apilar y desafinar aparece ese batido que llena el estéreo.

## Ruteo rápido

Los cuatro botones de **Quick Routing** a la izquierda del display cambian
cómo se conectan osciladores, filtros y amplificadores (no tocan los niveles,
afinación ni forma de onda que ya ajustaste):

1. **Paralelo total** — cada oscilador alimenta exclusivamente su propio
   filtro y amplificador.
2. **Split** — similar, pero cada oscilador reparte su salida por igual entre
   los dos filtros.
3. **Colapsado en Filter 1** — ambos osciladores van a Filter 1 y Amp 1;
   Filter 2 y Amp 2 quedan deshabilitados.
4. **Serie** — los dos osciladores entran a Filter 1 y de ahí, en cadena,
   exclusivamente a Filter 2 y Amp 2.

## Loop de envolvente

El selector **Loop** repite ciertos segmentos de la envolvente de volumen
mientras mantenés la tecla:

- **Off** — la envolvente recorre sus fases una vez, sin loop.
- **AD-R** — attack y decay se repiten en bucle hasta que soltás; ahí entra
  el release.
- **ADR-R** — igual, pero incluye también el release dentro del loop mientras
  sostenés.
- **ADS-AR** — no loopea: reproduce la envolvente normal y vuelve a disparar
  attack y release una vez al final de la nota (con tiempos cortos, simula
  instrumentos con apagadores audibles).

Si activás **Free** en los modos AD-R o ADR-R, las notas se comportan como si
estuvieran siempre pulsadas.

::demo[envolvente-loop]

**Envolventes polimétricas:** si usás modos y tiempos de loop distintos en
cada envolvente, cada una corre con su propia métrica. Eso le da textura y
movimiento al sonido, porque los ciclos no coinciden nunca del todo.
