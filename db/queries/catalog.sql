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
  l.position   AS lesson_position
FROM modules m
JOIN lessons l ON l.module_id = m.id
WHERE m.course_id = $1
ORDER BY m.position, l.position;
