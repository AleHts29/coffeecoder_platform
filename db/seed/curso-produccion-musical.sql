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
  }

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
$d1$, 420)
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

  function press(e) {
    if (e && e.cancelable && e.type !== 'mousedown') e.preventDefault();
    if (mode === 'held') return;
    mode = 'held'; pressT = now();
    btn.classList.add('on'); btn.setAttribute('aria-pressed', 'true');
    if (reduce) { setStage('sustain'); render(); }
    else if (!raf) raf = requestAnimationFrame(loop);
  }

  function letGo() {
    if (mode !== 'held') return;
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
$d2$, 420)
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

-- Módulos: uno por unidad. Solo el primero tiene lecciones cargadas;
-- el resto marca el plan (un módulo vacío no se publica).
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
VALUES ('00000000-0000-4000-8000-AB0201000001', '00000000-0000-4000-8000-AB0100000001', 'Video 1', 'Presentación del módulo.', 1200, true, 1, 'video', $b1$$b1$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000002', '00000000-0000-4000-8000-AB0100000001', 'Introducción a la Síntesis y Forma de Onda', 'Oscilador, formas de onda y espectro de armónicos, con una demo para escuchar con los ojos.', 214, true, 2, 'article', $b2$## Qué es sintetizar

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
$b2$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000003', '00000000-0000-4000-8000-AB0100000001', 'Analog 1', 'El sintetizador de Ableton por dentro: envolvente ADSR, pitch y sub-oscilador.', 203, false, 3, 'article', $b3$## El instrumento Analog

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
$b3$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000004', '00000000-0000-4000-8000-AB0100000001', 'Video 2', 'Analog en Live, paso a paso.', 2700, false, 4, 'video', $b4$$b4$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000005', '00000000-0000-4000-8000-AB0100000001', 'Video 3', 'Diseño de sonido sobre el proyecto de clase.', 1920, false, 5, 'video', $b5$$b5$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000006', '00000000-0000-4000-8000-AB0100000001', 'Ejercicio - Analog 1', 'Diseñá un bajo y un lead desde cero, sin presets.', 46, false, 6, 'article', $b6$## Ejercicio: diseñá un bajo y un lead desde cero

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
$b6$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000007', '00000000-0000-4000-8000-AB0100000001', 'Proyecto de Clase | Consigna', 'Diseñá los Analog de los canales 11 y 12 del proyecto.', 34, false, 7, 'article', $b7$## Proyecto de clase

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
$b7$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;
INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('00000000-0000-4000-8000-AB0201000008', '00000000-0000-4000-8000-AB0100000001', 'Cuestionario - Analog 1', 'Cuatro preguntas para chequear lo del módulo.', 73, false, 8, 'article', $b8$## Autoevaluación

Cuatro preguntas para chequear lo del módulo: formas de onda, envolvente y
sub-oscilador. El resultado no se guarda en ningún lado, es para vos.

::demo[cuestionario-analog-1]

Si algo no te cerró, volvé a la lección correspondiente antes de seguir con
Analog 2.
$b8$)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;

COMMIT;
