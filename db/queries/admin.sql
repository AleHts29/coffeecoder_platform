-- Queries de administración (P7). Solo las usa el rol admin.

-- ---------------------------------------------------------------------------
-- Carreras
-- ---------------------------------------------------------------------------

-- name: AdminListCareers :many
SELECT c.*, (SELECT count(*) FROM career_courses cc WHERE cc.career_id = c.id)::int AS course_count
FROM careers c
ORDER BY c.position, c.created_at;

-- name: CreateCareer :one
INSERT INTO careers (slug, title, subtitle, description, level, price_cents, status, position)
VALUES ($1, $2, $3, $4, $5, $6, $7, (SELECT COALESCE(MAX(position), 0) + 1 FROM careers))
RETURNING *;

-- name: UpdateCareer :one
UPDATE careers
SET slug = $2, title = $3, subtitle = $4, description = $5, level = $6, price_cents = $7, status = $8
WHERE id = $1
RETURNING *;

-- name: DeleteCareer :exec
DELETE FROM careers WHERE id = $1;

-- name: DeleteCareerCourses :exec
DELETE FROM career_courses WHERE career_id = $1;

-- name: InsertCareerCourse :exec
INSERT INTO career_courses (career_id, course_id, position) VALUES ($1, $2, $3);

-- ---------------------------------------------------------------------------
-- Cursos
-- ---------------------------------------------------------------------------

-- name: AdminListCourses :many
SELECT c.*,
  (SELECT count(*) FROM modules m JOIN lessons l ON l.module_id = m.id WHERE m.course_id = c.id)::int AS lesson_count
FROM courses c
ORDER BY c.position, c.created_at;

-- name: CreateCourse :one
INSERT INTO courses (slug, title, subtitle, description, level, price_cents, status, position)
VALUES ($1, $2, $3, $4, $5, $6, $7, (SELECT COALESCE(MAX(position), 0) + 1 FROM courses))
RETURNING *;

-- name: UpdateCourse :one
UPDATE courses
SET slug = $2, title = $3, subtitle = $4, description = $5, level = $6, price_cents = $7, status = $8
WHERE id = $1
RETURNING *;

-- name: DeleteCourse :exec
DELETE FROM courses WHERE id = $1;

-- name: AdminGetCourseCurriculum :many
-- Como GetCourseCurriculum pero con módulos vacíos y estado del video.
-- video_asset_id sigue sin salir: el admin opera por estado.
SELECT
  m.id           AS module_id,
  m.title        AS module_title,
  m.position     AS module_position,
  l.id           AS lesson_id,
  l.title        AS lesson_title,
  l.description,
  l.duration_s,
  l.is_free_sample,
  l.position     AS lesson_position,
  l.video_status,
  l.kind,
  l.body_md
FROM modules m
LEFT JOIN lessons l ON l.module_id = m.id
WHERE m.course_id = $1
ORDER BY m.position, l.position;

-- ---------------------------------------------------------------------------
-- Módulos y lecciones
-- ---------------------------------------------------------------------------

-- name: CreateModule :one
INSERT INTO modules (course_id, title, position)
VALUES ($1, $2, (SELECT COALESCE(MAX(position), 0) + 1 FROM modules WHERE course_id = $1))
RETURNING *;

-- name: GetModule :one
SELECT * FROM modules WHERE id = $1;

-- name: UpdateModule :one
UPDATE modules SET title = $2 WHERE id = $1 RETURNING *;

-- name: DeleteModule :exec
DELETE FROM modules WHERE id = $1;

-- name: ListModuleIDs :many
SELECT id FROM modules WHERE course_id = $1 ORDER BY position;

-- name: SetModulePosition :exec
-- Solo dentro de una transacción: UNIQUE (course_id, position) es
-- DEFERRABLE INITIALLY DEFERRED justamente para reordenar.
UPDATE modules SET position = $2 WHERE id = $1;

-- name: CreateLesson :one
INSERT INTO lessons (module_id, title, description, duration_s, is_free_sample, kind, body_md, position)
VALUES ($1, $2, $3, $4, $5, $6, $7, (SELECT COALESCE(MAX(position), 0) + 1 FROM lessons WHERE module_id = $1))
RETURNING *;

-- name: UpdateLesson :one
-- El tipo no se cambia acá: tiene su propia query con guarda.
UPDATE lessons
SET title = $2, description = $3, duration_s = $4, is_free_sample = $5, body_md = $6
WHERE id = $1
RETURNING *;

-- name: SetLessonKind :one
-- Cambiar el tipo solo si la lección no tiene video subido; si no,
-- no afecta filas y el service devuelve un error accionable.
UPDATE lessons
SET kind = $2, body_md = CASE WHEN $2 = 'video' THEN '' ELSE body_md END
WHERE id = $1 AND video_status = 'none'
RETURNING *;

-- name: DeleteLesson :exec
DELETE FROM lessons WHERE id = $1;

-- name: ListLessonIDs :many
SELECT id FROM lessons WHERE module_id = $1 ORDER BY position;

-- name: SetLessonPosition :exec
UPDATE lessons SET position = $2 WHERE id = $1;

-- ---------------------------------------------------------------------------
-- Alumnos
-- ---------------------------------------------------------------------------

-- name: AdminListUsers :many
SELECT u.id, u.email, u.name, u.role, u.created_at,
  (SELECT count(*) FROM enrollments e WHERE e.user_id = u.id AND e.revoked_at IS NULL)::int AS active_enrollments
FROM users u
WHERE sqlc.arg(q)::text = '' OR u.email ILIKE '%' || sqlc.arg(q)::text || '%' OR u.name ILIKE '%' || sqlc.arg(q)::text || '%'
ORDER BY u.created_at DESC
LIMIT $1 OFFSET $2;

-- name: AdminListUserEnrollments :many
SELECT e.*,
  COALESCE(c.title, k.title, '') AS product_title,
  COALESCE(c.slug, k.slug, '')   AS product_slug
FROM enrollments e
LEFT JOIN courses c ON e.scope = 'course' AND c.id = e.scope_id
LEFT JOIN careers k ON e.scope = 'career' AND k.id = e.scope_id
WHERE e.user_id = $1
ORDER BY e.activated_at DESC;

-- name: GetEnrollment :one
SELECT * FROM enrollments WHERE id = $1;
