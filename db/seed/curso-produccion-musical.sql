-- CoffeeCoder · seed del curso "Producción Musical con Ableton" (desarrollo).
-- GENERADO por scripts/gen-seed-produccion-musical.py. No editar a mano:
-- editá seed/produccion-musical/*.md y seed/demos/*.html y regeneralo.
-- Idempotente: UUIDs fijos + ON CONFLICT. Se aplica después de dev.sql.
-- Serie de UUIDs propia, fuera del rango del seed de dev:
--   curso   00000000-0000-4000-8000-AB0000000001
--   módulos 00000000-0000-4000-8000-AB010000NNNN
--   lección 00000000-0000-4000-8000-AB02MM0000NN
--   demos   00000000-0000-4000-8000-AB0300000NNN

BEGIN;

-- Curso (draft: no se ve en el catálogo hasta publicarlo).
INSERT INTO courses (id, slug, title, subtitle, description, level, price_cents, status, position, category_id)
VALUES ('00000000-0000-4000-8000-AB0000000001', 'produccion-musical-ableton', 'Producción Musical con Ableton',
        'De la síntesis a la mezcla: cómo suena cada decisión, con demos que podés tocar.',
        'Un recorrido por Ableton Live pensado para entender, no para memorizar botones: qué hace cada instrumento y efecto, por qué, y cómo se escucha. Cada tema trae teoría corta y una demo interactiva para experimentar antes de abrir el DAW.', 'medio', 5900, 'draft', 10, '00000000-0000-4000-8000-060000000002')
ON CONFLICT (id) DO UPDATE SET subtitle = EXCLUDED.subtitle, description = EXCLUDED.description,
  category_id = EXCLUDED.category_id;

-- Biblioteca de demos del curso.
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000001', '00000000-0000-4000-8000-AB0000000001', 'formas-de-onda', 'Formas de onda y armónicos', $d1$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Formas de onda y su espectro</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .seg { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }
  .seg button { font-family: inherit; font-size: 13px; line-height: 1;
                padding: 8px 10px; border-radius: 6px; cursor: pointer;
                background: #242426; border: 1px solid #3A3A3C; color: #EDEDEB; }
  .seg button[aria-pressed="true"] { background: #E08E33; border-color: #E08E33; color: #141414; }
  .seg button:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .row { display: grid; grid-template-columns: 74px 1fr 40px; gap: 10px;
         align-items: center; margin-bottom: 10px; }
  .row label { font-size: 13px; color: #9A9A97; }
  .row.off label, .row.off .value { color: #48484A; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
           text-align: right; }
  input[type=range] { accent-color: #E08E33; width: 100%; margin: 0; }
  input[type=range]:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  input[type=range]:disabled { accent-color: #48484A; }
  .audio { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin: 0 0 10px; }
  .audio .btn { font-family: inherit; font-size: 13px; line-height: 1; padding: 8px 10px;
                border-radius: 6px; cursor: pointer; background: #242426;
                border: 1px solid #3A3A3C; color: #EDEDEB; }
  .audio .btn[aria-pressed="true"] { background: #E08E33; border-color: #E08E33; color: #141414; }
  .audio .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
  .audio input[type=range] { width: 110px; flex: 0 1 110px; }
  .audio .value { width: 38px; text-align: right; color: #8C8C8A; }
  .panels { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 0 0 4px; }
  canvas { display: block; width: 100%; height: 200px; }
  .note { font-size: 12px; color: #8C8C8A; margin: 10px 0 0; }
  @media (max-width: 560px) { canvas { height: 120px; } }
</style>
</head>
<body>
  <div class="seg" role="group" aria-label="Forma de onda">
    <button type="button" data-shape="sine" aria-pressed="false">sine</button>
    <button type="button" data-shape="triangle" aria-pressed="false">triangle</button>
    <button type="button" data-shape="saw" aria-pressed="true">saw</button>
    <button type="button" data-shape="square" aria-pressed="false">square</button>
    <button type="button" data-shape="noise" aria-pressed="false">noise</button>
  </div>

  <div class="row" id="harmRow">
    <label for="harm">Armónicos</label>
    <input id="harm" type="range" min="1" max="16" step="1" value="8">
    <span class="value" id="harmOut">8</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <div class="panels">
    <div>
      <p class="caption">Tiempo · 2 ciclos</p>
      <canvas id="wave" role="img" aria-label="Onda en el tiempo"></canvas>
    </div>
    <div>
      <p class="caption">Espectro · armónicos</p>
      <canvas id="spec" role="img" aria-label="Espectro de armónicos"></canvas>
    </div>
  </div>

  <p class="note">Mirá cómo al sumar armónicos los flancos se afilan sin que cambie la altura: lo que cambia es el espectro.</p>

<script>
(function () {
  var ACCENT = '#E08E33', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var CYCLES = 2, MAXH = 16, NOISE_BARS = 32;

  var shape = 'saw', harm = 8;
  var btns = Array.prototype.slice.call(document.querySelectorAll('.seg button'));
  var harmIn = document.getElementById('harm');
  var harmOut = document.getElementById('harmOut');
  var harmRow = document.getElementById('harmRow');
  var waveC = document.getElementById('wave');
  var specC = document.getElementById('spec');

  var NAME = { sine: 'senoidal', triangle: 'triangular', saw: 'diente de sierra',
               square: 'cuadrada', noise: 'ruido' };

  function prng(seed) {
    var a = seed >>> 0;
    return function () {
      a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  var r1 = prng(20260921), NOISE = [];
  for (var i = 0; i < 1024; i++) NOISE.push(r1() * 2 - 1);
  var r2 = prng(1337), NBARS = [];
  for (var j = 0; j < NOISE_BARS; j++) NBARS.push(0.60 + r2() * 0.30);
  NBARS[0] = 0;

  function coef(n) {
    if (shape === 'sine') return n === 1 ? 1 : 0;
    if (shape === 'saw') return (n % 2 ? 1 : -1) / n;
    if (shape === 'square') return n % 2 ? 1 / n : 0;
    if (shape === 'triangle') return n % 2 ? ((((n - 1) / 2) % 2 ? -1 : 1) / (n * n)) : 0;
    return 0;
  }

  function sample(u) {
    if (shape === 'noise') return NOISE[Math.floor(u * NOISE.length) % NOISE.length];
    var x = 2 * Math.PI * CYCLES * u, s = 0;
    for (var n = 1; n <= harm; n++) {
      var c = coef(n);
      if (c) s += c * Math.sin(n * x);
    }
    return s;
  }

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function drawWave() {
    var g = setup(waveC), ctx = g.ctx, mid = g.h / 2, amp = g.h / 2 - 6;
    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, mid + 0.5); ctx.lineTo(g.w, mid + 0.5); ctx.stroke();
    for (var k = 1; k < CYCLES; k++) {
      var gx = Math.round(g.w * k / CYCLES) + 0.5;
      ctx.beginPath(); ctx.moveTo(gx, 2); ctx.lineTo(gx, g.h - 2); ctx.stroke();
    }

    var steps = Math.max(2, Math.round(g.w)), ys = [], peak = 0;
    for (var s = 0; s <= steps; s++) {
      var v = sample(s / steps);
      ys.push(v);
      if (Math.abs(v) > peak) peak = Math.abs(v);
    }
    if (peak === 0) peak = 1;

    ctx.strokeStyle = ACCENT; ctx.lineWidth = 1.6;
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.beginPath();
    for (var p = 0; p <= steps; p++) {
      var x = p / steps * g.w, y = mid - ys[p] / peak * amp;
      if (p === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  function drawSpec() {
    var g = setup(specC), ctx = g.ctx;
    var pad = 4, base = g.h - 6, top = 6, span = base - top;
    var count = shape === 'noise' ? NOISE_BARS : MAXH;
    var vals = [], peak = 0, n;
    for (n = 1; n <= count; n++) {
      var a = shape === 'noise' ? NBARS[n - 1] : Math.abs(coef(n));
      vals.push(a);
      if (a > peak) peak = a;
    }
    if (peak === 0) peak = 1;

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    for (var q = 1; q <= 3; q++) {
      var gy = Math.round(base - span * q / 4) + 0.5;
      ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(g.w, gy); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(0, base + 0.5); ctx.lineTo(g.w, base + 0.5); ctx.stroke();

    var slot = (g.w - pad * 2) / count;
    var bw = Math.max(1.5, slot * (shape === 'noise' ? 0.5 : 0.62));
    for (n = 1; n <= count; n++) {
      var v = vals[n - 1] / peak;
      var on = shape === 'noise' || n <= harm;
      var hgt = Math.max(v > 0 ? 1 : 0, v * span);
      if (!hgt) continue;
      ctx.fillStyle = on ? ACCENT : AXIS;
      ctx.fillRect(pad + slot * (n - 1) + (slot - bw) / 2, base - hgt, bw, hgt);
    }

    if (shape !== 'noise' && harm < MAXH) {
      var mx = Math.round(pad + slot * harm) + 0.5;
      ctx.strokeStyle = SECOND;
      ctx.beginPath(); ctx.moveTo(mx, top); ctx.lineTo(mx, base); ctx.stroke();
    }
  }

  function draw() {
    var noise = shape === 'noise';
    harmIn.disabled = noise;
    harmRow.className = noise ? 'row off' : 'row';
    harmOut.textContent = noise ? '—' : String(harm);

    waveC.setAttribute('aria-label',
      noise ? 'Ruido en el tiempo: recorrido irregular sin forma repetida'
            : 'Onda ' + NAME[shape] + ' en el tiempo, reconstruida con ' + harm +
              (harm === 1 ? ' armónico' : ' armónicos'));
    specC.setAttribute('aria-label',
      noise ? 'Espectro del ruido: muchas barras parejas y sin fundamental'
            : 'Espectro de la onda ' + NAME[shape] + ': ' + harm +
              (harm === 1 ? ' armónico activo' : ' armónicos activos') + ' de 16');

    drawWave();
    drawSpec();
    syncAudio();
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

  // --- tono: 220 Hz (A3) con la MISMA forma y los MISMOS N parciales que dibuja el canvas ---
  var FREQ = 220;
  var sndBtn = document.getElementById('snd');
  var volIn = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var voice = null, noiseBuf = null, switching = false;

  function noiseBuffer(ctx) {
    if (noiseBuf) return noiseBuf;
    var len = Math.floor(ctx.sampleRate * 2);
    noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    var data = noiseBuf.getChannelData(0), rn = prng(20260921);
    for (var i = 0; i < len; i++) data[i] = rn() * 2 - 1;
    return noiseBuf;
  }

  function applyWave(osc, ctx) {
    // sine: el tipo nativo ya es el único parcial que dibuja el canvas.
    if (shape === 'sine') { osc.type = 'sine'; return; }
    // El resto: PeriodicWave con los mismos coeficientes de coef(), hasta
    // el armónico del slider, para que se oiga exactamente la suma que se ve.
    var real = new Float32Array(MAXH + 1), imag = new Float32Array(MAXH + 1);
    for (var n = 1; n <= harm; n++) imag[n] = coef(n);
    osc.setPeriodicWave(ctx.createPeriodicWave(real, imag));
  }

  function startTone() {
    if (!audio.on() || voice) return;
    var ctx = audio.ctx();
    var g = ctx.createGain();
    g.gain.value = 0;
    g.connect(audio.master());
    var src, kind;
    if (shape === 'noise') {
      kind = 'noise';
      src = ctx.createBufferSource();
      src.buffer = noiseBuffer(ctx);
      src.loop = true;
    } else {
      kind = 'tone';
      src = ctx.createOscillator();
      src.frequency.value = FREQ;
      applyWave(src, ctx);
    }
    src.connect(g);
    src.start();
    voice = { kind: kind, src: src, gain: g };
    audio.ramp(g.gain, kind === 'noise' ? 0.45 : 0.9, 0.012);
  }

  function stopTone() {
    if (!voice) return;
    var v = voice; voice = null;
    var ctx = audio.ctx();
    audio.ramp(v.gain.gain, 0, 0.012);
    try { v.src.stop(ctx.currentTime + 0.06); } catch (e) {}
    setTimeout(function () {
      try { v.src.disconnect(); } catch (e) {}
      try { v.gain.disconnect(); } catch (e) {}
    }, 150);
  }

  function syncAudio() {
    if (!audio.on()) return;
    if (!voice) { startTone(); return; }
    var want = shape === 'noise' ? 'noise' : 'tone';
    if (voice.kind !== want) { stopTone(); startTone(); return; }
    if (want === 'tone') {
      applyWave(voice.src, audio.ctx());
      voice.src.frequency.value = FREQ;
    }
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

  btns.forEach(function (b) {
    b.addEventListener('click', function () {
      shape = b.getAttribute('data-shape');
      btns.forEach(function (o) {
        o.setAttribute('aria-pressed', o === b ? 'true' : 'false');
      });
      draw();
    });
  });
  harmIn.addEventListener('input', function () {
    harm = parseInt(harmIn.value, 10);
    draw();
  });
  window.addEventListener('resize', draw);

  draw();
})();
</script>
</body>
</html>
$d1$, 460)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000002', '00000000-0000-4000-8000-AB0000000001', 'envolvente-adsr', 'Envolvente ADSR', $d2$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Envolvente ADSR</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .row { display: grid; grid-template-columns: 64px 1fr 62px; gap: 10px;
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
  .gate { display: block; width: 100%; margin: 2px 0 10px; padding: 7px 10px;
          font-family: inherit; font-size: 13px; font-weight: 500;
          background: #242426; border: 1px solid #3A3A3C; border-radius: 6px;
          color: #EDEDEB; cursor: pointer; touch-action: none;
          -webkit-user-select: none; user-select: none; }
  .gate.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .gate:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  canvas { display: block; width: 100%; }
  .status { margin: 8px 0 0; font-size: 12px; color: #9A9A97; }
  .status .value { text-align: left; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 6px 0 0; }
</style>
</head>
<body>
  <div class="row">
    <label for="attack">Attack</label>
    <input id="attack" type="range" min="0" max="2000" step="10" value="120">
    <span class="value" id="attackOut">120 ms</span>
  </div>
  <div class="row">
    <label for="decay">Decay</label>
    <input id="decay" type="range" min="0" max="2000" step="10" value="300">
    <span class="value" id="decayOut">300 ms</span>
  </div>
  <div class="row">
    <label for="sustain">Sustain</label>
    <input id="sustain" type="range" min="0" max="100" step="1" value="60">
    <span class="value" id="sustainOut">60%</span>
  </div>
  <div class="row">
    <label for="release">Release</label>
    <input id="release" type="range" min="0" max="3000" step="10" value="600">
    <span class="value" id="releaseOut">600 ms</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <button class="gate" id="gate" type="button" aria-pressed="false">Tocar nota — mantené apretado</button>

  <canvas id="env" style="height:140px" role="img"
          aria-label="Envolvente ADSR: el attack sube al máximo, el decay baja al nivel de sustain, la meseta dura lo que dura la tecla apretada y el release cae a silencio al soltar"></canvas>

  <p class="status">etapa <span class="value" id="stage">silencio</span></p>
  <p class="caption">Qué mirar: sustain bajo y decay corto dan un pluck; sustain alto y release largo, un pad.</p>

<script>
(function () {
  var attack = document.getElementById('attack');
  var decay = document.getElementById('decay');
  var sustain = document.getElementById('sustain');
  var release = document.getElementById('release');
  var attackOut = document.getElementById('attackOut');
  var decayOut = document.getElementById('decayOut');
  var sustainOut = document.getElementById('sustainOut');
  var releaseOut = document.getElementById('releaseOut');
  var btn = document.getElementById('gate');
  var stageOut = document.getElementById('stage');
  var cv = document.getElementById('env');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ACCENT = '#E08E33', MUTED = '#8C8C8A', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var BG = '#1B1B1D', SHADE = 'rgba(90, 90, 92, 0.16)';
  var NOMINAL = 700;
  var mode = 'idle', pressT = 0, gateLen = 0, raf = 0;

  function now() { return performance.now(); }

  function vals() {
    return { a: parseInt(attack.value, 10), d: parseInt(decay.value, 10),
             s: parseInt(sustain.value, 10) / 100, r: parseInt(release.value, 10) };
  }

  function outs(v) {
    attackOut.textContent = v.a + ' ms';
    decayOut.textContent = v.d + ' ms';
    sustainOut.textContent = Math.round(v.s * 100) + '%';
    releaseOut.textContent = v.r + ' ms';
  }

  function ads(t, v) {
    if (t < v.a) return v.a > 0 ? t / v.a : 1;
    if (t < v.a + v.d) return v.d > 0 ? 1 - (1 - v.s) * (t - v.a) / v.d : v.s;
    return v.s;
  }

  function levelAt(t, g, v) {
    if (t < g) return ads(t, v);
    var L = ads(g, v);
    if (v.r <= 0) return 0;
    var k = (t - g) / v.r;
    return k >= 1 ? 0 : L * (1 - k);
  }

  function stageAt(t, g, v) {
    if (t >= g) return 'release';
    if (t < v.a) return 'attack';
    if (t < v.a + v.d) return 'decay';
    return 'sustain';
  }

  function points(g, v) {
    var pts = [[0, 0]];
    if (g >= v.a) {
      pts.push([v.a, 1]);
      if (g >= v.a + v.d) { pts.push([v.a + v.d, v.s]); pts.push([g, v.s]); }
      else { pts.push([g, ads(g, v)]); }
    } else {
      pts.push([g, v.a > 0 ? g / v.a : 1]);
    }
    pts.push([g + v.r, 0]);
    return pts;
  }

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function draw(v, g, t) {
    var G = setup(cv), ctx = G.ctx;
    var padL = 10, padR = 10, top = 14, base = G.h - 22;
    var total = g + v.r; if (total <= 0) total = 1;
    var span = G.w - padL - padR;
    function X(tt) { return padL + (tt / total) * span; }
    function Y(l) { return base - l * (base - top); }

    ctx.fillStyle = SHADE;
    ctx.fillRect(X(0), top, X(g) - X(0), base - top);

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, base + 0.5); ctx.lineTo(G.w - padR, base + 0.5);
    ctx.moveTo(padL + 0.5, top); ctx.lineTo(padL + 0.5, base);
    ctx.stroke();

    var ys = Y(v.s);
    ctx.strokeStyle = SECOND; ctx.setLineDash([3, 4]);
    ctx.beginPath(); ctx.moveTo(padL, ys + 0.5); ctx.lineTo(G.w - padR, ys + 0.5); ctx.stroke();
    ctx.setLineDash([]);

    var txt = Math.round(v.s * 100) + '%';
    ctx.font = '11px "JetBrains Mono", ui-monospace, monospace';
    ctx.textAlign = 'right'; ctx.textBaseline = 'alphabetic';
    var tw = ctx.measureText(txt).width;
    var tx = G.w - padR, ty = Math.max(top + 9, ys - 4);
    ctx.fillStyle = BG; ctx.fillRect(tx - tw - 3, ty - 10, tw + 5, 13);
    ctx.fillStyle = MUTED; ctx.fillText(txt, tx, ty);

    var pts = points(g, v), i;
    ctx.strokeStyle = ACCENT; ctx.lineWidth = 2;
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.beginPath();
    for (i = 0; i < pts.length; i++) {
      var px = X(pts[i][0]), py = Y(pts[i][1]);
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.stroke();

    ctx.font = '12px "Space Grotesk", system-ui, sans-serif';
    ctx.textAlign = 'center'; ctx.fillStyle = MUTED;
    var segs = [['A', 0, Math.min(v.a, g)],
                ['D', Math.min(v.a, g), Math.min(v.a + v.d, g)],
                ['S', Math.min(v.a + v.d, g), g],
                ['R', g, total]];
    for (i = 0; i < segs.length; i++) {
      var s0 = segs[i][1], s1 = segs[i][2];
      if (X(s1) - X(s0) >= 14) ctx.fillText(segs[i][0], (X(s0) + X(s1)) / 2, G.h - 6);
    }

    if (t !== null) {
      var bt = Math.min(t, total);
      ctx.fillStyle = ACCENT;
      ctx.beginPath(); ctx.arc(X(bt), Y(levelAt(bt, g, v)), 4.5, 0, Math.PI * 2); ctx.fill();
    }
  }

  function setStage(s) { if (stageOut.textContent !== s) stageOut.textContent = s; }

  function render() {
    var v = vals(); outs(v);
    var t = null, g = v.a + v.d + NOMINAL;
    if (!reduce && mode !== 'idle') {
      t = now() - pressT;
      if (mode === 'held') { g = Math.max(t, g); }
      else {
        g = gateLen;
        if (t >= g + v.r) { mode = 'idle'; t = null; g = v.a + v.d + NOMINAL; }
      }
      setStage(t === null ? 'silencio' : stageAt(t, g, v));
    }
    draw(v, g, t);
  }

  function loop() {
    raf = 0;
    render();
    if (mode !== 'idle') raf = requestAnimationFrame(loop);
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

  // --- nota: A3 = 220 Hz, sawtooth, con la MISMA envolvente que dibuja el canvas ---
  var FREQ = 220;
  var sndBtn = document.getElementById('snd');
  var volIn = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var note = null, switching = false;

  function noteOn(v) {
    if (!audio.on()) return;
    noteOff(true);
    var ctx = audio.ctx(), t = ctx.currentTime;
    var osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = FREQ;
    var g = ctx.createGain();
    // attack y decay con rampas; piso de 5 ms para no cortar en seco.
    var a = Math.max(v.a / 1000, 0.005), d = Math.max(v.d / 1000, 0.005);
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.9, t + a);
    g.gain.linearRampToValueAtTime(0.9 * v.s, t + a + d);
    osc.connect(g);
    g.connect(audio.master());
    osc.start(t);
    note = { osc: osc, gain: g };
  }

  function noteOff(fast) {
    if (!note) return;
    var n = note; note = null;
    var r = fast ? 0.01 : Math.max(parseInt(release.value, 10) / 1000, 0.01);
    audio.ramp(n.gain.gain, 0, r);
    try { n.osc.stop(audio.ctx().currentTime + r + 0.02); } catch (e) {}
    setTimeout(function () {
      try { n.osc.disconnect(); } catch (e) {}
      try { n.gain.disconnect(); } catch (e) {}
    }, r * 1000 + 200);
  }

  function reflectSound(on) { sndBtn.setAttribute('aria-pressed', on ? 'true' : 'false'); }

  sndBtn.addEventListener('click', function () {
    if (switching) return;
    if (audio.on()) {
      reflectSound(false);
      noteOff(true);
      switching = true;
      setTimeout(function () { if (audio.on()) audio.toggle(); switching = false; }, 90);
    } else {
      audio.toggle();
      audio.setVolume(parseInt(volIn.value, 10) / 100);
      reflectSound(true);
    }
  });

  volIn.addEventListener('input', function () {
    var pct = parseInt(volIn.value, 10);
    volOut.textContent = pct + '%';
    audio.setVolume(pct / 100);
  });

  document.addEventListener('visibilitychange', function () {
    if (document.hidden && audio.on()) { noteOff(true); audio.toggle(); reflectSound(false); }
  });

  function press(e) {
    if (e && e.cancelable && e.type !== 'mousedown') e.preventDefault();
    if (mode === 'held') return;
    mode = 'held'; pressT = now();
    noteOn(vals());
    btn.classList.add('on'); btn.setAttribute('aria-pressed', 'true');
    if (reduce) { setStage('sustain'); render(); }
    else if (!raf) raf = requestAnimationFrame(loop);
  }

  function letGo() {
    if (mode !== 'held') return;
    noteOff(false);
    btn.classList.remove('on'); btn.setAttribute('aria-pressed', 'false');
    if (reduce) { mode = 'idle'; setStage('silencio'); render(); return; }
    gateLen = now() - pressT; mode = 'rel';
    if (!raf) raf = requestAnimationFrame(loop);
  }

  btn.addEventListener('mousedown', press);
  btn.addEventListener('touchstart', press, { passive: false });
  btn.addEventListener('mouseup', letGo);
  btn.addEventListener('mouseleave', letGo);
  btn.addEventListener('touchend', letGo);
  btn.addEventListener('touchcancel', letGo);
  btn.addEventListener('blur', letGo);
  btn.addEventListener('keydown', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') {
      if (e.repeat) { e.preventDefault(); return; }
      press(e);
    }
  });
  btn.addEventListener('keyup', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') letGo();
  });

  [attack, decay, sustain, release].forEach(function (el) {
    el.addEventListener('input', function () { if (mode === 'idle' || reduce) render(); });
  });
  window.addEventListener('resize', function () { if (mode === 'idle' || reduce) render(); });

  render();
})();
</script>
</body>
</html>
$d2$, 460)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000003', '00000000-0000-4000-8000-AB0000000001', 'cuestionario-analog-1', 'Autoevaluación · Analog 1', $d3$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Autoevaluación · Analog</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  [hidden] { display: none !important; }
  .step { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
          color: #8C8C8A; margin: 0 0 8px; }
  .q { font-size: 15px; font-weight: 500; line-height: 1.3; margin: 0 0 10px; outline: none; }
  .opt { display: block; width: 100%; min-height: 44px; margin: 0 0 6px; padding: 8px 12px;
         text-align: left; background: #242426; border: 0.5px solid #3A3A3C; border-radius: 8px;
         color: #EDEDEB; font: 400 14px/1.3 'Space Grotesk', system-ui, sans-serif;
         cursor: pointer; transition: border-color .12s linear; }
  .opt:hover:enabled { border-color: #5A5A5C; }
  .opt:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .opt:disabled { cursor: default; color: #8C8C8A; border-color: #2C2C2E; }
  .opt.ok { border-color: #E08E33; color: #E08E33; }
  .opt.bad { border-color: #7A3B34; color: #E2695C; }
  .fb { font-size: 13px; line-height: 1.35; color: #9A9A97; margin: 10px 0 0; min-height: 52px; }
  .fb b { font-weight: 500; }
  .fb .ok { color: #E08E33; }
  .fb .bad { color: #E2695C; }
  .btn { min-height: 36px; padding: 8px 16px; border: none; border-radius: 8px;
         background: #E08E33; color: #141414;
         font: 500 14px 'Space Grotesk', system-ui, sans-serif; cursor: pointer; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .end { padding: 36px 0 0; }
  .score { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 34px;
           color: #E08E33; margin: 0; outline: none; }
  .score span { color: #8C8C8A; }
  .close { font-size: 13px; color: #9A9A97; margin: 8px 0 16px; }
  @media (prefers-reduced-motion: reduce) { .opt { transition: none; } }
</style>
</head>
<body>
  <div id="quiz">
    <p class="step" id="step">pregunta 01 / 04</p>
    <h1 class="q" id="question" tabindex="-1"></h1>
    <div id="options"></div>
    <p class="fb" id="feedback" role="status" aria-live="polite"></p>
    <button class="btn" id="next" hidden>Siguiente</button>
  </div>

  <div class="end" id="end" hidden>
    <p class="score" id="score" tabindex="-1"></p>
    <p class="close" id="close"></p>
    <button class="btn" id="retry">Reintentar</button>
  </div>

<script>
(function () {
  var Q = [
    { q: '¿Qué forma de onda contiene solo la frecuencia fundamental, sin armónicos?',
      o: ['Sierra', 'Cuadrada', 'Sinusoidal', 'Ruido'], c: 2,
      e: 'La sinusoidal es una sola frecuencia; todas las demás tienen armónicos.' },
    { q: 'En la envolvente ADSR, ¿cuál de los cuatro parámetros es un nivel y no un tiempo?',
      o: ['Attack', 'Decay', 'Sustain', 'Release'], c: 2,
      e: 'Sustain es el nivel que se mantiene mientras sostenés la tecla; los otros tres son tiempos.' },
    { q: 'La síntesis sustractiva parte de una onda rica en armónicos y…',
      o: ['le quita frecuencias con filtros', 'le suma osciladores',
          'modula la frecuencia de una portadora', 'usa samples'], c: 0,
      e: 'Sustractiva = filtrar/quitar. Por eso se arranca de sierra o cuadrada.' },
    { q: 'El sub-oscilador de Analog agrega un oscilador afinado…',
      o: ['una octava arriba', 'una octava abajo', 'una quinta arriba', 'a la misma altura'], c: 1,
      e: 'Suma peso en los graves, clave para bajos.' }
  ];

  var CIERRE = [
    'Conviene volver al video antes de seguir.',
    'Conviene volver al video antes de seguir.',
    'Vas por la mitad: repasá los puntos que fallaste.',
    'Casi todo claro. Repasá el que se te escapó.',
    'Los cuatro conceptos quedaron firmes.'
  ];

  var step = document.getElementById('step');
  var question = document.getElementById('question');
  var options = document.getElementById('options');
  var feedback = document.getElementById('feedback');
  var next = document.getElementById('next');
  var quiz = document.getElementById('quiz');
  var end = document.getElementById('end');
  var score = document.getElementById('score');
  var close = document.getElementById('close');
  var retry = document.getElementById('retry');

  var idx = 0, hits = 0, buttons = [];

  function pad(n) { return (n < 10 ? '0' : '') + n; }

  function render(focus) {
    var item = Q[idx];
    step.textContent = 'pregunta ' + pad(idx + 1) + ' / ' + pad(Q.length);
    question.textContent = item.q;
    feedback.textContent = '';
    next.hidden = true;
    next.textContent = idx === Q.length - 1 ? 'Ver resultado' : 'Siguiente';
    options.textContent = '';
    buttons = item.o.map(function (text, i) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'opt';
      b.textContent = text;
      b.addEventListener('click', function () { answer(i); });
      options.appendChild(b);
      return b;
    });
    if (focus) question.focus();
  }

  function answer(i) {
    var item = Q[idx], ok = i === item.c;
    if (ok) hits++;
    buttons.forEach(function (b, j) {
      b.disabled = true;
      if (j === item.c) b.className = 'opt ok';
      if (j === i && !ok) b.className = 'opt bad';
    });
    var tag = document.createElement('b');
    tag.className = ok ? 'ok' : 'bad';
    tag.textContent = ok ? 'Correcto.' : 'Incorrecto.';
    feedback.textContent = '';
    feedback.appendChild(tag);
    var previa = ok ? ' ' : ' La correcta era «' + item.o[item.c] + '». ';
    feedback.appendChild(document.createTextNode(previa + item.e));
    next.hidden = false;
    next.focus();
  }

  function finish() {
    quiz.hidden = true;
    end.hidden = false;
    score.textContent = '';
    score.appendChild(document.createTextNode(String(hits)));
    var rest = document.createElement('span');
    rest.textContent = ' / ' + Q.length;
    score.appendChild(rest);
    score.setAttribute('aria-label', 'Resultado: ' + hits + ' de ' + Q.length + ' correctas');
    close.textContent = CIERRE[hits];
    score.focus();
  }

  next.addEventListener('click', function () {
    if (idx === Q.length - 1) finish();
    else { idx++; render(true); }
  });

  retry.addEventListener('click', function () {
    idx = 0; hits = 0;
    end.hidden = true;
    quiz.hidden = false;
    render(true);
  });

  render(false);
})();
</script>
</body>
</html>
$d3$, 460)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000004', '00000000-0000-4000-8000-AB0000000001', 'mono-vs-poli', 'Monofonía y polifonía', $d4$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mono contra poli</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .row { display: grid; grid-template-columns: 52px 1fr 54px; gap: 10px;
         align-items: center; margin-bottom: 8px; }
  .row label, .row .label { font-size: 13px; color: #9A9A97; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
           text-align: right; }
  input[type=range] { accent-color: #E08E33; width: 100%; margin: 0; }
  input[type=range]:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .row.off label, .row.off .value { color: #48484A; }
  .row.off input[type=range] { accent-color: #48484A; }

  .modes { grid-template-columns: 52px 1fr auto; }
  .seg { display: flex; gap: 6px; }
  .btn { font-family: inherit; font-size: 13px; font-weight: 500; padding: 6px 12px;
         background: #242426; border: 1px solid #3A3A3C; border-radius: 6px;
         color: #EDEDEB; cursor: pointer; }
  .btn.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }

  .keys { position: relative; height: 58px; margin: 10px 0 6px;
          -webkit-user-select: none; user-select: none; touch-action: none; }
  .key { position: absolute; top: 0; margin: 0; padding: 0 0 5px; box-sizing: border-box;
         font-family: inherit; font-size: 11px; color: #9A9A97;
         display: flex; align-items: flex-end; justify-content: center;
         cursor: pointer; touch-action: none; }
  .key.w { height: 58px; width: 14.2857%; background: #242426;
           border: 1px solid #3A3A3C; border-radius: 0 0 4px 4px; }
  .key.b { height: 36px; width: 8.2%; background: #1B1B1D; border: 1px solid #3A3A3C;
           border-radius: 0 0 4px 4px; z-index: 2; font-size: 0; }
  .key.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .key:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; z-index: 3; }

  canvas { display: block; width: 100%; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 0 0 4px; }
  .caption .value { text-align: left; }
  .foot { font-size: 12px; color: #8C8C8A; margin: 8px 0 0; line-height: 1.4; }

  .audio { display: grid; grid-template-columns: auto 52px 1fr 44px; gap: 10px;
           align-items: center; margin-top: 10px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
</style>
</head>
<body>
  <div class="row modes">
    <span class="label" id="modeLbl">Modo</span>
    <div class="seg" role="group" aria-labelledby="modeLbl">
      <button id="mono" type="button" class="btn on" aria-pressed="true">Mono</button>
      <button id="poli" type="button" class="btn" aria-pressed="false">Poli</button>
    </div>
    <button id="chord" type="button" class="btn">Acorde</button>
  </div>

  <div class="row off" id="voicesRow">
    <label for="voices">Voces</label>
    <input id="voices" type="range" min="1" max="8" step="1" value="4" disabled>
    <span class="value" id="voicesOut">1</span>
  </div>

  <div class="keys" id="keys" role="group" aria-label="Teclado de una octava, do a si">
    <button type="button" class="key w" data-note="60" style="left:0%" aria-label="Do">C</button>
    <button type="button" class="key w" data-note="62" style="left:14.2857%" aria-label="Re">D</button>
    <button type="button" class="key w" data-note="64" style="left:28.5714%" aria-label="Mi">E</button>
    <button type="button" class="key w" data-note="65" style="left:42.8571%" aria-label="Fa">F</button>
    <button type="button" class="key w" data-note="67" style="left:57.1428%" aria-label="Sol">G</button>
    <button type="button" class="key w" data-note="69" style="left:71.4285%" aria-label="La">A</button>
    <button type="button" class="key w" data-note="71" style="left:85.7142%" aria-label="Si">B</button>
    <button type="button" class="key b" data-note="61" style="left:10.19%" aria-label="Do sostenido"></button>
    <button type="button" class="key b" data-note="63" style="left:24.47%" aria-label="Re sostenido"></button>
    <button type="button" class="key b" data-note="66" style="left:53.04%" aria-label="Fa sostenido"></button>
    <button type="button" class="key b" data-note="68" style="left:67.33%" aria-label="Sol sostenido"></button>
    <button type="button" class="key b" data-note="70" style="left:81.61%" aria-label="La sostenido"></button>
  </div>

  <p class="caption">voces sonando <span class="value" id="countOut">0 / 1</span></p>
  <canvas id="roll" style="height:140px" role="img"
          aria-label="Líneas de voz en el tiempo: la altura de cada línea es la altura de la nota. En mono una sola línea salta de nota en nota; en poli cada nota abre su línea y, al pasarse del límite, la voz más vieja se corta."></canvas>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <p class="foot">Qué mirar: un bajo mono tiene una sola voz, así que el acorde le queda en la última nota. La polifonía las apila y cobra cada voz en CPU.</p>

<script>
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

(function () {
  var monoBtn = document.getElementById('mono');
  var poliBtn = document.getElementById('poli');
  var chordBtn = document.getElementById('chord');
  var voices = document.getElementById('voices');
  var voicesRow = document.getElementById('voicesRow');
  var voicesOut = document.getElementById('voicesOut');
  var countOut = document.getElementById('countOut');
  var keysEl = document.getElementById('keys');
  var cv = document.getElementById('roll');
  var snd = document.getElementById('snd');
  var vol = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ACCENT = '#E08E33', MUTED = '#8C8C8A', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var WINDOW = 3.6;      // segundos visibles
  var HOLD = 1.4;        // cada nota se apaga sola
  var ATTACK = 0.01;     // 10 ms
  var RELEASE = 0.12;    // 120 ms
  var STEAL = 0.015;     // corte audible, pero sin click
  var PEAK = 0.16;
  var LO = 59.5, HI = 71.5;

  var poly = false;
  var live = [];   // voces sonando, de la más vieja a la más nueva
  var segs = [];   // trazos dibujados
  var raf = 0, lastT = 0;

  function tnow() { return performance.now() / 1000; }
  function freq(n) { return 440 * Math.pow(2, (n - 69) / 12); }
  function limit() { return poly ? parseInt(voices.value, 10) : 1; }

  function keyEls(note) {
    return keysEl.querySelectorAll('[data-note="' + note + '"]');
  }
  function paintKey(note, on) {
    var els = keyEls(note), i;
    for (i = 0; i < els.length; i++) els[i].classList.toggle('on', on);
  }
  function keyHeld(note) {
    var i;
    for (i = 0; i < live.length; i++) if (live[i].note === note) return true;
    return false;
  }

  function counts() {
    countOut.textContent = live.length + ' / ' + limit();
  }

  function stop(v, cut) {
    var i = live.indexOf(v);
    if (i < 0) return;
    live.splice(i, 1);
    if (v.timer) { clearTimeout(v.timer); v.timer = 0; }
    v.seg.t1 = tnow();
    v.seg.cut = !!cut;
    if (v.gain && v.osc) {
      var rel = cut ? STEAL : RELEASE;
      var a = audio.ctx();
      audio.ramp(v.gain.gain, 0, rel);
      try { v.osc.stop(a.currentTime + rel + 0.03); } catch (e) { /* ya detenido */ }
    }
    if (!keyHeld(v.note)) paintKey(v.note, false);
    counts();
    mark();
  }

  function start(note) {
    var t = tnow(), i;
    for (i = live.length - 1; i >= 0; i--) {
      if (live[i].note === note) stop(live[i], true);
    }
    var jump = null;
    while (live.length >= limit()) {
      var old = live[0];
      if (!poly) jump = old.note;
      stop(old, true);
    }

    var seg = { note: note, t0: t, t1: null, cut: false, jump: jump };
    segs.push(seg);
    var v = { note: note, seg: seg, osc: null, gain: null, timer: 0 };

    var ctx = audio.ctx();
    if (audio.on() && ctx) {
      var g = ctx.createGain();
      g.gain.value = 0;
      var o = ctx.createOscillator();
      o.type = 'sawtooth';
      o.frequency.value = freq(note);
      o.connect(g);
      g.connect(audio.master());
      o.start();
      audio.ramp(g.gain, PEAK, ATTACK);
      v.osc = o; v.gain = g;
    }
    v.timer = setTimeout(function () { stop(v, false); }, HOLD * 1000);
    live.push(v);
    paintKey(note, true);
    counts();
    mark();
  }

  function mark() {
    lastT = tnow();
    if (reduce) { draw(); return; }
    if (!raf) raf = requestAnimationFrame(loop);
  }

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function draw() {
    var G = setup(cv), ctx = G.ctx, i;
    var padL = 8, padR = 8, top = 10, base = G.h - 10;
    var span = G.w - padL - padR;
    var end = reduce ? lastT + 0.8 : tnow();

    // limpieza de trazos fuera de la ventana
    var keep = [];
    for (i = 0; i < segs.length; i++) {
      if (segs[i].t1 === null || segs[i].t1 > end - WINDOW) keep.push(segs[i]);
    }
    segs = keep;

    function X(t) {
      var x = padL + (1 - (end - t) / WINDOW) * span;
      return x < padL ? padL : (x > G.w - padR ? G.w - padR : x);
    }
    function Y(n) { return base - (n - LO) / (HI - LO) * (base - top); }

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath();
    for (i = 60; i <= 71; i++) {
      var gy = Math.round(Y(i)) + 0.5;
      ctx.moveTo(padL, gy); ctx.lineTo(G.w - padR, gy);
    }
    ctx.moveTo(padL + 0.5, top); ctx.lineTo(padL + 0.5, base);
    ctx.stroke();

    ctx.lineCap = 'butt';
    for (i = 0; i < segs.length; i++) {
      var s = segs[i];
      var x0 = X(s.t0), x1 = X(s.t1 === null ? end : s.t1), y = Y(s.note);

      if (s.jump !== null && s.jump !== undefined && x0 > padL) {
        ctx.strokeStyle = SECOND; ctx.lineWidth = 1;
        ctx.setLineDash([2, 3]);
        ctx.beginPath();
        ctx.moveTo(x0 + 0.5, Y(s.jump)); ctx.lineTo(x0 + 0.5, y);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      ctx.strokeStyle = s.cut ? SECOND : ACCENT;
      ctx.lineWidth = s.cut ? 1.5 : 2.4;
      ctx.beginPath();
      ctx.moveTo(x0, y); ctx.lineTo(Math.max(x1, x0 + 1), y);
      ctx.stroke();

      if (s.cut && x1 > padL && x1 < G.w - padR) {
        ctx.strokeStyle = MUTED; ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(x1 + 0.5, y - 5); ctx.lineTo(x1 + 0.5, y + 5);
        ctx.stroke();
      }
    }
  }

  function loop() {
    raf = 0;
    draw();
    if (live.length || segs.length) raf = requestAnimationFrame(loop);
  }

  function setMode(next) {
    poly = next;
    monoBtn.classList.toggle('on', !poly);
    poliBtn.classList.toggle('on', poly);
    monoBtn.setAttribute('aria-pressed', poly ? 'false' : 'true');
    poliBtn.setAttribute('aria-pressed', poly ? 'true' : 'false');
    voices.disabled = !poly;
    voicesRow.classList.toggle('off', !poly);
    voicesOut.textContent = String(limit());
    while (live.length > limit()) stop(live[0], true);
    counts();
    mark();
  }

  // El visual funciona igual sin sonido: el audio es la capa de arriba.
  function trigger(note) { start(note); }

  var kids = keysEl.querySelectorAll('.key'), k;
  for (k = 0; k < kids.length; k++) {
    (function (el) {
      var note = parseInt(el.getAttribute('data-note'), 10);
      function hit(e) {
        if (e && e.cancelable && e.type !== 'mousedown') e.preventDefault();
        trigger(note);
      }
      if (window.PointerEvent) el.addEventListener('pointerdown', hit);
      else {
        el.addEventListener('mousedown', hit);
        el.addEventListener('touchstart', hit, { passive: false });
      }
      el.addEventListener('keydown', function (e) {
        if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') {
          if (e.repeat) { e.preventDefault(); return; }
          e.preventDefault();
          trigger(note);
        }
      });
    })(kids[k]);
  }

  monoBtn.addEventListener('click', function () { setMode(false); });
  poliBtn.addEventListener('click', function () { setMode(true); });
  chordBtn.addEventListener('click', function () {
    trigger(60); trigger(64); trigger(67);
  });

  voices.addEventListener('input', function () {
    voicesOut.textContent = String(limit());
    while (live.length > limit()) stop(live[0], true);
    counts();
    mark();
  });

  snd.addEventListener('click', function () {
    var on = audio.toggle();
    snd.classList.toggle('on', on);
    snd.setAttribute('aria-pressed', on ? 'true' : 'false');
    if (on) audio.setVolume(parseInt(vol.value, 10) / 100);
  });
  vol.addEventListener('input', function () {
    var v = parseInt(vol.value, 10);
    volOut.textContent = v + '%';
    audio.setVolume(v / 100);
  });

  window.addEventListener('resize', draw);

  counts();
  draw();
})();
</script>
</body>
</html>
$d4$, 480)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000005', '00000000-0000-4000-8000-AB0000000001', 'oscillator-sync', 'Oscillator sync', $d5$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hard sync de osciladores</title>
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
  .btn { font-family: inherit; font-size: 12px; line-height: 1; padding: 6px 10px;
         background: #242426; color: #EDEDEB; border: 1px solid #3A3A3C;
         border-radius: 6px; cursor: pointer; }
  .btn[aria-pressed="true"] { background: #E08E33; border-color: #E08E33; color: #141414; }
  .btn:disabled { background: #1B1B1D; color: #48484A; border-color: #2C2C2E; cursor: default; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .btns { display: flex; gap: 6px; }
  .soundbar { display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
              margin-bottom: 8px; }
  .audio { display: flex; align-items: center; gap: 8px; flex: 1 1 210px; }
  .audio input[type=range] { flex: 1; }
  .audio .value { min-width: 42px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 10px 0 4px; }
  .caption .value { text-align: left; }
  .foot { font-size: 12px; color: #8C8C8A; margin: 10px 0 0; line-height: 1.4; }
  canvas { display: block; width: 100%; }
  @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>
</head>
<body>
  <div class="row">
    <label for="ratio">Ratio</label>
    <input id="ratio" type="range" min="0" max="100" step="1" value="0">
    <span class="value" id="ratioOut">0%</span>
  </div>
  <div class="row">
    <span class="row-label" id="shapeLbl" style="font-size:13px;color:#9A9A97">Esclavo</span>
    <div class="btns" role="group" aria-labelledby="shapeLbl">
      <button id="saw" type="button" class="btn" aria-pressed="true">Sawtooth</button>
      <button id="sqr" type="button" class="btn" aria-pressed="false">Square</button>
    </div>
    <span></span>
  </div>

  <div class="soundbar">
    <button id="play" type="button" class="btn" aria-pressed="false" disabled>Tocar A3</button>
    <div class="audio">
      <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
      <label for="vol" class="label">Volumen</label>
      <input id="vol" type="range" min="0" max="100" step="1" value="15">
      <span class="value" id="volOut">15%</span>
    </div>
  </div>

  <p class="caption">Esclavo sobre 2 ciclos del maestro · esclavo <span class="value" id="mulOut">x1.00</span></p>
  <canvas id="wave" style="height:120px" role="img" aria-label="Forma de onda del oscilador esclavo con marcas verticales donde el maestro reinicia su fase"></canvas>
  <p class="caption">Armónicos</p>
  <canvas id="spec" style="height:50px" role="img" aria-label="Barras de amplitud de los primeros armónicos de la onda sincronizada"></canvas>

  <p class="foot">Qué mirar: el sync suma armónicos sin cambiar la nota — sigue siendo A3, 220 Hz. Barrer el Ratio de punta a punta es el clásico <em>sync sweep</em>.</p>

<script>
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

(function () {
  var ratio = document.getElementById('ratio');
  var ratioOut = document.getElementById('ratioOut');
  var mulOut = document.getElementById('mulOut');
  var sawBtn = document.getElementById('saw');
  var sqrBtn = document.getElementById('sqr');
  var playBtn = document.getElementById('play');
  var sndBtn = document.getElementById('snd');
  var vol = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var waveCv = document.getElementById('wave');
  var specCv = document.getElementById('spec');

  var ACCENT = '#E08E33', AXIS = '#2C2C2E', SECOND = '#5A5A5C', MUTED = '#8C8C8A';
  var BASE_HZ = 220;          // A3: la altura la fija el maestro y no cambia nunca
  var MAX_MUL = 5;            // Ratio 100% => el esclavo corre a 5x el maestro
  var HARMONICS = 56;         // banda útil: 56 x 220 Hz ~ 12.3 kHz
  var DFT_N = 2048;
  var shape = 'saw';

  // ---- forma base del esclavo, fase normalizada en [0,1) ----
  function base(p) {
    p = p - Math.floor(p);
    return shape === 'saw' ? (2 * p - 1) : (p < 0.5 ? 1 : -1);
  }
  function mul() { return 1 + (parseInt(ratio.value, 10) / 100) * (MAX_MUL - 1); }
  // Valor del esclavo sincronizado, con u = fase del MAESTRO en [0,1).
  // El maestro reinicia al esclavo en cada u entero: por eso la fase del
  // esclavo es u*mul y arranca de cero en cada ciclo del maestro.
  function synced(u, m) { return base((u - Math.floor(u)) * m); }

  // ---- tabla de armónicos ----
  // APROXIMACIÓN DE AUDIO: Web Audio no tiene hard sync nativo (no se puede
  // reiniciar la fase de un OscillatorNode en marcha). Pero la onda con hard
  // sync es EXACTAMENTE periódica en el período del maestro, sea cual sea el
  // ratio, porque la fase del esclavo se reinicia en cada ciclo. Así que
  // calculamos por DFT los coeficientes de Fourier de UN período del maestro
  // y los mandamos a createPeriodicWave(): un solo oscilador a 220 Hz
  // reproduce la misma forma, con la síntesis limitada en banda del browser.
  // Lo único aproximado es el truncado a 56 armónicos (mata el alias de los
  // saltos) con ventana sigma de Lánczos para suavizar el Gibbs. La tabla se
  // recalcula cada vez que cambia el Ratio o la forma del esclavo.
  function harmonics(m) {
    var f = new Float64Array(DFT_N), k, n;
    for (k = 0; k < DFT_N; k++) f[k] = synced(k / DFT_N, m);
    var real = new Float32Array(HARMONICS + 1);
    var imag = new Float32Array(HARMONICS + 1);
    var mag = new Float64Array(HARMONICS + 1);
    for (n = 1; n <= HARMONICS; n++) {
      var dth = 2 * Math.PI * n / DFT_N;
      var c = Math.cos(dth), s = Math.sin(dth);
      var cs = 1, sn = 0, a = 0, b = 0, t;
      for (k = 0; k < DFT_N; k++) {
        a += f[k] * cs;
        b += f[k] * sn;
        t = cs * c - sn * s; sn = sn * c + cs * s; cs = t;
      }
      a = 2 * a / DFT_N; b = 2 * b / DFT_N;
      var x = Math.PI * n / (HARMONICS + 1);
      var sigma = Math.sin(x) / x;        // ventana de Lánczos
      real[n] = a * sigma; imag[n] = b * sigma;
      mag[n] = Math.sqrt(a * a + b * b);
    }
    return { real: real, imag: imag, mag: mag };
  }

  // ---- canvas ----
  function setup(c, axis) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    if (axis) {
      ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, Math.round(r.height / 2) + 0.5);
      ctx.lineTo(r.width, Math.round(r.height / 2) + 0.5);
      ctx.stroke();
    }
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function drawWave(m) {
    var g = setup(waveCv, true);
    var mid = g.h / 2, amp = g.h / 2 - 6;
    var CYCLES = 2;
    // marcas del maestro: solo hay reinicio audible con Ratio > 0
    if (parseInt(ratio.value, 10) > 0) {
      g.ctx.strokeStyle = SECOND; g.ctx.lineWidth = 1;
      for (var i = 0; i <= CYCLES; i++) {
        var x = Math.round(g.w * i / CYCLES) + (i === CYCLES ? -0.5 : 0.5);
        g.ctx.beginPath();
        g.ctx.moveTo(x, 2); g.ctx.lineTo(x, g.h - 2);
        g.ctx.stroke();
      }
    }
    g.ctx.strokeStyle = ACCENT; g.ctx.lineWidth = 1.6;
    g.ctx.lineJoin = 'round';
    g.ctx.beginPath();
    var steps = Math.max(240, Math.round(g.w * 3));
    for (var j = 0; j <= steps; j++) {
      var u = (j / steps) * CYCLES;
      var y = mid - synced(u, m) * amp;
      if (j === 0) g.ctx.moveTo(0, y); else g.ctx.lineTo((j / steps) * g.w, y);
    }
    g.ctx.stroke();
  }

  function drawSpec(mag) {
    var g = setup(specCv, false);
    var shown = 24, max = 0, n;
    for (n = 1; n <= shown; n++) if (mag[n] > max) max = mag[n];
    if (max <= 0) max = 1;
    g.ctx.strokeStyle = AXIS; g.ctx.lineWidth = 1;
    g.ctx.beginPath();
    g.ctx.moveTo(0, g.h - 0.5); g.ctx.lineTo(g.w, g.h - 0.5); g.ctx.stroke();
    var slot = g.w / shown, bw = Math.max(2, slot - 3);
    g.ctx.fillStyle = ACCENT;
    for (n = 1; n <= shown; n++) {
      var hgt = Math.max(1, (mag[n] / max) * (g.h - 4));
      g.ctx.fillRect((n - 1) * slot + (slot - bw) / 2, g.h - 1 - hgt, bw, hgt);
    }
  }

  // ---- audio ----
  var wave = null, table = null, osc = null, noteGain = null;

  function buildWave(m) {
    table = harmonics(m);
    var ctx = audio.ctx();
    wave = ctx ? ctx.createPeriodicWave(table.real, table.imag) : null;
    if (osc && wave) osc.setPeriodicWave(wave);
  }

  function noteOn() {
    var ctx = audio.ctx();
    if (!audio.on() || !ctx || osc) return;
    if (!wave) buildWave(mul());
    osc = ctx.createOscillator();
    osc.setPeriodicWave(wave);
    osc.frequency.value = BASE_HZ;
    noteGain = ctx.createGain();
    noteGain.gain.value = 0;
    osc.connect(noteGain);
    noteGain.connect(audio.master());
    osc.start();
    audio.ramp(noteGain.gain, 0.8, 0.012);
    playBtn.setAttribute('aria-pressed', 'true');
  }

  function noteOff() {
    if (!osc) return;
    var ctx = audio.ctx(), o = osc, gn = noteGain;
    osc = null; noteGain = null;
    audio.ramp(gn.gain, 0, 0.02);
    try { o.stop(ctx.currentTime + 0.06); } catch (e) { /* ya detenido */ }
    setTimeout(function () { try { o.disconnect(); gn.disconnect(); } catch (e) {} }, 200);
    playBtn.setAttribute('aria-pressed', 'false');
  }

  // ---- render ----
  function draw() {
    var m = mul();
    ratioOut.textContent = ratio.value + '%';
    mulOut.textContent = 'x' + m.toFixed(2);
    buildWave(m);
    drawWave(m);
    drawSpec(table.mag);
  }

  ratio.addEventListener('input', draw);
  window.addEventListener('resize', function () {
    var m = mul();
    drawWave(m);
    if (table) drawSpec(table.mag);
  });

  function setShape(next) {
    shape = next;
    sawBtn.setAttribute('aria-pressed', String(next === 'saw'));
    sqrBtn.setAttribute('aria-pressed', String(next === 'sqr'));
    draw();
  }
  sawBtn.addEventListener('click', function () { setShape('saw'); });
  sqrBtn.addEventListener('click', function () { setShape('sqr'); });

  sndBtn.addEventListener('click', function () {
    var on = audio.toggle();
    sndBtn.setAttribute('aria-pressed', String(on));
    playBtn.disabled = !on;
    if (on) { audio.setVolume(parseInt(vol.value, 10) / 100); buildWave(mul()); }
    else noteOff();
  });
  vol.addEventListener('input', function () {
    volOut.textContent = vol.value + '%';
    audio.setVolume(parseInt(vol.value, 10) / 100);
  });

  playBtn.addEventListener('pointerdown', function (e) { e.preventDefault(); noteOn(); });
  playBtn.addEventListener('pointerup', noteOff);
  playBtn.addEventListener('pointercancel', noteOff);
  playBtn.addEventListener('pointerleave', noteOff);
  playBtn.addEventListener('keydown', function (e) {
    if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); if (!e.repeat) noteOn(); }
  });
  playBtn.addEventListener('keyup', function (e) {
    if (e.key === ' ' || e.key === 'Enter') noteOff();
  });
  document.addEventListener('visibilitychange', function () { if (document.hidden) noteOff(); });

  // Sin animación continua: la demo se redibuja solo cuando el alumno toca
  // un control, así que cumple prefers-reduced-motion en los dos modos.
  draw();
})();
</script>
</body>
</html>
$d5$, 460)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000006', '00000000-0000-4000-8000-AB0000000001', 'lfo-forma', 'Formas del LFO', $d6$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Formas de onda del LFO</title>
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
  input[type=range]:disabled { accent-color: #48484A; }
  .row.off label, .row.off .value { color: #48484A; }
  .waves { display: flex; flex-wrap: wrap; gap: 6px; }
  .btn { font-family: 'Space Grotesk', system-ui, sans-serif; font-size: 11px;
         line-height: 1; padding: 7px 8px; border-radius: 6px;
         background: #242426; color: #EDEDEB; border: 1px solid #3A3A3C;
         cursor: pointer; }
  .btn[aria-pressed="true"] { background: #E08E33; color: #141414; border-color: #E08E33; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .audio { display: grid; grid-template-columns: auto 52px 1fr 52px; gap: 8px;
           align-items: center; margin: 10px 0 0; }
  .label { font-size: 12px; color: #8C8C8A; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 10px 0 4px; }
  .foot { font-size: 12px; color: #8C8C8A; margin: 10px 0 0; line-height: 1.4; }
  canvas { display: block; width: 100%; }
</style>
</head>
<body>
  <div class="row">
    <label id="waveLbl">Wave</label>
    <div class="waves" role="group" aria-labelledby="waveLbl">
      <button class="btn" type="button" data-wave="sine" aria-pressed="true">sine</button>
      <button class="btn" type="button" data-wave="tri" aria-pressed="false">tri</button>
      <button class="btn" type="button" data-wave="rect" aria-pressed="false">rect</button>
      <button class="btn" type="button" data-wave="steps" aria-pressed="false">noise-pasos</button>
      <button class="btn" type="button" data-wave="ramps" aria-pressed="false">noise-rampas</button>
    </div>
    <span></span>
  </div>
  <div class="row off" id="widthRow">
    <label for="width">Width</label>
    <input id="width" type="range" min="0" max="100" step="1" value="50" disabled>
    <span class="value" id="widthOut">—</span>
  </div>
  <div class="row">
    <label for="rate">Rate</label>
    <input id="rate" type="range" min="0.1" max="8" step="0.1" value="1.5">
    <span class="value" id="rateOut">1.5 Hz</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <p class="caption">LFO · la forma que modula</p>
  <canvas id="wave" style="height:140px" role="img" aria-label="Onda del LFO: sinusoide"></canvas>

  <p class="foot">Qué mirar: Width deforma la onda — el LFO no es siempre una sinusoide.</p>

<script>
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

(function () {
  var waveBtns = [].slice.call(document.querySelectorAll('[data-wave]'));
  var widthRow = document.getElementById('widthRow');
  var widthIn = document.getElementById('width');
  var widthOut = document.getElementById('widthOut');
  var rateIn = document.getElementById('rate');
  var rateOut = document.getElementById('rateOut');
  var canvas = document.getElementById('wave');
  var snd = document.getElementById('snd');
  var vol = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ACCENT = '#E08E33', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var W_CYCLES = reduce ? 2 : 3;
  var CYCLE_SAMPLES = 4096;
  var NOISE_STEPS = 64;
  var SHAPED = { tri: 1, rect: 1 };
  var NAMES = { sine: 'sinusoide', tri: 'triangular', rect: 'rectangular',
                steps: 'ruido en pasos', ramps: 'ruido en rampas' };
  var AUTOSTOP = 20000;

  var wave = 'sine';
  var phase = 0, last = 0;

  // --- la forma: una sola fuente de verdad para dibujo y audio ---
  function rnd(i) {
    var k = ((i % NOISE_STEPS) + NOISE_STEPS) % NOISE_STEPS;
    var x = Math.sin(k * 127.1 + 311.7) * 43758.5453;
    return (x - Math.floor(x)) * 2 - 1;
  }
  function lfoValue(t, kind, w) {
    var p = t - Math.floor(t);
    if (kind === 'sine') return Math.sin(2 * Math.PI * p);
    if (kind === 'tri') {
      var r = Math.min(0.999, Math.max(0.001, 1 - w));
      return p < r ? (-1 + 2 * p / r) : (1 - 2 * (p - r) / (1 - r));
    }
    if (kind === 'rect') {
      var d = Math.min(0.99, Math.max(0.01, w));
      return p < d ? 1 : -1;
    }
    var i = Math.floor(t);
    if (kind === 'steps') return rnd(i);
    return rnd(i) + (rnd(i + 1) - rnd(i)) * p;
  }

  function state() {
    return {
      kind: wave,
      width: parseInt(widthIn.value, 10) / 100,
      rate: parseFloat(rateIn.value)
    };
  }

  // --- dibujo ---
  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function draw() {
    var s = state();
    var g = setup(canvas);
    var mid = g.h / 2, amp = g.h / 2 - 6;
    var x, k;

    g.ctx.strokeStyle = AXIS; g.ctx.lineWidth = 1;
    g.ctx.beginPath();
    g.ctx.moveTo(0, Math.round(mid - amp) + 0.5); g.ctx.lineTo(g.w, Math.round(mid - amp) + 0.5);
    g.ctx.moveTo(0, Math.round(mid + amp) + 0.5); g.ctx.lineTo(g.w, Math.round(mid + amp) + 0.5);
    for (k = Math.ceil(phase); k <= phase + W_CYCLES; k++) {
      x = Math.round(((k - phase) / W_CYCLES) * g.w) + 0.5;
      g.ctx.moveTo(x, mid - amp); g.ctx.lineTo(x, mid + amp);
    }
    g.ctx.stroke();

    g.ctx.strokeStyle = SECOND;
    g.ctx.beginPath();
    g.ctx.moveTo(0, Math.round(mid) + 0.5); g.ctx.lineTo(g.w, Math.round(mid) + 0.5);
    g.ctx.stroke();

    g.ctx.strokeStyle = ACCENT; g.ctx.lineWidth = 1.8;
    g.ctx.lineJoin = 'round';
    g.ctx.beginPath();
    for (x = 0; x <= g.w; x++) {
      var t = phase + (x / g.w) * W_CYCLES;
      var y = mid - lfoValue(t, s.kind, s.width) * amp;
      if (x === 0) g.ctx.moveTo(x, y); else g.ctx.lineTo(x, y);
    }
    g.ctx.stroke();
  }

  function sync() {
    var s = state();
    var shaped = !!SHAPED[s.kind];
    widthIn.disabled = !shaped;
    widthRow.className = shaped ? 'row' : 'row off';
    widthOut.textContent = shaped ? Math.round(s.width * 100) + '%' : '—';
    rateOut.textContent = s.rate.toFixed(1) + ' Hz';
    canvas.setAttribute('aria-label', 'Onda del LFO: ' + NAMES[s.kind]);
    draw();
  }

  // --- audio: tono sostenido con el cutoff modulado por el mismo LFO ---
  var nodes = null, stopTimer = null, soundOn = false;
  var bufKey = '', bufVal = null;

  function buffer(ctx, s) {
    var noisy = (s.kind === 'steps' || s.kind === 'ramps');
    var cycles = noisy ? NOISE_STEPS : 1;
    var key = s.kind + ':' + (SHAPED[s.kind] ? Math.round(s.width * 100) : 'x');
    if (key === bufKey && bufVal) return bufVal;
    var len = cycles * CYCLE_SAMPLES;
    var buf = ctx.createBuffer(1, len, ctx.sampleRate);
    var data = buf.getChannelData(0);
    for (var i = 0; i < len; i++) data[i] = lfoValue(i / CYCLE_SAMPLES, s.kind, s.width);
    bufKey = key; bufVal = buf;
    return buf;
  }

  function refreshLfo() {
    if (!nodes) return;
    var ctx = audio.ctx();
    var s = state();
    if (nodes.lfo) {
      try { nodes.lfo.stop(); } catch (e) {}
      try { nodes.lfo.disconnect(); } catch (e) {}
    }
    var src = ctx.createBufferSource();
    src.buffer = buffer(ctx, s);
    src.loop = true;
    src.playbackRate.value = s.rate * CYCLE_SAMPLES / ctx.sampleRate;
    src.connect(nodes.depth);
    src.start();
    nodes.lfo = src;
  }

  function startAudio() {
    var ctx = audio.ctx();
    if (!ctx || nodes) return;
    var osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = 220;
    var filt = ctx.createBiquadFilter();
    filt.type = 'lowpass';
    filt.frequency.value = 500;
    filt.Q.value = 6;
    var depth = ctx.createGain();
    depth.gain.value = 1800;
    var env = ctx.createGain();
    env.gain.value = 0;
    osc.connect(filt); filt.connect(env); env.connect(audio.master());
    depth.connect(filt.detune);
    osc.start();
    nodes = { osc: osc, filt: filt, env: env, depth: depth, lfo: null };
    refreshLfo();
    audio.ramp(env.gain, 0.9, 0.015);
  }

  function stopAudio() {
    if (!nodes) return;
    var n = nodes; nodes = null;
    var ctx = audio.ctx();
    audio.ramp(n.env.gain, 0, 0.02);
    var t = ctx.currentTime + 0.06;
    try { n.osc.stop(t); } catch (e) {}
    try { if (n.lfo) n.lfo.stop(t); } catch (e) {}
    setTimeout(function () {
      try {
        n.osc.disconnect(); n.filt.disconnect();
        n.env.disconnect(); n.depth.disconnect();
        if (n.lfo) n.lfo.disconnect();
      } catch (e) {}
    }, 200);
  }

  function armStop() {
    clearTimeout(stopTimer);
    stopTimer = setTimeout(function () { setSound(false); }, AUTOSTOP);
  }

  function setSound(want) {
    if (want === soundOn) return;
    soundOn = want;
    snd.setAttribute('aria-pressed', want ? 'true' : 'false');
    if (want) {
      if (!audio.on()) audio.toggle();
      audio.setVolume(parseInt(vol.value, 10) / 100);
      startAudio();
      armStop();
    } else {
      clearTimeout(stopTimer);
      stopAudio();
      setTimeout(function () { if (!soundOn && audio.on()) audio.toggle(); }, 150);
    }
  }

  function pushRate() {
    if (!nodes || !nodes.lfo) return;
    var ctx = audio.ctx();
    var v = parseFloat(rateIn.value) * CYCLE_SAMPLES / ctx.sampleRate;
    nodes.lfo.playbackRate.setTargetAtTime(v, ctx.currentTime, 0.02);
  }

  // --- eventos ---
  waveBtns.forEach(function (b) {
    b.addEventListener('click', function () {
      wave = b.getAttribute('data-wave');
      waveBtns.forEach(function (o) {
        o.setAttribute('aria-pressed', o === b ? 'true' : 'false');
      });
      sync();
      refreshLfo();
      if (soundOn) armStop();
    });
  });
  widthIn.addEventListener('input', function () {
    sync(); refreshLfo(); if (soundOn) armStop();
  });
  rateIn.addEventListener('input', function () {
    sync(); pushRate(); if (soundOn) armStop();
  });
  snd.addEventListener('click', function () { setSound(!soundOn); });
  vol.addEventListener('input', function () {
    var v = parseInt(vol.value, 10);
    volOut.textContent = v + '%';
    audio.setVolume(v / 100);
  });
  window.addEventListener('resize', draw);
  document.addEventListener('visibilitychange', function () {
    if (document.hidden && soundOn) setSound(false);
  });

  function loop(now) {
    if (!last) last = now;
    var dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    phase += parseFloat(rateIn.value) * dt;
    if (phase >= NOISE_STEPS) phase -= NOISE_STEPS;
    draw();
    requestAnimationFrame(loop);
  }

  sync();
  if (!reduce) requestAnimationFrame(loop);
})();
</script>
</body>
</html>
$d6$, 440)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000007', '00000000-0000-4000-8000-AB0000000001', 'lfo-amplitud', 'Modulación de amplitud', $d7$<!doctype html>
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
$d7$, 420)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000008', '00000000-0000-4000-8000-AB0000000001', 'unisono-detune', 'Unísono y detune', $d8$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Unísono con detune</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .row { display: grid; grid-template-columns: 58px 1fr 66px; gap: 10px;
         align-items: center; margin-bottom: 8px; }
  .row label { font-size: 13px; color: #9A9A97; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
           text-align: right; }
  input[type=range] { accent-color: #E08E33; width: 100%; margin: 0; }
  input[type=range]:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin: 0 0 8px; }
  .audio .btn { font-family: inherit; font-size: 13px; line-height: 1; padding: 8px 10px;
                border-radius: 6px; cursor: pointer; background: #242426;
                border: 1px solid #3A3A3C; color: #EDEDEB; }
  .audio .btn[aria-pressed="true"] { background: #E08E33; border-color: #E08E33; color: #141414; }
  .audio .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
  .audio input[type=range] { width: auto; flex: 1 1 90px; min-width: 64px; }
  .audio .value { width: 38px; text-align: right; color: #8C8C8A; }
  .gate { display: block; width: 100%; margin: 2px 0 8px; padding: 7px 10px;
          font-family: inherit; font-size: 13px; font-weight: 500;
          background: #242426; border: 1px solid #3A3A3C; border-radius: 6px;
          color: #EDEDEB; cursor: pointer; touch-action: none;
          -webkit-user-select: none; user-select: none; }
  .gate.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .gate:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  canvas { display: block; width: 100%; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 5px 0 3px; }
  .caption .value { text-align: left; }
  .note { font-size: 12px; color: #8C8C8A; margin: 8px 0 0; }
</style>
</head>
<body>
  <div class="row">
    <label for="voices">Voces</label>
    <input id="voices" type="range" min="1" max="7" step="1" value="3">
    <span class="value" id="voicesOut">3</span>
  </div>
  <div class="row">
    <label for="detune">Detune</label>
    <input id="detune" type="range" min="0" max="50" step="1" value="12">
    <span class="value" id="detuneOut">12 cents</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <button class="gate" id="play" type="button" aria-pressed="false">Tocar — mantené apretado</button>

  <p class="caption" id="waveCap">Copias y suma · cámara lenta</p>
  <canvas id="wave" style="height:122px" role="img"
          aria-label="Las copias de la onda sawtooth, tenues y apenas desfasadas entre sí, y su suma resaltada: al desafinar, la suma se deforma y su amplitud late"></canvas>

  <p class="caption">Espectro · batido <span class="value" id="beat">—</span></p>
  <canvas id="spec" style="height:66px" role="img"
          aria-label="Barras de espectro alrededor de la fundamental de 220 Hz: al subir el detune, las voces se separan y la energía se ensancha"></canvas>

  <p class="note">Qué mirar: una voz suena fina; apilarla apenas desafinada la engorda y la hace latir — es el supersaw.</p>

<script>
(function () {
  var voicesEl = document.getElementById('voices');
  var detuneEl = document.getElementById('detune');
  var voicesOut = document.getElementById('voicesOut');
  var detuneOut = document.getElementById('detuneOut');
  var beatOut = document.getElementById('beat');
  var snd = document.getElementById('snd');
  var vol = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var btn = document.getElementById('play');
  var waveC = document.getElementById('wave');
  var waveCap = document.getElementById('waveCap');
  var specC = document.getElementById('spec');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ACCENT = '#E08E33', MUTED = '#8C8C8A', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var SURFACE = '#242426';
  var F0 = 220, MAXV = 7, CYCLES = 3, SLOW = 0.12, SPAN = 60;
  var WIN = CYCLES / F0;
  // arranca con las copias ya desfasadas, para no mostrar el caso coherente al entrar
  var start = performance.now() - 1500, raf = 0;

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
  // --- fin del patrón compartido ---

  var stack = null, noteGain = null, playing = false;

  function hz(c) { return F0 * Math.pow(2, c / 1200); }
  function saw(p) { p = p - Math.floor(p); return 2 * p - 1; }

  function vals() {
    var n = parseInt(voicesEl.value, 10);
    var d = parseInt(detuneEl.value, 10);
    var step = n === 1 ? 0 : (2 * d) / (n - 1);
    var cents = [], i;
    for (i = 0; i < n; i++) cents.push(n === 1 ? 0 : -d + step * i);
    return { n: n, d: d, step: step, cents: cents };
  }

  function beatHz(v) {
    if (v.step === 0) return 0;
    return Math.abs(hz(v.step / 2) - hz(-v.step / 2));
  }

  function outs(v) {
    voicesOut.textContent = String(v.n);
    detuneOut.textContent = v.d + ' cents';
    var b = beatHz(v);
    beatOut.textContent = b > 0 ? b.toFixed(1) + ' Hz' : '—';
  }

  // Nivel por voz: se normaliza por la cantidad de voces para no clipear.
  function applyAudio(v, t) {
    if (!stack) return;
    var g = 1 / Math.sqrt(v.n), i;
    for (i = 0; i < MAXV; i++) {
      var live = i < v.n;
      audio.ramp(stack[i].gain.gain, live ? g : 0, t);
      if (live) audio.ramp(stack[i].osc.detune, v.cents[i], t);
    }
  }

  function noteOff(fast) {
    if (!stack) return;
    var ctx = audio.ctx(), s = stack, ng = noteGain, i;
    stack = null; noteGain = null;
    if (!ctx) return;
    var rel = fast ? 0.006 : 0.022;
    audio.ramp(ng.gain, 0, rel);
    var stopAt = ctx.currentTime + rel + 0.03;
    for (i = 0; i < s.length; i++) { try { s[i].osc.stop(stopAt); } catch (e) {} }
    setTimeout(function () { try { ng.disconnect(); } catch (e) {} }, (rel + 0.12) * 1000);
  }

  function noteOn() {
    var ctx = audio.ctx();
    if (!ctx || !audio.on()) return;
    noteOff(true);
    noteGain = ctx.createGain();
    noteGain.gain.value = 0;
    noteGain.connect(audio.master());
    stack = [];
    for (var i = 0; i < MAXV; i++) {
      var osc = ctx.createOscillator();
      osc.type = 'sawtooth';
      osc.frequency.value = F0;
      osc.detune.value = 0;
      var g = ctx.createGain();
      g.gain.value = 0;
      osc.connect(g); g.connect(noteGain);
      osc.start();
      stack.push({ osc: osc, gain: g });
    }
    applyAudio(vals(), 0.012);
    audio.ramp(noteGain.gain, 1, 0.012);
  }

  function paintSnd(on) { snd.setAttribute('aria-pressed', on ? 'true' : 'false'); }

  function press(e) {
    if (e && e.cancelable && e.type !== 'mousedown') e.preventDefault();
    if (playing) return;
    playing = true;
    btn.classList.add('on'); btn.setAttribute('aria-pressed', 'true');
    if (!audio.on()) {
      paintSnd(audio.toggle());
      audio.setVolume(parseInt(vol.value, 10) / 100);
    } else {
      var c = audio.ctx();
      if (c && c.state === 'suspended') c.resume();
    }
    noteOn();
  }

  function letGo() {
    if (!playing) return;
    playing = false;
    btn.classList.remove('on'); btn.setAttribute('aria-pressed', 'false');
    noteOff(false);
  }

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  function drawWave(v, tv) {
    var G = setup(waveC), ctx = G.ctx, i, x;
    var mid = G.h / 2, amp = G.h / 2 - 7;
    var steps = Math.max(120, Math.round(G.w));

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(0, mid - amp + 0.5); ctx.lineTo(G.w, mid - amp + 0.5);
    ctx.moveTo(0, mid + amp + 0.5); ctx.lineTo(G.w, mid + amp + 0.5);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.beginPath(); ctx.moveTo(0, mid + 0.5); ctx.lineTo(G.w, mid + 0.5); ctx.stroke();

    var f = [], drift = [];
    for (i = 0; i < v.n; i++) {
      f.push(hz(v.cents[i]));
      drift.push((f[i] - F0) * tv);
    }

    if (v.n > 1) {
      ctx.strokeStyle = SECOND; ctx.lineWidth = 1;
      for (i = 0; i < v.n; i++) {
        ctx.beginPath();
        for (x = 0; x <= steps; x++) {
          var px = x * G.w / steps;
          var y = mid - saw(f[i] * (px / G.w) * WIN + drift[i]) * amp;
          if (x === 0) ctx.moveTo(px, y); else ctx.lineTo(px, y);
        }
        ctx.stroke();
      }
    }

    ctx.strokeStyle = ACCENT; ctx.lineWidth = 2; ctx.lineJoin = 'round';
    ctx.beginPath();
    for (x = 0; x <= steps; x++) {
      var qx = x * G.w / steps, s = 0;
      for (i = 0; i < v.n; i++) s += saw(f[i] * (qx / G.w) * WIN + drift[i]);
      var sy = mid - (s / v.n) * amp;
      if (x === 0) ctx.moveTo(qx, sy); else ctx.lineTo(qx, sy);
    }
    ctx.stroke();
  }

  function drawSpec(v) {
    var G = setup(specC), ctx = G.ctx, i;
    var pad = 16, base = G.h - 17, top = 6;
    var span = G.w - pad * 2;
    function X(c) { return pad + (c + SPAN) / (2 * SPAN) * span; }

    // la banda que ocupan las voces: se ensancha con el detune
    if (v.n > 1 && v.d > 0) {
      ctx.fillStyle = SURFACE;
      ctx.fillRect(X(-v.d), top, X(v.d) - X(-v.d), base - top);
    }

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, base + 0.5); ctx.lineTo(G.w, base + 0.5); ctx.stroke();
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(Math.round(X(0)) + 0.5, top); ctx.lineTo(Math.round(X(0)) + 0.5, base);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.strokeStyle = SECOND;
    ctx.beginPath();
    ctx.moveTo(Math.round(X(-50)) + 0.5, base); ctx.lineTo(Math.round(X(-50)) + 0.5, base + 4);
    ctx.moveTo(Math.round(X(50)) + 0.5, base); ctx.lineTo(Math.round(X(50)) + 0.5, base + 4);
    ctx.stroke();

    var h = (base - top) / Math.sqrt(v.n), bw = 7;
    ctx.fillStyle = ACCENT;
    for (i = 0; i < v.n; i++) {
      ctx.fillRect(Math.round(X(v.cents[i]) - bw / 2), base - h, bw, h);
    }

    ctx.font = '10px "JetBrains Mono", ui-monospace, monospace';
    ctx.fillStyle = MUTED; ctx.textAlign = 'center'; ctx.textBaseline = 'top';
    ctx.fillText('-50', X(-50), base + 5);
    ctx.fillText('220 Hz', X(0), base + 5);
    ctx.fillText('+50', X(50), base + 5);
  }

  function render() {
    var v = vals();
    outs(v);
    var tv;
    if (reduce) {
      var b = beatHz(v);
      tv = b > 0 ? 0.25 / b : 0;
    } else {
      tv = (performance.now() - start) / 1000 * SLOW;
    }
    drawWave(v, tv);
    drawSpec(v);
  }

  function loop() {
    raf = requestAnimationFrame(loop);
    render();
  }

  function onControl() {
    var v = vals();
    outs(v);
    applyAudio(v, 0.02);
    if (reduce) render();
  }

  voicesEl.addEventListener('input', onControl);
  detuneEl.addEventListener('input', onControl);
  window.addEventListener('resize', render);

  vol.addEventListener('input', function () {
    var p = parseInt(vol.value, 10);
    volOut.textContent = p + '%';
    audio.setVolume(p / 100);
  });

  snd.addEventListener('click', function () {
    var on = audio.toggle();
    paintSnd(on);
    if (!on) { letGo(); return; }
    audio.setVolume(parseInt(vol.value, 10) / 100);
    if (playing) noteOn();
  });

  btn.addEventListener('mousedown', press);
  btn.addEventListener('touchstart', press, { passive: false });
  btn.addEventListener('mouseup', letGo);
  btn.addEventListener('mouseleave', letGo);
  btn.addEventListener('touchend', letGo);
  btn.addEventListener('touchcancel', letGo);
  btn.addEventListener('blur', letGo);
  btn.addEventListener('keydown', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') {
      if (e.repeat) { e.preventDefault(); return; }
      press(e);
    }
  });
  btn.addEventListener('keyup', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') letGo();
  });
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) letGo();
  });

  if (reduce) waveCap.textContent = 'Copias y suma';
  render();
  if (!reduce) raf = requestAnimationFrame(loop);
})();
</script>
</body>
</html>
$d8$, 480)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000009', '00000000-0000-4000-8000-AB0000000001', 'envolvente-loop', 'Loops de envolvente', $d9$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Modos de loop de la envolvente</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  .modes { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-bottom: 9px; }
  .modes .label { font-size: 13px; color: #9A9A97; margin-right: 2px; }
  .sep { width: 1px; height: 18px; background: #2C2C2E; margin: 0 3px; }
  .btn { font-family: inherit; font-size: 12px; font-weight: 500; padding: 5px 9px;
         background: #242426; border: 1px solid #3A3A3C; border-radius: 6px;
         color: #EDEDEB; cursor: pointer; }
  .btn.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .btn[disabled] { color: #48484A; border-color: #2C2C2E; background: #1B1B1D; cursor: default; }
  .row { display: grid; grid-template-columns: 64px 1fr 62px; gap: 10px;
         align-items: center; margin-bottom: 6px; }
  .row label { font-size: 13px; color: #9A9A97; }
  .value { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
           text-align: right; }
  input[type=range] { accent-color: #E08E33; width: 100%; margin: 0; }
  input[type=range]:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  .audio { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin: 9px 0 8px; }
  .audio .label { font-size: 12px; color: #8C8C8A; }
  .audio input[type=range] { width: auto; flex: 1 1 70px; min-width: 60px; }
  .audio .value { width: 38px; text-align: right; color: #8C8C8A; }
  .gate { display: block; width: 100%; margin: 0 0 9px; padding: 7px 10px;
          font-family: inherit; font-size: 13px; font-weight: 500;
          background: #242426; border: 1px solid #3A3A3C; border-radius: 6px;
          color: #EDEDEB; cursor: pointer; touch-action: none;
          -webkit-user-select: none; user-select: none; }
  .gate.on { background: #E08E33; border-color: #E08E33; color: #141414; }
  .gate:focus-visible { outline: 2px solid #E08E33; outline-offset: 3px; }
  canvas { display: block; width: 100%; }
  .status { margin: 7px 0 0; font-size: 12px; color: #9A9A97; }
  .status .value { text-align: left; }
  .caption { font-size: 12px; color: #8C8C8A; margin: 5px 0 0; }
</style>
</head>
<body>
  <div class="modes" role="group" aria-label="Modo de loop de la envolvente">
    <span class="label">Modo</span>
    <button class="btn" type="button" data-mode="off" aria-pressed="false">Off</button>
    <button class="btn on" type="button" data-mode="ad-r" aria-pressed="true">AD-R</button>
    <button class="btn" type="button" data-mode="adr-r" aria-pressed="false">ADR-R</button>
    <button class="btn" type="button" data-mode="ads-ar" aria-pressed="false">ADS-AR</button>
    <span class="sep" aria-hidden="true"></span>
    <button class="btn" type="button" id="free" aria-pressed="false">Free</button>
  </div>

  <div class="row">
    <label for="attack">Attack</label>
    <input id="attack" type="range" min="0" max="2000" step="10" value="120">
    <span class="value" id="attackOut">120 ms</span>
  </div>
  <div class="row">
    <label for="decay">Decay</label>
    <input id="decay" type="range" min="0" max="2000" step="10" value="300">
    <span class="value" id="decayOut">300 ms</span>
  </div>
  <div class="row">
    <label for="sustain">Sustain</label>
    <input id="sustain" type="range" min="0" max="100" step="1" value="60">
    <span class="value" id="sustainOut">60%</span>
  </div>
  <div class="row">
    <label for="release">Release</label>
    <input id="release" type="range" min="0" max="3000" step="10" value="500">
    <span class="value" id="releaseOut">500 ms</span>
  </div>

  <div class="audio">
    <button id="snd" type="button" class="btn" aria-pressed="false">Sonido</button>
    <label for="vol" class="label">Volumen</label>
    <input id="vol" type="range" min="0" max="100" step="1" value="15">
    <span class="value" id="volOut">15%</span>
  </div>

  <button class="gate" id="gate" type="button" aria-pressed="false">Tocar nota — mantené apretado</button>

  <canvas id="env" style="height:106px" role="img"
          aria-label="Envolvente a lo largo del tiempo: la zona sombreada es la tecla apretada y la bolita recorre la curva. En los modos AD-R y ADR-R el segmento se repite en bucle mientras sostenés; en ADS-AR la envolvente suena una vez y vuelve a disparar attack y release al final de la nota"></canvas>

  <p class="status">etapa <span class="value" id="stage">silencio</span></p>
  <p class="caption">Qué mirar: los loops meten movimiento rítmico dentro de una sola nota sostenida.</p>

<script>
(function () {
  var attack = document.getElementById('attack');
  var decay = document.getElementById('decay');
  var sustain = document.getElementById('sustain');
  var release = document.getElementById('release');
  var attackOut = document.getElementById('attackOut');
  var decayOut = document.getElementById('decayOut');
  var sustainOut = document.getElementById('sustainOut');
  var releaseOut = document.getElementById('releaseOut');
  var freeBtn = document.getElementById('free');
  var snd = document.getElementById('snd');
  var vol = document.getElementById('vol');
  var volOut = document.getElementById('volOut');
  var btn = document.getElementById('gate');
  var stageOut = document.getElementById('stage');
  var cv = document.getElementById('env');
  var modeBtns = [].slice.call(document.querySelectorAll('[data-mode]'));
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

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

  var ACCENT = '#E08E33', MUTED = '#8C8C8A', AXIS = '#2C2C2E', SECOND = '#5A5A5C';
  var BG = '#1B1B1D', SHADE = 'rgba(90, 90, 92, 0.16)', TAIL = 'rgba(90, 90, 92, 0.07)';
  var MAXHOLD = 10000, HORIZON = 13000, MINR = 0.006, FREQ = 220;
  var mode = 'ad-r', freeOn = false;
  var play = 'idle', pressT = 0, gateLen = 0, raf = 0, holdTimer = 0, tailTimer = 0;
  var note = null;

  function now() { return performance.now(); }
  function loops(m) { return m === 'ad-r' || m === 'adr-r'; }

  function vals() {
    return { a: parseInt(attack.value, 10), d: parseInt(decay.value, 10),
             s: parseInt(sustain.value, 10) / 100, r: parseInt(release.value, 10) };
  }

  function outs(v) {
    attackOut.textContent = v.a + ' ms';
    decayOut.textContent = v.d + ' ms';
    sustainOut.textContent = Math.round(v.s * 100) + '%';
    releaseOut.textContent = v.r + ' ms';
  }

  function cyc(v, m) { return v.a + v.d + (m === 'adr-r' ? v.r : 0); }

  function nominal(v, m) {
    if (!loops(m)) return v.a + v.d + 700;
    var cd = cyc(v, m);
    if (cd < 1) return 700;
    var n = Math.round(2400 / cd);
    if (n < 3) n = 3;
    if (n > 8) n = 8;
    while (n > 2 && cd * n > 9000) n--;
    return cd * n;
  }

  function freeTail(v, m) {
    var x = cyc(v, m) * 2;
    if (x < 500) x = 500;
    if (x > 2200) x = 2200;
    return x;
  }

  // Construye la envolvente como lista de tramos exactos: mientras dura el
  // gate repite el segmento del modo, y después entra la fase de release.
  function build(v, m, fr, gate) {
    var segs = [], t = 0, lvl = 0, full = false;
    var limit = Math.max(1, gate + (fr && loops(m) ? freeTail(v, m) : 0));

    function seg(st, dur, to, c) {
      if (full) return;
      if (!(dur > 0)) dur = 0;
      if (t + dur > limit) {
        var k = dur > 0 ? (limit - t) / dur : 1;
        var end = lvl + (to - lvl) * k;
        segs.push({ st: st, t0: t, t1: limit, l0: lvl, l1: end, c: c });
        lvl = end; t = limit; full = true;
        return;
      }
      segs.push({ st: st, t0: t, t1: t + dur, l0: lvl, l1: to, c: c });
      t += dur; lvl = to;
    }

    if (loops(m)) {
      var cd = cyc(v, m);
      if (cd < 1) {
        seg('attack', v.a, 1, 1);
        seg('decay', v.d, v.s, 1);
        if (m === 'adr-r') seg('release', v.r, 0, 1);
        seg('sustain', limit - t, lvl, 1);
      } else {
        var n = 0;
        while (!full && n < 600) {
          n++;
          seg('attack', v.a, 1, n);
          seg('decay', v.d, v.s, n);
          if (m === 'adr-r') seg('release', v.r, 0, n);
        }
      }
    } else {
      seg('attack', v.a, 1, 0);
      seg('decay', v.d, v.s, 0);
      seg('sustain', limit - t, v.s, 0);
    }

    var holdEnd = t;
    limit = Infinity; full = false;
    if (m === 'ads-ar') { seg('attack', v.a, 1, 0); seg('release', v.r, 0, 0); }
    else seg('release', v.r, 0, 0);

    return { segs: segs, holdEnd: holdEnd, total: t };
  }

  function at(env, t) {
    var segs = env.segs, i, g;
    if (t <= 0) return { l: 0, st: 'silencio', c: 0 };
    for (i = 0; i < segs.length; i++) {
      g = segs[i];
      if (t <= g.t1) {
        var k = g.t1 > g.t0 ? (t - g.t0) / (g.t1 - g.t0) : 1;
        return { l: g.l0 + (g.l1 - g.l0) * k, st: g.st, c: g.c };
      }
    }
    return { l: 0, st: 'silencio', c: 0 };
  }

  function descr(m, fr) {
    var s = m === 'off' ? 'sin loop · A D S R'
      : m === 'ad-r' ? 'loop de A y D · release al soltar'
      : m === 'adr-r' ? 'loop de A D R · release al soltar'
      : 'sin loop · A y R extra al final';
    return fr && loops(m) ? s + ' · free' : s;
  }

  function setup(c) {
    var dpr = window.devicePixelRatio || 1;
    var r = c.getBoundingClientRect();
    var w = Math.round(r.width * dpr), h = Math.round(r.height * dpr);
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    var ctx = c.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, r.width, r.height);
    return { ctx: ctx, w: r.width, h: r.height };
  }

  var LETTER = { attack: 'A', decay: 'D', sustain: 'S', release: 'R' };

  function draw(v, env, gate, t) {
    var G = setup(cv), ctx = G.ctx, i, g;
    var padL = 10, padR = 10, top = 14, base = G.h - 22;
    var total = env.total > 0 ? env.total : 1;
    var span = G.w - padL - padR;
    function X(tt) { return padL + (tt / total) * span; }
    function Y(l) { return base - l * (base - top); }

    var gx = X(Math.min(gate, total));
    ctx.fillStyle = SHADE;
    ctx.fillRect(X(0), top, gx - X(0), base - top);
    if (env.holdEnd > gate + 1) {
      ctx.fillStyle = TAIL;
      ctx.fillRect(gx, top, X(env.holdEnd) - gx, base - top);
    }

    ctx.strokeStyle = AXIS; ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, base + 0.5); ctx.lineTo(G.w - padR, base + 0.5);
    ctx.moveTo(padL + 0.5, top); ctx.lineTo(padL + 0.5, base);
    ctx.stroke();

    var ys = Y(v.s);
    ctx.strokeStyle = SECOND; ctx.setLineDash([3, 4]);
    ctx.beginPath(); ctx.moveTo(padL, ys + 0.5); ctx.lineTo(G.w - padR, ys + 0.5); ctx.stroke();

    var cd = cyc(v, mode);
    if (loops(mode) && cd >= 1 && (X(cd) - X(0)) >= 18) {
      ctx.strokeStyle = AXIS;
      ctx.beginPath();
      for (i = 0; i < env.segs.length; i++) {
        g = env.segs[i];
        if (g.st !== 'attack' || g.t0 <= 0 || g.t0 >= env.holdEnd) continue;
        ctx.moveTo(X(g.t0) + 0.5, top); ctx.lineTo(X(g.t0) + 0.5, base);
      }
      ctx.stroke();
    }
    if (env.holdEnd > gate + 1) {
      ctx.strokeStyle = SECOND;
      ctx.beginPath(); ctx.moveTo(gx + 0.5, top); ctx.lineTo(gx + 0.5, base); ctx.stroke();
    }
    ctx.setLineDash([]);

    ctx.font = '11px "JetBrains Mono", ui-monospace, monospace';
    ctx.textAlign = 'right'; ctx.textBaseline = 'alphabetic';
    var txt = Math.round(v.s * 100) + '%';
    var tw = ctx.measureText(txt).width;
    var tx = G.w - padR, ty = Math.max(top + 9, ys - 4);
    ctx.fillStyle = BG; ctx.fillRect(tx - tw - 3, ty - 10, tw + 5, 13);
    ctx.fillStyle = MUTED; ctx.fillText(txt, tx, ty);

    ctx.strokeStyle = ACCENT; ctx.lineWidth = 2;
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(X(0), Y(0));
    for (i = 0; i < env.segs.length; i++) {
      g = env.segs[i];
      ctx.lineTo(X(g.t1), Y(g.l1));
    }
    ctx.stroke();

    ctx.font = '12px "Space Grotesk", system-ui, sans-serif';
    ctx.textAlign = 'center'; ctx.fillStyle = MUTED;
    for (i = 0; i < env.segs.length; i++) {
      g = env.segs[i];
      if (X(g.t1) - X(g.t0) >= 13) {
        ctx.fillText(LETTER[g.st] || '', (X(g.t0) + X(g.t1)) / 2, G.h - 6);
      }
    }

    if (t !== null) {
      var bt = Math.min(t, total);
      ctx.fillStyle = ACCENT;
      ctx.beginPath(); ctx.arc(X(bt), Y(at(env, bt).l), 4.5, 0, Math.PI * 2); ctx.fill();
    }
  }

  function setStage(s) { if (stageOut.textContent !== s) stageOut.textContent = s; }

  function render() {
    var v = vals(); outs(v);
    var fr = freeOn && loops(mode);
    var t = null, gate = 0, env = null;

    if (!reduce && play !== 'idle') {
      t = now() - pressT;
      gate = play === 'held' ? Math.max(t, nominal(v, mode)) : gateLen;
      env = build(v, mode, fr && play === 'rel', gate);
      if (play === 'rel' && t >= env.total) { play = 'idle'; t = null; }
    }
    if (t === null) {
      gate = nominal(v, mode);
      env = build(v, mode, fr, gate);
    }

    if (t === null) {
      setStage(reduce ? descr(mode, freeOn) : 'silencio');
    } else {
      var r = at(env, t);
      var lbl = r.st;
      if (r.c) lbl += ' · ciclo ' + r.c;
      if (play === 'rel' && t < env.holdEnd) lbl = 'free · ' + lbl;
      setStage(lbl);
    }
    draw(v, env, gate, t);
  }

  function loop() {
    raf = 0;
    render();
    if (play !== 'idle') raf = requestAnimationFrame(loop);
  }

  // --- audio: el gain del tono sigue los mismos tramos que se dibujan ---
  function endNote(n, when) {
    try { n.osc.stop(when); } catch (e) {}
    n.osc.onended = function () {
      try { n.osc.disconnect(); n.gain.disconnect(); } catch (e) {}
    };
  }

  function cutNote() {
    if (!note) return;
    var ctx = audio.ctx();
    if (ctx) {
      var p = note.gain.gain, t = ctx.currentTime;
      p.cancelScheduledValues(t);
      p.setValueAtTime(p.value, t);
      p.linearRampToValueAtTime(0, t + 0.01);
      endNote(note, t + 0.05);
    }
    note = null;
  }

  function startNote() {
    cutNote();
    if (!audio.on()) return;
    var ctx = audio.ctx();
    if (!ctx) return;
    var v = vals(), env = build(v, mode, false, HORIZON);
    var t0 = ctx.currentTime + 0.01;
    var osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(FREQ, t0);
    var g = ctx.createGain();
    var p = g.gain;
    p.setValueAtTime(0, t0);
    var prev = t0, i, sg, te;
    for (i = 0; i < env.segs.length && i < 1400; i++) {
      sg = env.segs[i];
      if (sg.t0 >= env.holdEnd) break;
      te = t0 + sg.t1 / 1000;
      if (te < prev + MINR) te = prev + MINR;
      p.linearRampToValueAtTime(sg.l1, te);
      prev = te;
    }
    osc.connect(g); g.connect(audio.master());
    osc.start(t0);
    note = { osc: osc, gain: g };
  }

  function releaseNote() {
    if (!note) return;
    var ctx = audio.ctx();
    if (!ctx) { cutNote(); return; }
    var v = vals(), p = note.gain.gain, t = ctx.currentTime, end;
    p.cancelScheduledValues(t);
    p.setValueAtTime(p.value, t);
    if (mode === 'ads-ar') {
      var ta = t + Math.max(v.a / 1000, MINR);
      p.linearRampToValueAtTime(1, ta);
      end = ta + Math.max(v.r / 1000, MINR);
    } else {
      end = t + Math.max(v.r / 1000, MINR);
    }
    p.linearRampToValueAtTime(0, end);
    endNote(note, end + 0.03);
    note = null;
  }

  function clearTimers() {
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = 0; }
    if (tailTimer) { clearTimeout(tailTimer); tailTimer = 0; }
  }

  function press(e) {
    if (e && e.cancelable && e.type !== 'mousedown') e.preventDefault();
    if (play === 'held') return;
    clearTimers();
    play = 'held'; pressT = now();
    btn.classList.add('on'); btn.setAttribute('aria-pressed', 'true');
    startNote();
    holdTimer = setTimeout(function () { holdTimer = 0; letGo(); }, MAXHOLD);
    if (reduce) render();
    else if (!raf) raf = requestAnimationFrame(loop);
  }

  function letGo() {
    if (play !== 'held') return;
    btn.classList.remove('on'); btn.setAttribute('aria-pressed', 'false');
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = 0; }
    var v = vals();
    if (freeOn && loops(mode)) {
      tailTimer = setTimeout(function () { tailTimer = 0; releaseNote(); }, freeTail(v, mode));
    } else {
      releaseNote();
    }
    if (reduce) { play = 'idle'; render(); return; }
    gateLen = now() - pressT; play = 'rel';
    if (!raf) raf = requestAnimationFrame(loop);
  }

  function stopAll() {
    clearTimers();
    cutNote();
    play = 'idle';
    btn.classList.remove('on'); btn.setAttribute('aria-pressed', 'false');
  }

  function setMode(m) {
    mode = m;
    modeBtns.forEach(function (b) {
      var on = b.getAttribute('data-mode') === m;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    freeBtn.disabled = !loops(m);
    if (freeBtn.disabled && freeOn) {
      freeOn = false;
      freeBtn.classList.remove('on');
      freeBtn.setAttribute('aria-pressed', 'false');
    }
    stopAll();
    render();
  }

  modeBtns.forEach(function (b) {
    b.addEventListener('click', function () { setMode(b.getAttribute('data-mode')); });
  });

  freeBtn.addEventListener('click', function () {
    if (freeBtn.disabled) return;
    freeOn = !freeOn;
    freeBtn.classList.toggle('on', freeOn);
    freeBtn.setAttribute('aria-pressed', freeOn ? 'true' : 'false');
    stopAll();
    render();
  });

  snd.addEventListener('click', function () {
    var on = audio.toggle();
    snd.classList.toggle('on', on);
    snd.setAttribute('aria-pressed', on ? 'true' : 'false');
    if (on) audio.setVolume(parseInt(vol.value, 10) / 100); else cutNote();
  });

  vol.addEventListener('input', function () {
    volOut.textContent = vol.value + '%';
    audio.setVolume(parseInt(vol.value, 10) / 100);
  });

  btn.addEventListener('mousedown', press);
  btn.addEventListener('touchstart', press, { passive: false });
  btn.addEventListener('mouseup', letGo);
  btn.addEventListener('mouseleave', letGo);
  btn.addEventListener('touchend', letGo);
  btn.addEventListener('touchcancel', letGo);
  btn.addEventListener('blur', letGo);
  btn.addEventListener('keydown', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') {
      if (e.repeat) { e.preventDefault(); return; }
      press(e);
    }
  });
  btn.addEventListener('keyup', function (e) {
    if (e.key === ' ' || e.key === 'Spacebar' || e.key === 'Enter') letGo();
  });

  [attack, decay, sustain, release].forEach(function (el) {
    el.addEventListener('input', function () { if (play === 'idle' || reduce) render(); });
  });
  window.addEventListener('resize', function () { if (play === 'idle' || reduce) render(); });
  document.addEventListener('visibilitychange', function () { if (document.hidden) stopAll(); });

  setMode(mode);
})();
</script>
</body>
</html>
$d9$, 500)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;
INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('00000000-0000-4000-8000-AB0300000010', '00000000-0000-4000-8000-AB0000000001', 'cuestionario-analog-2', 'Autoevaluación · Analog 2', $d10$<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Autoevaluación · Analog II</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 12px; background: #1B1B1D; color: #EDEDEB;
         font-family: 'Space Grotesk', system-ui, sans-serif; }
  [hidden] { display: none !important; }
  .step { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
          color: #8C8C8A; margin: 0 0 8px; }
  .q { font-size: 15px; font-weight: 500; line-height: 1.3; margin: 0 0 10px; outline: none; }
  .opt { display: block; width: 100%; min-height: 44px; margin: 0 0 6px; padding: 8px 12px;
         text-align: left; background: #242426; border: 0.5px solid #3A3A3C; border-radius: 8px;
         color: #EDEDEB; font: 400 14px/1.3 'Space Grotesk', system-ui, sans-serif;
         cursor: pointer; transition: border-color .12s linear; }
  .opt:hover:enabled { border-color: #5A5A5C; }
  .opt:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .opt:disabled { cursor: default; color: #8C8C8A; border-color: #2C2C2E; }
  .opt.ok { border-color: #E08E33; color: #E08E33; }
  .opt.bad { border-color: #7A3B34; color: #E2695C; }
  .fb { font-size: 13px; line-height: 1.35; color: #9A9A97; margin: 10px 0 0; min-height: 52px; }
  .fb b { font-weight: 500; }
  .fb .ok { color: #E08E33; }
  .fb .bad { color: #E2695C; }
  .btn { min-height: 36px; padding: 8px 16px; border: none; border-radius: 8px;
         background: #E08E33; color: #141414;
         font: 500 14px 'Space Grotesk', system-ui, sans-serif; cursor: pointer; }
  .btn:focus-visible { outline: 2px solid #E08E33; outline-offset: 2px; }
  .end { padding: 36px 0 0; }
  .score { font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 34px;
           color: #E08E33; margin: 0; outline: none; }
  .score span { color: #8C8C8A; }
  .close { font-size: 13px; color: #9A9A97; margin: 8px 0 16px; }
  @media (prefers-reduced-motion: reduce) { .opt { transition: none; } }
</style>
</head>
<body>
  <div id="quiz">
    <p class="step" id="step">pregunta 01 / 04</p>
    <h1 class="q" id="question" tabindex="-1"></h1>
    <div id="options"></div>
    <p class="fb" id="feedback" role="status" aria-live="polite"></p>
    <button class="btn" id="next" hidden>Siguiente</button>
  </div>

  <div class="end" id="end" hidden>
    <p class="score" id="score" tabindex="-1"></p>
    <p class="close" id="close"></p>
    <button class="btn" id="retry">Reintentar</button>
  </div>

<script>
(function () {
  var Q = [
    { q: 'En modo polifónico, cuando se agotan las voces disponibles y tocás una nota más, ¿qué hace el sintetizador?',
      o: ['La ignora', 'Apaga la voz más vieja (note stealing)',
          'Corta todas', 'Sube la CPU sin límite'], c: 1,
      e: 'Libera la voz más antigua para dar lugar a la nueva.' },
    { q: 'Al subir el Ratio del Oscillator Sync, ¿qué cambia en el sonido?',
      o: ['La altura de la nota', 'El contenido armónico / timbre',
          'El volumen', 'La afinación general'], c: 1,
      e: 'Sync reinicia la fase y suma armónicos sin cambiar la altura.' },
    { q: '¿Para qué sirve el efecto Unison con Detune?',
      o: ['Bajar una octava', 'Apilar voces desafinadas para engordar',
          'Filtrar agudos', 'Sincronizar al tempo'], c: 1,
      e: 'Es la base de los sonidos anchos tipo supersaw.' },
    { q: 'En el modo de loop de envolvente AD-R, las fases de attack y decay…',
      o: ['Se reproducen una sola vez', 'Se repiten hasta que soltás la nota',
          'Se saltean', 'Se invierten'], c: 1,
      e: 'Loopean mientras sostenés; al soltar entra el release.' }
  ];

  var CIERRE = [
    'Conviene volver al video antes de seguir.',
    'Conviene volver al video antes de seguir.',
    'Vas por la mitad: repasá los puntos que fallaste.',
    'Casi todo claro. Repasá el que se te escapó.',
    'Los cuatro conceptos quedaron firmes.'
  ];

  var step = document.getElementById('step');
  var question = document.getElementById('question');
  var options = document.getElementById('options');
  var feedback = document.getElementById('feedback');
  var next = document.getElementById('next');
  var quiz = document.getElementById('quiz');
  var end = document.getElementById('end');
  var score = document.getElementById('score');
  var close = document.getElementById('close');
  var retry = document.getElementById('retry');

  var idx = 0, hits = 0, buttons = [];

  function pad(n) { return (n < 10 ? '0' : '') + n; }

  function render(focus) {
    var item = Q[idx];
    step.textContent = 'pregunta ' + pad(idx + 1) + ' / ' + pad(Q.length);
    question.textContent = item.q;
    feedback.textContent = '';
    next.hidden = true;
    next.textContent = idx === Q.length - 1 ? 'Ver resultado' : 'Siguiente';
    options.textContent = '';
    buttons = item.o.map(function (text, i) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'opt';
      b.textContent = text;
      b.addEventListener('click', function () { answer(i); });
      options.appendChild(b);
      return b;
    });
    if (focus) question.focus();
  }

  function answer(i) {
    var item = Q[idx], ok = i === item.c;
    if (ok) hits++;
    buttons.forEach(function (b, j) {
      b.disabled = true;
      if (j === item.c) b.className = 'opt ok';
      if (j === i && !ok) b.className = 'opt bad';
    });
    var tag = document.createElement('b');
    tag.className = ok ? 'ok' : 'bad';
    tag.textContent = ok ? 'Correcto.' : 'Incorrecto.';
    feedback.textContent = '';
    feedback.appendChild(tag);
    var previa = ok ? ' ' : ' La correcta era «' + item.o[item.c] + '». ';
    feedback.appendChild(document.createTextNode(previa + item.e));
    next.hidden = false;
    next.focus();
  }

  function finish() {
    quiz.hidden = true;
    end.hidden = false;
    score.textContent = '';
    score.appendChild(document.createTextNode(String(hits)));
    var rest = document.createElement('span');
    rest.textContent = ' / ' + Q.length;
    score.appendChild(rest);
    score.setAttribute('aria-label', 'Resultado: ' + hits + ' de ' + Q.length + ' correctas');
    close.textContent = CIERRE[hits];
    score.focus();
  }

  next.addEventListener('click', function () {
    if (idx === Q.length - 1) finish();
    else { idx++; render(true); }
  });

  retry.addEventListener('click', function () {
    idx = 0; hits = 0;
    end.hidden = true;
    quiz.hidden = false;
    render(true);
  });

  render(false);
})();
</script>
</body>
</html>
$d10$, 460)
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;

-- Módulos: uno por unidad. Los que todavía no tienen lecciones
-- marcan el plan (un módulo vacío no se publica).
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000001', '00000000-0000-4000-8000-AB0000000001', 'Analog 1: Monofonía', 1) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000002', '00000000-0000-4000-8000-AB0000000001', 'Analog 2: Polifonía', 2) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000003', '00000000-0000-4000-8000-AB0000000001', 'Introducción a plug-ins VST', 3) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000004', '00000000-0000-4000-8000-AB0000000001', 'Instrument Racks', 4) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000005', '00000000-0000-4000-8000-AB0000000001', 'MIDI: configuración, mapeo y grabación', 5) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000006', '00000000-0000-4000-8000-AB0000000001', 'MIDI: creatividad y grabación', 6) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000007', '00000000-0000-4000-8000-AB0000000001', 'Práctica guiada', 7) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000008', '00000000-0000-4000-8000-AB0000000001', 'Trabajo práctico 1', 8) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000009', '00000000-0000-4000-8000-AB0000000001', 'Armado de plantillas', 9) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000010', '00000000-0000-4000-8000-AB0000000001', 'Arrangement: recursos creativos', 10) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000011', '00000000-0000-4000-8000-AB0000000001', 'Espacialidad: Echo & Convolution Reverb', 11) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000012', '00000000-0000-4000-8000-AB0000000001', 'EQ Eight & introducción a la compresión', 12) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000013', '00000000-0000-4000-8000-AB0000000001', 'Glue Compressor & Drum Buss', 13) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000014', '00000000-0000-4000-8000-AB0000000001', 'Práctica de ecualización y compresión', 14) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000015', '00000000-0000-4000-8000-AB0000000001', 'BONUS: recursos creativos en la mezcla', 15) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
INSERT INTO modules (id, course_id, title, position) VALUES ('00000000-0000-4000-8000-AB0100000016', '00000000-0000-4000-8000-AB0000000001', 'Trabajo práctico final', 16) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

-- Módulo 1 · Analog 1: Monofonía (8 lecciones).
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000001', '00000000-0000-4000-8000-AB0100000001', 'Video 1', 'Presentación del módulo.', 1200, true, 1, 'video', $b11$$b11$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000002', '00000000-0000-4000-8000-AB0100000001', 'Introducción a la Síntesis y Forma de Onda', 'Oscilador, formas de onda y espectro de armónicos, con una demo para escuchar con los ojos.', 214, true, 2, 'article', $b12$## Qué es sintetizar

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
$b12$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000003', '00000000-0000-4000-8000-AB0100000001', 'Analog 1', 'El sintetizador de Ableton por dentro: envolvente ADSR, pitch y sub-oscilador.', 203, false, 3, 'article', $b13$## El instrumento Analog

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
$b13$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000004', '00000000-0000-4000-8000-AB0100000001', 'Video 2', 'Analog en Live, paso a paso.', 2700, false, 4, 'video', $b14$$b14$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000005', '00000000-0000-4000-8000-AB0100000001', 'Video 3', 'Diseño de sonido sobre el proyecto de clase.', 1920, false, 5, 'video', $b15$$b15$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000006', '00000000-0000-4000-8000-AB0100000001', 'Ejercicio - Analog 1', 'Diseñá un bajo y un lead desde cero, sin presets.', 46, false, 6, 'article', $b16$## Ejercicio: diseñá un bajo y un lead desde cero

Abrí una pista MIDI con Analog y trabajá sin presets. La idea es aplicar
todo lo del módulo: forma de onda, ADSR y sub.

**1. Un bajo.**
- Oscilador en **sawtooth** (espectro rico para filtrar después).
- ADSR: **attack casi en cero**, decay corto, **sustain medio-bajo**,
  release corto. Un bajo tiene que arrancar seco y no colgarse.
- Activá el **sub** una octava abajo para darle peso.
- Tocá una línea grave y ajustá hasta que "pegue" en el pecho sin
  embarrarse.

**2. Un lead.**
- Oscilador en **square** o **sawtooth**.
- ADSR: attack corto pero perceptible, **sustain alto**, release un poco
  más largo para que las notas respiren.
- Subí una octava respecto del bajo y probá una melodía simple.

**Para entregar:** una captura del Analog con tus dos configuraciones y una
línea explicando por qué elegiste cada valor de la envolvente.
$b16$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000007', '00000000-0000-4000-8000-AB0100000001', 'Proyecto de Clase | Consigna', 'Diseñá los Analog de los canales 11 y 12 del proyecto.', 34, false, 7, 'article', $b17$## Proyecto de clase

[Descargar el proyecto de Ableton](/uploads/2026/09/99d23eb67c3c39b4e8e35d70b9b7c5f8.zip) (18 MB, .zip)

Trabajá sobre las **escenas marcadas en
amarillo**: ya tienen una base rítmica y clips de audio armados.

Los **clips MIDI ya están escritos**, pero los Analog de los **canales 11 y
12 todavía no fueron diseñados**. Tu objetivo es conseguir:

- un **sonido de bajo** (canal 11),
- un **sonido de lead** (canal 12),

que se amolden musicalmente con lo que ya está sonando. Usá lo del ejercicio:
forma de onda, ADSR y sub. No hace falta que sea complejo, sí que **encaje**.

**Entrega:** el proyecto con los dos Analog diseñados y una nota breve
contando qué decisiones tomaste.
$b17$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000008', '00000000-0000-4000-8000-AB0100000001', 'Cuestionario - Analog 1', 'Cuatro preguntas para chequear lo del módulo.', 73, false, 8, 'article', $b18$## Autoevaluación

Cuatro preguntas para chequear lo del módulo: formas de onda, envolvente y
sub-oscilador. El resultado no se guarda en ningún lado, es para vos.

::demo[cuestionario-analog-1]

Si algo no te cerró, volvé a la lección correspondiente antes de seguir con
Analog 2.
$b18$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;

-- Módulo 2 · Analog 2: Polifonía (7 lecciones).
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000001', '00000000-0000-4000-8000-AB0100000002', 'Video 1', 'Presentación del módulo.', 1200, false, 1, 'video', $b21$$b21$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000002', '00000000-0000-4000-8000-AB0100000002', 'Polifonía y osciladores en capas', 'Voces, note stealing, suma de osciladores y oscillator sync.', 224, false, 2, 'article', $b22$## De una voz a varias

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
$b22$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000003', '00000000-0000-4000-8000-AB0100000002', 'Modulación: LFO, AM y vibrato', 'El LFO de Analog, la modulación de amplitud y el vibrato.', 248, false, 3, 'article', $b23$## El LFO de Analog

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
$b23$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000004', '00000000-0000-4000-8000-AB0100000002', 'Cuerpo y voces: unísono, ruteo y envolventes', 'Unison con detune, los cuatro ruteos rápidos y los loops de envolvente.', 232, false, 4, 'article', $b24$## Global y volumen

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
$b24$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000005', '00000000-0000-4000-8000-AB0100000002', 'Ejercicio - Analog 2', 'Diseñá un pad polifónico ancho desde cero.', 54, false, 5, 'article', $b25$## Ejercicio: diseñá un pad polifónico ancho

Poné Analog en una pista MIDI, en modo **poli**, y diseñá un pad desde cero
aplicando lo del módulo.

**1. Base con dos osciladores.**
- OSC 1 en **sawtooth**, OSC 2 en **sawtooth** o **square**, sumados de forma
  aditiva (acordate de activar el Amp del segundo).
- Pasalos por el filtro con un pasa-bajos y dejá algo de brillo.

**2. Cuerpo con unísono.**
- Activá **Uni** y subí las voces; agregá **Detune** hasta que el pad se
  sienta ancho, sin que se desafine feo.

**3. Movimiento con el LFO.**
- Asigná un **LFO lento** (en modo sync, ej. 1/2 o 1/1) a la **frecuencia de
  corte** con un poco de Freq Mod, para que el pad respire.

**4. Envolvente de pad.**
- Attack **medio-largo**, sustain **alto**, release **largo**. Un pad tiene
  que entrar suave y colgarse al soltar.

Tocá un acorde sostenido y ajustá hasta que suene grande y estable.

**Para entregar:** captura del Analog con tu patch y una línea explicando qué
hiciste con unísono y con el LFO.
$b25$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000006', '00000000-0000-4000-8000-AB0100000002', 'Proyecto de Clase | Polifonía', 'Diseñá los Analog de los canales 14 y 15.', 44, false, 6, 'article', $b26$## Proyecto de clase

Descargá el proyecto y trabajá sobre las **escenas marcadas en amarillo**,
que ya tienen una base rítmica armada. Los **clips MIDI ya están escritos**,
pero los instrumentos Analog de los **canales 14 y 15 todavía no fueron
diseñados**.

Tu objetivo es conseguir:

- un **sonido de bajo** (canal 14),
- un **sonido de pad / stab** (canal 15),

que se amolden musicalmente con lo que ya está escrito. Aplicá lo del módulo:
suma de osciladores, unísono para el pad, y una envolvente adecuada a cada rol
(el bajo directo, el pad con cuerpo).

**Entrega:** el proyecto con los dos Analog diseñados y una nota breve con tus
decisiones.

<!-- PENDIENTE: adjuntar "P302 - ANALOG II - Polifonía Project.zip" (4 MB).
     Subilo desde el admin con "Adjuntar archivo" y pegá el link acá arriba,
     como en el proyecto de Analog 1. -->
$b26$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0202000007', '00000000-0000-4000-8000-AB0100000002', 'Cuestionario - Analog 2', 'Cuatro preguntas para chequear lo del módulo.', 73, false, 7, 'article', $b27$## Autoevaluación

Cuatro preguntas sobre lo del módulo: polifonía y note stealing, sync,
unísono y loops de envolvente. El resultado no se guarda, es para vos.

::demo[cuestionario-analog-2]

Si algo no te cerró, volvé a la lección correspondiente antes de seguir con
los plug-ins.
$b27$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;

COMMIT;
