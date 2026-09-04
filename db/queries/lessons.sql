-- name: GetLesson :one
-- Lección con su contexto de curso. Uso interno (media, progress):
-- los handlers públicos nunca serializan esta fila directo.
SELECT
  l.*,
  m.course_id,
  m.title    AS module_title,
  m.position AS module_position
FROM lessons l
JOIN modules m ON m.id = l.module_id
WHERE l.id = $1;

-- name: SetLessonVideoUploading :one
-- Se llama al iniciar un upload: asocia el asset externo y resetea
-- la duración (la trae el webhook de transcodificación).
UPDATE lessons
SET video_provider = $2,
    video_asset_id = $3,
    video_status   = 'uploading',
    duration_s     = 0
WHERE id = $1
RETURNING *;

-- name: UpdateLessonVideoByAsset :one
-- Transición de estado disparada por webhook o sync manual. Si el
-- provider ya informa duración (> 0) se persiste; si no, se conserva.
UPDATE lessons
SET video_status = $3,
    duration_s   = CASE WHEN $4::int > 0 THEN $4::int ELSE duration_s END
WHERE video_provider = $1 AND video_asset_id = $2
RETURNING *;
