-- name: ListPublishedCareers :many
SELECT * FROM careers
WHERE status = 'published'
ORDER BY position, created_at;

-- name: GetCareerBySlug :one
SELECT * FROM careers WHERE slug = $1;

-- name: ListCareerCourses :many
SELECT c.*, cc.position AS career_position
FROM career_courses cc
JOIN courses c ON c.id = cc.course_id
WHERE cc.career_id = $1
ORDER BY cc.position;

-- name: ListPublishedCourses :many
SELECT * FROM courses
WHERE status = 'published'
ORDER BY position, created_at;

-- name: GetCourseBySlug :one
SELECT * FROM courses WHERE slug = $1;

-- name: GetCourseCurriculum :many
-- Currícula completa de un curso: módulos y lecciones ordenados.
-- video_asset_id NO se expone acá: las URLs de reproducción se firman
-- por lección en el módulo media, tras verificar acceso.
SELECT
  m.id         AS module_id,
  m.title      AS module_title,
  m.position   AS module_position,
  l.id         AS lesson_id,
  l.title      AS lesson_title,
  l.description,
  l.duration_s,
  l.is_free_sample,
  l.kind,
  l.position   AS lesson_position
FROM modules m
JOIN lessons l ON l.module_id = m.id
WHERE m.course_id = $1
ORDER BY m.position, l.position;

-- name: ListCourseStats :many
-- Agregados por curso para cards y heros: cantidad de lecciones y
-- duración total. Se calcula sobre la currícula (no sobre progreso).
SELECT
  m.course_id,
  COUNT(l.id)::int                 AS lesson_count,
  COALESCE(SUM(l.duration_s), 0)::int AS duration_s
FROM modules m
JOIN lessons l ON l.module_id = m.id
GROUP BY m.course_id;

-- name: ListPublishedCareersForCourse :many
-- Carreras publicadas que contienen el curso (para el upsell al bundle).
SELECT c.*
FROM career_courses cc
JOIN careers c ON c.id = cc.career_id
WHERE cc.course_id = $1 AND c.status = 'published'
ORDER BY c.position, c.created_at;
