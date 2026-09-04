-- name: CreateOrder :one
INSERT INTO orders (user_id, product_type, product_id, amount_cents, currency, provider)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: AttachProviderPayment :one
-- Vincula el pago externo apenas el provider lo emite (preference/intent).
UPDATE orders
SET provider_payment_id = $2
WHERE id = $1
RETURNING *;

-- name: ApproveOrderByProviderPayment :one
-- Punto de idempotencia del webhook: si ya está approved, el UPDATE
-- no cambia nada y el handler corta ahí (no re-crea enrollments).
UPDATE orders
SET status = 'approved'
WHERE provider = $1
  AND provider_payment_id = $2
  AND status = 'pending'
RETURNING *;

-- name: GetOrder :one
SELECT * FROM orders WHERE id = $1;

-- name: ListUserOrders :many
SELECT * FROM orders
WHERE user_id = $1
ORDER BY created_at DESC;
