-- name: ListCategories :many
-- Tabla chica: el service la trae entera y mapea por id.
SELECT * FROM categories ORDER BY position, name;

-- name: GetCategoryBySlug :one
SELECT * FROM categories WHERE slug = $1;

-- name: SetCourseCategory :exec
UPDATE courses SET category_id = $2 WHERE id = $1;

-- name: SetCareerCategory :exec
UPDATE careers SET category_id = $2 WHERE id = $1;
