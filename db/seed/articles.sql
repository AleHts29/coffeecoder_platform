-- CoffeeCoder · seed de artículos y demos del curso "Go desde cero".
-- GENERADO por scripts/gen-seed-articles.py. No editar a mano: editá
-- seed/articulo-ejemplo.md y seed/demos/*.html y regeneralo.
-- Idempotente: UUIDs fijos + ON CONFLICT. Se aplica después de dev.sql.

BEGIN;

-- Biblioteca de demos del curso.
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-050000000001', '00000000-0000-4000-8000-020000000001', 'channels-buffer', 'Channels con y sin buffer', $d1$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Channels con y sin buffer en Go</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .bar { display: flex; gap: 8px; }
  button { flex: 1; font: 500 13px 'Space Grotesk', system-ui, sans-serif; border-radius: 8px;
           padding: 9px 10px; cursor: pointer; background: #242426; color: #EDEDEB;
           border: 0.5px solid #3A3A3C; }
  button:hover { background: #2E2E30; border-color: #48484A; }
  button:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  button.mono { font-family: 'JetBrains Mono', ui-monospace, monospace; font-weight: 400; }
  button[aria-pressed="true"] { background: #E08E33; color: #1B1B1D; border-color: #E08E33; }
  button.ghost { flex: 0 0 auto; background: transparent; border-color: transparent; color: #9A9A97; }
  button.ghost:hover { background: #242426; color: #EDEDEB; }
  svg { display: block; width: 100%; height: auto; margin: 12px 0; }
  #msg { margin: 0 0 12px; min-height: 40px; font-size: 13px; line-height: 1.5; color: #9A9A97; }
</style>
</head>
<body>
  <div class="bar" role="group" aria-label="Capacidad del channel">
    <button id="cap0" aria-pressed="true">Sin buffer</button>
    <button id="cap2" aria-pressed="false">Buffer de 2</button>
  </div>

  <svg viewBox="0 0 380 150" role="img" aria-labelledby="t d">
    <title id="t">Goroutine emisora, channel y goroutine receptora</title>
    <desc id="d">El emisor manda valores al channel y el receptor los toma. Si no hay lugar, el emisor queda bloqueado.</desc>
    <defs>
      <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M2 1L8 5L2 9" fill="none" stroke="#5A5A5C" stroke-width="1.5" stroke-linecap="round"/>
      </marker>
    </defs>
    <rect id="sendBox" x="10" y="40" width="88" height="56" rx="8" fill="#242426" stroke="#3A3A3C" stroke-width="0.5"/>
    <text x="54" y="63" text-anchor="middle" font-size="14" font-weight="500" fill="#EDEDEB">emisor</text>
    <text x="54" y="81" text-anchor="middle" font-size="12" fill="#8C8C8A">goroutine</text>
    <text id="sendState" x="54" y="118" text-anchor="middle" font-size="12" font-family="JetBrains Mono, monospace" fill="#8C8C8A">corriendo</text>

    <line x1="102" y1="68" x2="126" y2="68" stroke="#5A5A5C" stroke-width="1.2" marker-end="url(#arrow)"/>
    <rect x="132" y="30" width="116" height="76" rx="10" fill="none" stroke="#3A3A3C" stroke-width="0.5" stroke-dasharray="4 3"/>
    <text x="190" y="22" text-anchor="middle" font-size="12" font-family="JetBrains Mono, monospace" fill="#8C8C8A">chan int</text>
    <g id="slots"></g>
    <line x1="252" y1="68" x2="276" y2="68" stroke="#5A5A5C" stroke-width="1.2" marker-end="url(#arrow)"/>

    <rect id="recvBox" x="282" y="40" width="88" height="56" rx="8" fill="#242426" stroke="#3A3A3C" stroke-width="0.5"/>
    <text x="326" y="63" text-anchor="middle" font-size="14" font-weight="500" fill="#EDEDEB">receptor</text>
    <text x="326" y="81" text-anchor="middle" font-size="12" fill="#8C8C8A">goroutine</text>
    <text id="recvState" x="326" y="118" text-anchor="middle" font-size="12" font-family="JetBrains Mono, monospace" fill="#8C8C8A">corriendo</text>
  </svg>

  <p id="msg" aria-live="polite">Mandá un valor para empezar.</p>

  <div class="bar">
    <button id="send" class="mono">ch &lt;- v</button>
    <button id="recv" class="mono">v := &lt;-ch</button>
    <button id="reset" class="ghost">Reiniciar</button>
  </div>

<script>
(function () {
  var NS = 'http://www.w3.org/2000/svg';
  var ACCENT = '#E08E33', MUTED = '#8C8C8A', BORDER = '#3A3A3C';
  var cap = 0, buf = [], sendBlocked = false, recvBlocked = false, n = 0;

  var slots = document.getElementById('slots');
  var msg = document.getElementById('msg');
  var sendState = document.getElementById('sendState');
  var recvState = document.getElementById('recvState');
  var sendBox = document.getElementById('sendBox');
  var recvBox = document.getElementById('recvBox');
  var cap0 = document.getElementById('cap0');
  var cap2 = document.getElementById('cap2');

  function el(tag, attrs, text) {
    var e = document.createElementNS(NS, tag);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function drawSlots() {
    slots.textContent = '';
    if (cap === 0) {
      slots.appendChild(el('rect', { x: 156, y: 52, width: 68, height: 32, rx: 6, fill: 'none',
        stroke: sendBlocked ? ACCENT : BORDER, 'stroke-width': sendBlocked ? 1 : 0.5 }));
      slots.appendChild(el('text', { x: 190, y: 72, 'text-anchor': 'middle', 'font-size': 12,
        'font-family': 'JetBrains Mono, monospace', fill: sendBlocked ? ACCENT : MUTED },
        sendBlocked ? String(n) + ' en mano' : 'sin lugar'));
      return;
    }
    for (var i = 0; i < cap; i++) {
      var x = 146 + i * 48;
      slots.appendChild(el('rect', { x: x, y: 52, width: 40, height: 32, rx: 6, fill: 'none',
        stroke: BORDER, 'stroke-width': 0.5 }));
      if (buf[i] !== undefined) {
        slots.appendChild(el('circle', { cx: x + 20, cy: 68, r: 11, fill: ACCENT }));
        slots.appendChild(el('text', { x: x + 20, y: 72, 'text-anchor': 'middle', 'font-size': 12,
          'font-family': 'JetBrains Mono, monospace', fill: '#1B1B1D' }, String(buf[i])));
      }
    }
  }

  function state(textEl, box, blocked) {
    textEl.textContent = blocked ? 'bloqueado' : 'corriendo';
    textEl.setAttribute('fill', blocked ? ACCENT : MUTED);
    box.setAttribute('stroke', blocked ? ACCENT : BORDER);
    box.setAttribute('stroke-width', blocked ? 1 : 0.5);
  }

  function render(text) {
    state(sendState, sendBox, sendBlocked);
    state(recvState, recvBox, recvBlocked);
    if (text) msg.textContent = text;
    drawSlots();
  }

  function send() {
    if (sendBlocked) { render('El emisor ya está bloqueado: la línea no avanza hasta que alguien reciba.'); return; }
    n++;
    if (recvBlocked) { recvBlocked = false; render('Handoff directo: el receptor estaba esperando y tomó ' + n + '.'); return; }
    if (cap > 0 && buf.length < cap) {
      buf.push(n);
      render('El ' + n + ' entró al buffer. El emisor sigue corriendo sin esperar.');
    } else {
      sendBlocked = true;
      render(cap === 0
        ? 'Sin buffer, enviar bloquea hasta que otra goroutine reciba.'
        : 'Buffer lleno: el emisor queda bloqueado hasta que se libere un lugar.');
    }
  }

  function recv() {
    if (recvBlocked) { render('El receptor ya está bloqueado esperando un valor.'); return; }
    if (buf.length > 0) {
      var v = buf.shift(), extra = '';
      if (sendBlocked) { sendBlocked = false; buf.push(n); extra = ' Se liberó un lugar y el emisor dejó su ' + n + ' en el buffer.'; }
      render('Recibió ' + v + '.' + extra);
      return;
    }
    if (sendBlocked) { sendBlocked = false; render('Handoff: recibió ' + n + ' y el emisor se destrabó.'); return; }
    recvBlocked = true;
    render('Channel vacío: el receptor se bloquea hasta que llegue un valor.');
  }

  function setCap(c) {
    cap = c; buf = []; sendBlocked = false; recvBlocked = false; n = 0;
    cap0.setAttribute('aria-pressed', String(c === 0));
    cap2.setAttribute('aria-pressed', String(c === 2));
    render(c === 0
      ? 'Sin buffer: cada envío espera a que alguien reciba.'
      : 'Buffer de 2: entran dos valores sin esperar a nadie.');
  }

  cap0.addEventListener('click', function () { setCap(0); });
  cap2.addEventListener('click', function () { setCap(2); });
  document.getElementById('send').addEventListener('click', send);
  document.getElementById('recv').addEventListener('click', recv);
  document.getElementById('reset').addEventListener('click', function () { setCap(cap); });
  render();
})();
</script>
</body>
</html>
$d1$, 420)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-050000000002', '00000000-0000-4000-8000-020000000001', 'lfo-amplitud', 'LFO: modulación de amplitud', $d2$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Modulación de amplitud con un LFO</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .row { display: grid; grid-template-columns: 64px 1fr 60px; gap: 10px;
         align-items: center; margin-bottom: 8px; }
  .row label { font-size: 13px; color: #9A9A97; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
           text-align: right; }
  input[type=range] { accent-color: #E08E33; width: 100%; margin: 0; }
  input[type=range]:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin: 0 0 10px; }
  .audio .btn { font-family: inherit; font-size: 13px; line-height: 1; padding: 8px 10px;
                border-radius: 6px; cursor: pointer; background: #242426;
                border: 1px solid #3A3A3C; color: #EDEDEB; }
  .audio .btn[aria-pressed="true"] { background: #E08E33; border-color: #E08E33; color: #141414; }
  .audio .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
  .audio input[type=range] { width: 110px; flex: 0 1 110px; }
  .audio .value { width: 38px; text-align: right; color: #8C8C8A; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 12px 0 4px; }
  canvas { display: block; width: 100%; }
</style>
</head>
<body>
  <div class="row">
    <label for="rate">Rate</label>
    <input id="rate" type="range" min="0.1" max="2" step="0.1" value="0.5">
    <span class="value" id="rateOut">0.5 Hz</span>
  </div>
  <div class="row">
    <label for="amount">Amount</label>
    <input id="amount" type="range" min="0" max="100" step="1" value="100">
    <span class="value" id="amountOut">100%</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <p class="caption">LFO · el modulador, lento</p>
  <canvas id="lfo" style="height:56px" role="img" aria-label="Onda lenta del LFO"></canvas>
  <p class="caption">Portadora · el sonido, rápido y parejo</p>
  <canvas id="carrier" style="height:56px" role="img" aria-label="Onda portadora de amplitud constante"></canvas>
  <p class="caption">Resultado · la amplitud sigue al LFO</p>
  <canvas id="result" style="height:84px" role="img" aria-label="Portadora con la amplitud modulada por el LFO"></canvas>

<script>
(function () {
  var rate = document.getElementById('rate');
  var amount = document.getElementById('amount');
  var rateOut = document.getElementById('rateOut');
  var amountOut = document.getElementById('amountOut');
  var canvases = ['lfo', 'carrier', 'result'].map(function (id) { return document.getElementById(id); });
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ACCENT = '#E08E33', MUTED = '#8C8C8A', AXIS = '#2C2C2E', ENVELOPE = '#5A5A5C';
  var CARRIER_CYCLES = 30;
  var phase = 0, last = performance.now();

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, r.height / 2); ctx.lineTo(r.width, r.height / 2); ctx.stroke();
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function plot(g, fn, color, width) {
    var mid = g.h / 2, amp = g.h / 2 - 4;
    g.ctx.strokeStyle = color; g.ctx.lineWidth = width;
    g.ctx.beginPath();
    for (var x = 0; x <= g.w; x++) {
      var y = mid - fn(x / g.w) * amp;
      if (x === 0) g.ctx.moveTo(x, y); else g.ctx.lineTo(x, y);
    }
    g.ctx.stroke();
  }

  function draw() {
    var r = parseFloat(rate.value);
    var m = parseInt(amount.value, 10) / 100;
    rateOut.textContent = r.toFixed(1) + ' Hz';
    amountOut.textContent = Math.round(m * 100) + '%';

    var lfoCycles = 0.6 + r * 1.2;
    function lfo(u) { return Math.sin(2 * Math.PI * lfoCycles * u + phase); }
    function gain(u) { return 1 - m * (1 - (lfo(u) + 1) / 2); }
    function carrier(u) { return Math.sin(2 * Math.PI * CARRIER_CYCLES * u); }

    var g1 = setup(canvases[0]), g2 = setup(canvases[1]), g3 = setup(canvases[2]);
    plot(g1, lfo, ACCENT, 1.6);
    plot(g2, carrier, MUTED, 1.2);
    plot(g3, gain, ENVELOPE, 1);
    plot(g3, function (u) { return -gain(u); }, ENVELOPE, 1);
    plot(g3, function (u) { return gain(u) * carrier(u); }, ACCENT, 1.4);
  }

  function loop(now) {
    var dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    phase += parseFloat(rate.value) * dt * 2 * Math.PI;
    draw();
    requestAnimationFrame(loop);
  }

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

  // --- portadora A3 = 220 Hz con el gain modulado por el LFO ---
  // Misma fórmula que el dibujo: gain(t) = 1 - m * (1 - (sin + 1) / 2),
  // o sea offset (1 - m/2) + seno de amplitud m/2, leyendo Rate y Amount.
  var FREQ = 220;
  var sndBtn = document.getElementById('snd');
  var volIn = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var voice = null, switching = false;

  function syncAudio() {
    if (!voice) return;
    var t = audio.ctx().currentTime;
    var r = parseFloat(rate.value), m = parseInt(amount.value, 10) / 100;
    voice.lfo.frequency.setTargetAtTime(r, t, 0.01);
    voice.depth.gain.setTargetAtTime(m / 2, t, 0.01);
    voice.mod.gain.setTargetAtTime(1 - m / 2, t, 0.01);
  }

  function startTone() {
    if (!audio.on() || voice) return;
    var ctx = audio.ctx();
    var osc = ctx.createOscillator();
    osc.type = 'sine'; osc.frequency.value = FREQ;
    var mod = ctx.createGain();     // gain de la portadora: lo mueve el LFO
    var lfo = ctx.createOscillator();
    lfo.type = 'sine';
    var depth = ctx.createGain();   // Amount: cuánto de ese seno entra al gain
    var out = ctx.createGain();     // fade de encendido y apagado
    out.gain.value = 0;
    mod.gain.value = 1;
    depth.gain.value = 0;
    lfo.frequency.value = parseFloat(rate.value);
    lfo.connect(depth); depth.connect(mod.gain);
    osc.connect(mod); mod.connect(out); out.connect(audio.master());
    voice = { osc: osc, lfo: lfo, depth: depth, mod: mod, out: out };
    syncAudio();
    osc.start(); lfo.start();
    audio.ramp(out.gain, 0.9, 0.012);
  }

  function stopTone() {
    if (!voice) return;
    var v = voice; voice = null;
    var ctx = audio.ctx();
    audio.ramp(v.out.gain, 0, 0.012);
    try { v.osc.stop(ctx.currentTime + 0.06); } catch (e) {}
    try { v.lfo.stop(ctx.currentTime + 0.06); } catch (e) {}
    setTimeout(function () {
      try { v.osc.disconnect(); } catch (e) {}
      try { v.lfo.disconnect(); } catch (e) {}
      try { v.depth.disconnect(); } catch (e) {}
      try { v.mod.disconnect(); } catch (e) {}
      try { v.out.disconnect(); } catch (e) {}
    }, 150);
  }

  function reflectSound(on) { sndBtn.setAttribute('aria-pressed', on ? 'true' : 'false'); }

  sndBtn.addEventListener('click', function () {
    if (switching) return;
    if (audio.on()) {
      reflectSound(false);
      stopTone();
      switching = true;
      setTimeout(function () { if (audio.on()) audio.toggle(); switching = false; }, 90);
    } else {
      audio.toggle();
      audio.setVolume(parseInt(volIn.value, 10) / 100);
      reflectSound(true);
      startTone();
    }
  });

  volIn.addEventListener('input', function () {
    var pct = parseInt(volIn.value, 10);
    volOut.textContent = pct + '%';
    audio.setVolume(pct / 100);
  });

  document.addEventListener('visibilitychange', function () {
    if (document.hidden && audio.on()) { stopTone(); audio.toggle(); reflectSound(false); }
  });

  rate.addEventListener('input', draw);
  amount.addEventListener('input', draw);
  rate.addEventListener('input', syncAudio);
  amount.addEventListener('input', syncAudio);
  window.addEventListener('resize', draw);

  if (reduce) draw(); else requestAnimationFrame(loop);
})();
</script>
</body>
</html>
$d2$, 520)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;

-- Lección de lectura en el módulo "Errores y concurrencia", como muestra
-- gratis. duration_s = tiempo de lectura con la fórmula de internal/content.
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-040000010305', '00000000-0000-4000-8000-030000000103', 'Channels con y sin buffer',
        'Qué cambia cuando un channel tiene capacidad, con una demo para probarlo.',
        134, true, 5, 'article', $art$Una goroutine que necesita pasarle un dato a otra tiene dos caminos:
compartir una variable y protegerla con un mutex, o mandarle el dato por
un **channel**. Go empuja hacia el segundo, y lo resume en una frase:
no te comuniques compartiendo memoria; compartí memoria comunicándote.

## Enviar y recibir

Un channel se crea con `make` y se usa con el operador `<-`:

```go
ch := make(chan int)

go func() {
    ch <- 42 // enviar
}()

v := <-ch // recibir
fmt.Println(v)
```

Lo importante no es la sintaxis sino lo que pasa en el tiempo: en un
channel sin buffer, **enviar bloquea** hasta que otra goroutine reciba.
Es un pasamanos: el emisor no suelta el valor hasta que alguien lo agarra.

## El buffer como amortiguador

Si al crear el channel le das una capacidad, el emisor puede dejar
valores sin esperar, hasta llenar el buffer:

```go
ch := make(chan int, 2) // entran 2 valores sin bloquear
```

Probalo: con "Sin buffer", mandá dos valores seguidos. Después pasá a
"Buffer de 2" y repetí.

::demo[channels-buffer]

Fijate en tres cosas:

- Sin buffer, el primer envío ya bloquea al emisor.
- Con buffer de 2, los dos primeros envíos siguen de largo y recién el
  tercero bloquea.
- Recibir de un channel vacío bloquea al receptor, tenga buffer o no.

Un buffer no hace a tu programa más rápido por sí solo: desacopla el
ritmo del emisor y del receptor. Si el receptor es más lento siempre,
el buffer se llena y volvés a estar bloqueado, solo que un poco más tarde.
$art$)
ON CONFLICT (id) DO UPDATE SET body_md = EXCLUDED.body_md, duration_s = EXCLUDED.duration_s;

COMMIT;
