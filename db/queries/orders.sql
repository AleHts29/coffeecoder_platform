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

-- name: ApproveOrder :one
-- Punto de idempotencia para providers que informan el pago recién en
-- el webhook (Checkout Pro): la orden se ubica por external_reference
-- (= id de la orden) y solo transiciona si sigue pending. El índice
-- único (provider, provider_payment_id) impide que un mismo pago
-- apruebe dos órdenes.
UPDATE orders
SET status = 'approved', provider_payment_id = $3
WHERE id = $1 AND provider = $2 AND status = 'pending'
RETURNING *;

-- name: RejectOrder :one
UPDATE orders
SET status = 'rejected', provider_payment_id = COALESCE($3, provider_payment_id)
WHERE id = $1 AND provider = $2 AND status = 'pending'
RETURNING *;

-- name: RefundOrder :one
UPDATE orders
SET status = 'refunded'
WHERE id = $1 AND status = 'approved'
RETURNING *;

-- name: GetEnrollmentByOrder :one
SELECT * FROM enrollments WHERE order_id = $1;

-- name: ListOrders :many
-- Admin: últimas órdenes con comprador y producto.
SELECT
  o.*,
  u.email AS user_email,
  u.name  AS user_name,
  COALESCE(c.title, k.title, '') AS product_title
FROM orders o
JOIN users u ON u.id = o.user_id
LEFT JOIN courses c ON o.product_type = 'course' AND c.id = o.product_id
LEFT JOIN careers k ON o.product_type = 'career' AND k.id = o.product_id
ORDER BY o.created_at DESC
LIMIT $1 OFFSET $2;

-- name: ListUserOrdersWithProduct :many
SELECT
  o.*,
  COALESCE(c.title, k.title, '') AS product_title,
  COALESCE(c.slug, k.slug, '')   AS product_slug
FROM orders o
LEFT JOIN courses c ON o.product_type = 'course' AND c.id = o.product_id
LEFT JOIN careers k ON o.product_type = 'career' AND k.id = o.product_id
WHERE o.user_id = $1
ORDER BY o.created_at DESC;

-- name: HasCareerAccess :one
SELECT EXISTS (
  SELECT 1 FROM enrollments e
  WHERE e.user_id = $1 AND e.scope = 'career' AND e.scope_id = $2 AND e.revoked_at IS NULL
) AS has_access;

-- name: GetCareer :one
SELECT * FROM careers WHERE id = $1;

-- name: GetCourse :one
SELECT * FROM courses WHERE id = $1;

-- name: GetPendingOrder :one
-- Orden pending reciente del mismo usuario y producto: se reutiliza en
-- vez de crear una nueva por cada clic en "Pagar".
SELECT * FROM orders
WHERE user_id = $1 AND product_type = $2 AND product_id = $3
  AND status = 'pending' AND created_at > now() - interval '24 hours'
ORDER BY created_at DESC
LIMIT 1;
