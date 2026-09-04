-- name: HasCourseAccess :one
-- Acceso a un curso: enrollment directo al curso, o enrollment a una
-- carrera que hoy contenga el curso. Los enrollments revocados no cuentan.
SELECT EXISTS (
  SELECT 1
  FROM enrollments e
  WHERE e.user_id = $1
    AND e.revoked_at IS NULL
    AND (
      (e.scope = 'course' AND e.scope_id = $2)
      OR (
        e.scope = 'career'
        AND EXISTS (
          SELECT 1 FROM career_courses cc
          WHERE cc.career_id = e.scope_id
            AND cc.course_id = $2
        )
      )
    )
) AS has_access;

-- name: HasLessonAccess :one
-- Una lección es accesible si es muestra gratis o si el usuario
-- tiene acceso al curso que la contiene.
SELECT
  l.is_free_sample
  OR EXISTS (
    SELECT 1
    FROM enrollments e
    WHERE e.user_id = $1
      AND e.revoked_at IS NULL
      AND (
        (e.scope = 'course' AND e.scope_id = m.course_id)
        OR (
          e.scope = 'career'
          AND EXISTS (
            SELECT 1 FROM career_courses cc
            WHERE cc.career_id = e.scope_id
              AND cc.course_id = m.course_id
          )
        )
      )
  ) AS has_access
FROM lessons l
JOIN modules m ON m.id = l.module_id
WHERE l.id = $2;

-- name: CreateEnrollment :one
INSERT INTO enrollments (user_id, scope, scope_id, order_id)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, scope, scope_id) DO UPDATE
  SET revoked_at = NULL
RETURNING *;

-- name: ListUserEnrollments :many
SELECT * FROM enrollments
WHERE user_id = $1 AND revoked_at IS NULL
ORDER BY activated_at DESC;

-- name: RevokeEnrollment :one
-- Reembolso o baja administrativa. Idempotente: revocar dos veces no
-- mueve la fecha original.
UPDATE enrollments
SET revoked_at = COALESCE(revoked_at, now())
WHERE id = $1
RETURNING *;
