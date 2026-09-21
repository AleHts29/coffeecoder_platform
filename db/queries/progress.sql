-- name: UpsertHeartbeat :exec
-- Un heartbeat del player cada ~15 s. GREATEST evita que un seek
-- hacia atrás pise el máximo alcanzado; completed nunca retrocede.
INSERT INTO lesson_progress (user_id, lesson_id, seconds, updated_at)
VALUES ($1, $2, $3, now())
ON CONFLICT (user_id, lesson_id) DO UPDATE SET
  seconds    = GREATEST(lesson_progress.seconds, EXCLUDED.seconds),
  updated_at = now();

-- name: MarkLessonCompleted :one
INSERT INTO lesson_progress (user_id, lesson_id, seconds, completed, completed_at, updated_at)
VALUES ($1, $2, $3, true, now(), now())
ON CONFLICT (user_id, lesson_id) DO UPDATE SET
  seconds      = GREATEST(lesson_progress.seconds, EXCLUDED.seconds),
  completed    = true,
  completed_at = COALESCE(lesson_progress.completed_at, now()),
  updated_at   = now()
RETURNING *;

-- name: RefreshCourseProgress :exec
-- Recalcula el agregado de un curso para un usuario. Se llama tras
-- MarkLessonCompleted; barato porque acota por curso.
INSERT INTO course_progress (user_id, course_id, completed_lessons, total_lessons, last_lesson_id, updated_at)
SELECT
  $1,
  $2,
  count(*) FILTER (WHERE lp.completed),
  count(*),
  (
    SELECT lp2.lesson_id
    FROM lesson_progress lp2
    JOIN lessons l2 ON l2.id = lp2.lesson_id
    JOIN modules m2 ON m2.id = l2.module_id
    WHERE lp2.user_id = $1 AND m2.course_id = $2
    ORDER BY lp2.updated_at DESC
    LIMIT 1
  ),
  now()
FROM lessons l
JOIN modules m ON m.id = l.module_id
LEFT JOIN lesson_progress lp
  ON lp.lesson_id = l.id AND lp.user_id = $1
WHERE m.course_id = $2
ON CONFLICT (user_id, course_id) DO UPDATE SET
  completed_lessons = EXCLUDED.completed_lessons,
  total_lessons     = EXCLUDED.total_lessons,
  last_lesson_id    = EXCLUDED.last_lesson_id,
  updated_at        = now();

-- name: GetContinueWatching :one
-- El hero del dashboard: la última lección tocada con contexto completo.
SELECT
  lp.lesson_id,
  lp.seconds,
  l.title      AS lesson_title,
  l.duration_s,
  l.kind,
  m.title      AS module_title,
  m.position   AS module_position,
  c.id         AS course_id,
  c.slug       AS course_slug,
  c.title      AS course_title
FROM lesson_progress lp
JOIN lessons l ON l.id = lp.lesson_id
JOIN modules m ON m.id = l.module_id
JOIN courses c ON c.id = m.course_id
WHERE lp.user_id = $1 AND NOT lp.completed
ORDER BY lp.updated_at DESC
LIMIT 1;

-- name: ListCourseProgressByUser :many
SELECT * FROM course_progress
WHERE user_id = $1
ORDER BY updated_at DESC;

-- name: GetLessonProgress :one
SELECT * FROM lesson_progress WHERE user_id = $1 AND lesson_id = $2;

-- name: ListLessonProgressByCourse :many
-- Posición y completado de cada lección de un curso para un usuario.
-- Lectura por PK acotada a las lecciones del curso, no un agregado.
SELECT lp.lesson_id, lp.seconds, lp.completed
FROM lesson_progress lp
JOIN lessons l ON l.id = lp.lesson_id
JOIN modules m ON m.id = l.module_id
WHERE lp.user_id = $1 AND m.course_id = $2;

-- name: GetCourseProgress :one
SELECT * FROM course_progress WHERE user_id = $1 AND course_id = $2;

-- name: UpsertDailyActivity :exec
-- Suma segundos de estudio al día de hoy (en la zona horaria dada).
INSERT INTO daily_activity (user_id, day, seconds)
VALUES ($1, (now() AT TIME ZONE sqlc.arg(tz)::text)::date, $2)
ON CONFLICT (user_id, day) DO UPDATE
  SET seconds = daily_activity.seconds + EXCLUDED.seconds;

-- name: ListDailyActivitySince :many
SELECT day, seconds FROM daily_activity
WHERE user_id = $1 AND day >= $2
ORDER BY day DESC;

-- name: ListEnrolledCareers :many
-- Carreras con enrollment vigente del usuario, en orden de compra.
SELECT c.*
FROM enrollments e
JOIN careers c ON c.id = e.scope_id
WHERE e.user_id = $1 AND e.scope = 'career' AND e.revoked_at IS NULL
ORDER BY e.activated_at DESC;

-- name: ListEnrolledCourses :many
-- Cursos comprados sueltos (no los que vienen por carrera).
SELECT c.*
FROM enrollments e
JOIN courses c ON c.id = e.scope_id
WHERE e.user_id = $1 AND e.scope = 'course' AND e.revoked_at IS NULL
ORDER BY e.activated_at DESC;
