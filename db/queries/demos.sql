-- name: ListDemosByCourse :many
-- Biblioteca de demos de un curso. Sin el HTML: es pesado y solo lo
-- necesita el frame firmado o el editor de una demo puntual.
SELECT id, course_id, slug, title, height_px, length(html)::int AS size_bytes, created_at, updated_at
FROM demos
WHERE course_id = $1
ORDER BY title;

-- name: GetDemo :one
SELECT * FROM demos WHERE id = $1;

-- name: ListDemosBySlugs :many
-- Las demos referenciadas por un artículo, resueltas dentro del curso.
SELECT id, course_id, slug, title, height_px
FROM demos
WHERE course_id = $1 AND slug = ANY(sqlc.arg(slugs)::text[]);

-- name: CreateDemo :one
INSERT INTO demos (course_id, slug, title, html, height_px)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateDemo :one
UPDATE demos
SET slug = $2, title = $3, html = $4, height_px = $5
WHERE id = $1
RETURNING *;

-- name: DeleteDemo :exec
DELETE FROM demos WHERE id = $1;

-- name: ListLessonsUsingDemo :many
-- Lecciones del curso cuyo cuerpo referencia ::demo[slug]. Se usa para
-- avisar antes de borrar una demo en uso.
SELECT l.id, l.title, m.title AS module_title
FROM lessons l
JOIN modules m ON m.id = l.module_id
WHERE m.course_id = $1
  AND l.body_md ~ ('(^|\n)[[:space:]]*::demo\[' || sqlc.arg(slug)::text || '\][[:space:]]*(\n|$)')
ORDER BY m.position, l.position;
