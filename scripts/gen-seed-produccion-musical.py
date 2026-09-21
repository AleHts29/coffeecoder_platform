#!/usr/bin/env python3
"""Genera db/seed/curso-produccion-musical.sql desde las fuentes editables.

Fuentes: seed/produccion-musical/*.md (cuerpos de los artículos) y
seed/demos/*.html (demos del curso). Correr después de editar cualquiera
de las dos: `make seed-produccion-musical`.
"""
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent

DEMO_RE = re.compile(r'(?m)^[ \t]*::demo\[([a-z0-9]+(?:-[a-z0-9]+)*)\][ \t]*$')
FENCE_RE = re.compile(r'(?s)```.*?(?:```|$)')


def reading_time(body: str) -> int:
    """Misma fórmula que internal/content.ReadingTime."""
    no_code = FENCE_RE.sub(" ", body)
    demos = len(dict.fromkeys(DEMO_RE.findall(no_code)))
    code_words = sum(len(m.group(0).split()) for m in FENCE_RE.finditer(body))
    prose_words = len(DEMO_RE.sub(" ", no_code).split())
    return max(30, math.ceil((prose_words + code_words / 2) / 200 * 60) + demos * 60)


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def dollar(tag: str, s: str) -> str:
    assert f"${tag}$" not in s, tag
    return f"${tag}${s}${tag}$"


CAT = "00000000-0000-4000-8000-060000000002"      # produccion-musical
COURSE = "00000000-0000-4000-8000-AB0000000001"
mod = lambda n: f"00000000-0000-4000-8000-AB010000{n:04d}"
les = lambda m, n: f"00000000-0000-4000-8000-AB02{m:02d}0000{n:02d}"
demo = lambda n: f"00000000-0000-4000-8000-AB0300000{n:03d}"

# Un módulo por unidad del curso original (contenido-analog-1-monofonia.md §0).
MODULES = [
    "Analog 1: Monofonía", "Analog 2: Polifonía", "Introducción a plug-ins VST",
    "Instrument Racks", "MIDI: configuración, mapeo y grabación",
    "MIDI: creatividad y grabación", "Práctica guiada", "Trabajo práctico 1",
    "Armado de plantillas", "Arrangement: recursos creativos",
    "Espacialidad: Echo & Convolution Reverb", "EQ Eight & introducción a la compresión",
    "Glue Compressor & Drum Buss", "Práctica de ecualización y compresión",
    "BONUS: recursos creativos en la mezcla", "Trabajo práctico final",
]

# Biblioteca de demos del curso. Las demos son por curso: `lfo-amplitud`
# existe también en el curso de Go, acá va su propia copia.
DEMOS = [
    (1, "formas-de-onda", "Formas de onda y armónicos", 460),
    (2, "envolvente-adsr", "Envolvente ADSR", 460),
    (3, "cuestionario-analog-1", "Autoevaluación · Analog 1", 460),
    (4, "mono-vs-poli", "Monofonía y polifonía", 480),
    (5, "oscillator-sync", "Oscillator sync", 460),
    (6, "lfo-forma", "Formas del LFO", 440),
    (7, "lfo-amplitud", "Modulación de amplitud", 420),
    (8, "unisono-detune", "Unísono y detune", 480),
    (9, "envolvente-loop", "Loops de envolvente", 500),
    (10, "cuestionario-analog-2", "Autoevaluación · Analog 2", 460),
]

src = ROOT / "seed" / "produccion-musical"
art = lambda f: (src / f).read_text().rstrip() + "\n"

# (posición, título, descripción, kind, duración de video, muestra gratis, cuerpo)
MODULE_1 = [
    (1, "Video 1", "Presentación del módulo.", "video", 20 * 60, True, ""),
    (2, "Introducción a la Síntesis y Forma de Onda",
     "Oscilador, formas de onda y espectro de armónicos, con una demo para escuchar con los ojos.",
     "article", None, True, art("02-introduccion-sintesis.md")),
    (3, "Analog 1",
     "El sintetizador de Ableton por dentro: envolvente ADSR, pitch y sub-oscilador.",
     "article", None, False, art("03-analog.md")),
    (4, "Video 2", "Analog en Live, paso a paso.", "video", 45 * 60, False, ""),
    (5, "Video 3", "Diseño de sonido sobre el proyecto de clase.", "video", 32 * 60, False, ""),
    (6, "Ejercicio - Analog 1", "Diseñá un bajo y un lead desde cero, sin presets.",
     "article", None, False, art("06-ejercicio.md")),
    (7, "Proyecto de Clase | Consigna", "Diseñá los Analog de los canales 11 y 12 del proyecto.",
     "article", None, False, art("07-proyecto.md")),
    (8, "Cuestionario - Analog 1", "Cuatro preguntas para chequear lo del módulo.",
     "article", None, False, art("08-cuestionario.md")),
]

# Módulo 2 · Analog 2: Polifonía (7 lecciones).
MODULE_2 = [
    (1, "Video 1", "Presentación del módulo.", "video", 20 * 60, False, ""),
    (2, "Polifonía y osciladores en capas",
     "Voces, note stealing, suma de osciladores y oscillator sync.",
     "article", None, False, art("m2-02-polifonia-osciladores.md")),
    (3, "Modulación: LFO, AM y vibrato",
     "El LFO de Analog, la modulación de amplitud y el vibrato.",
     "article", None, False, art("m2-03-modulacion.md")),
    (4, "Cuerpo y voces: unísono, ruteo y envolventes",
     "Unison con detune, los cuatro ruteos rápidos y los loops de envolvente.",
     "article", None, False, art("m2-04-cuerpo-y-voces.md")),
    (5, "Ejercicio - Analog 2", "Diseñá un pad polifónico ancho desde cero.",
     "article", None, False, art("m2-05-ejercicio.md")),
    (6, "Proyecto de Clase | Polifonía", "Diseñá los Analog de los canales 14 y 15.",
     "article", None, False, art("m2-06-proyecto.md")),
    (7, "Cuestionario - Analog 2", "Cuatro preguntas para chequear lo del módulo.",
     "article", None, False, art("m2-07-cuestionario.md")),
]

DESCRIPTION = ("Un recorrido por Ableton Live pensado para entender, no para memorizar botones: "
               "qué hace cada instrumento y efecto, por qué, y cómo se escucha. Cada tema trae "
               "teoría corta y una demo interactiva para experimentar antes de abrir el DAW.")

out = [
    '-- CoffeeCoder · seed del curso "Producción Musical con Ableton" (desarrollo).',
    "-- GENERADO por scripts/gen-seed-produccion-musical.py. No editar a mano:",
    "-- editá seed/produccion-musical/*.md y seed/demos/*.html y regeneralo.",
    "-- Idempotente: UUIDs fijos + ON CONFLICT. Se aplica después de dev.sql.",
    "-- Serie de UUIDs propia, fuera del rango del seed de dev:",
    "--   curso   00000000-0000-4000-8000-AB0000000001",
    "--   módulos 00000000-0000-4000-8000-AB010000NNNN",
    "--   lección 00000000-0000-4000-8000-AB02MM0000NN",
    "--   demos   00000000-0000-4000-8000-AB0300000NNN",
    "",
    "BEGIN;",
    "",
    "-- Curso (draft: no se ve en el catálogo hasta publicarlo).",
    f"""INSERT INTO courses (id, slug, title, subtitle, description, level, price_cents, status, position, category_id)
VALUES ('{COURSE}', 'produccion-musical-ableton', 'Producción Musical con Ableton',
        'De la síntesis a la mezcla: cómo suena cada decisión, con demos que podés tocar.',
        {q(DESCRIPTION)}, 'medio', 5900, 'draft', 10, '{CAT}')
ON CONFLICT (id) DO UPDATE SET subtitle = EXCLUDED.subtitle, description = EXCLUDED.description,
  category_id = EXCLUDED.category_id;""",
    "",
    "-- Biblioteca de demos del curso.",
]
for n, slug, title, h in DEMOS:
    html = (ROOT / "seed" / "demos" / f"{slug}.html").read_text()
    out.append(f"""INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('{demo(n)}', '{COURSE}', '{slug}', {q(title)}, {dollar('d' + str(n), html)}, {h})
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;""")

out += ["", "-- Módulos: uno por unidad. Los que todavía no tienen lecciones",
        "-- marcan el plan (un módulo vacío no se publica)."]
for i, title in enumerate(MODULES, 1):
    out.append(f"INSERT INTO modules (id, course_id, title, position) VALUES "
               f"('{mod(i)}', '{COURSE}', {q(title)}, {i}) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;")

# Las duraciones de video son placeholders: al subir el archivo real, el
# provider informa la duración y la pisa.
for module_no, lessons, label in ((1, MODULE_1, "Analog 1: Monofonía"), (2, MODULE_2, "Analog 2: Polifonía")):
    out += ["", f"-- Módulo {module_no} · {label} ({len(lessons)} lecciones)."]
    for n, title, desc, kind, dur, free, body in lessons:
        seconds = dur if kind == "video" else reading_time(body)
        tag = f"b{module_no}{n}"
        out.append(f"""INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('{les(module_no, n)}', '{mod(module_no)}', {q(title)}, {q(desc)}, {seconds}, {str(free).lower()}, {n}, '{kind}', {dollar(tag, body)})
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description,
  duration_s = EXCLUDED.duration_s, is_free_sample = EXCLUDED.is_free_sample,
  kind = EXCLUDED.kind, body_md = EXCLUDED.body_md;""")

out += ["", "COMMIT;"]
(ROOT / "db" / "seed" / "curso-produccion-musical.sql").write_text("\n".join(out) + "\n")
print(f"curso-produccion-musical.sql · {len(MODULES)} módulos · "
      f"{len(MODULE_1) + len(MODULE_2)} lecciones · {len(DEMOS)} demos")
