#!/usr/bin/env python3
"""Genera db/seed/articles.sql (curso "Go desde cero") desde las fuentes.

Fuentes: seed/articulo-ejemplo.md y seed/demos/*.html. Correr después de
editar cualquiera de las dos: `make seed-articles`.
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


COURSE = "00000000-0000-4000-8000-020000000001"   # go-desde-cero
MODULE = "00000000-0000-4000-8000-030000000103"   # Errores y concurrencia
LESSON = "00000000-0000-4000-8000-040000010305"
DEMOS = [
    ("00000000-0000-4000-8000-050000000001", "channels-buffer", "Channels con y sin buffer", 420),
    ("00000000-0000-4000-8000-050000000002", "lfo-amplitud", "LFO: modulación de amplitud", 520),
]

article = (ROOT / "seed" / "articulo-ejemplo.md").read_text()
seconds = reading_time(article)

out = [
    "-- CoffeeCoder · seed de artículos y demos del curso \"Go desde cero\".",
    "-- GENERADO por scripts/gen-seed-articles.py. No editar a mano: editá",
    "-- seed/articulo-ejemplo.md y seed/demos/*.html y regeneralo.",
    "-- Idempotente: UUIDs fijos + ON CONFLICT. Se aplica después de dev.sql.",
    "",
    "BEGIN;",
    "",
    "-- Biblioteca de demos del curso.",
]
for i, (did, slug, title, height) in enumerate(DEMOS, 1):
    html = (ROOT / "seed" / "demos" / f"{slug}.html").read_text()
    out.append(f"""INSERT INTO demos (id, course_id, slug, title, html, height_px)
VALUES ('{did}', '{COURSE}', '{slug}', {q(title)}, {dollar('d' + str(i), html)}, {height})
ON CONFLICT (id) DO UPDATE SET html = EXCLUDED.html, title = EXCLUDED.title, height_px = EXCLUDED.height_px;""")

out += [
    "",
    "-- Lección de lectura en el módulo \"Errores y concurrencia\", como muestra",
    "-- gratis. duration_s = tiempo de lectura con la fórmula de internal/content.",
    f"""INSERT INTO lessons (id, module_id, title, description, duration_s, is_free_sample, position, kind, body_md)
VALUES ('{LESSON}', '{MODULE}', 'Channels con y sin buffer',
        'Qué cambia cuando un channel tiene capacidad, con una demo para probarlo.',
        {seconds}, true, 5, 'article', {dollar('art', article)})
ON CONFLICT (id) DO UPDATE SET body_md = EXCLUDED.body_md, duration_s = EXCLUDED.duration_s;""",
    "",
    "COMMIT;",
]
(ROOT / "db" / "seed" / "articles.sql").write_text("\n".join(out) + "\n")
print(f"articles.sql · {len(DEMOS)} demos · lectura {seconds}s")
