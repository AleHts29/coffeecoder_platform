-- name: CreateUser :one
INSERT INTO users (email, password_hash, name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByOAuthIdentity :one
SELECT u.*
FROM users u
JOIN auth_identities ai ON ai.user_id = u.id
WHERE ai.provider = $1 AND ai.provider_id = $2;

-- name: LinkOAuthIdentity :exec
INSERT INTO auth_identities (provider, provider_id, user_id)
VALUES ($1, $2, $3)
ON CONFLICT (provider, provider_id) DO NOTHING;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetRefreshTokenByHash :one
-- Trae el token aunque esté revocado o vencido: el service decide.
-- Un token revocado que vuelve a aparecer es señal de robo y dispara
-- la revocación de toda la familia del usuario.
SELECT * FROM refresh_tokens WHERE token_hash = $1;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked_at = now()
WHERE id = $1 AND revoked_at IS NULL;

-- name: RevokeAllUserRefreshTokens :exec
UPDATE refresh_tokens SET revoked_at = now()
WHERE user_id = $1 AND revoked_at IS NULL;

-- name: DeleteExpiredRefreshTokens :exec
-- Limpieza periódica (job): borra tokens vencidos hace más de 30 días.
DELETE FROM refresh_tokens
WHERE expires_at < now() - interval '30 days';
