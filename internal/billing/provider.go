// Package billing vende: una orden = un producto (curso o carrera).
// El PaymentProvider (Mercado Pago hoy, Stripe después) crea el
// checkout, informa pagos y reembolsa. El webhook es idempotente por
// diseño de datos: la transición pending → approved en una sola query.
package billing

import (
	"context"
	"net/http"

	"github.com/google/uuid"
)

type CheckoutRequest struct {
	OrderID     uuid.UUID
	Title       string
	Description string
	AmountCents int32
	Currency    string
	PayerEmail  string
}

type Checkout struct {
	// ProviderRef es el id externo del checkout (preference id).
	ProviderRef string
	// URL a la que se redirige al comprador.
	URL string
}

type PaymentStatus string

const (
	PaymentApproved PaymentStatus = "approved"
	PaymentPending  PaymentStatus = "pending"
	PaymentRejected PaymentStatus = "rejected"
	PaymentRefunded PaymentStatus = "refunded"
	PaymentUnknown  PaymentStatus = "unknown"
)

type Payment struct {
	ID          string
	Status      PaymentStatus
	OrderID     uuid.UUID // external_reference
	AmountCents int32
	Currency    string
}

type PaymentProvider interface {
	// Name se persiste en orders.provider.
	Name() string
	CreateCheckout(ctx context.Context, req CheckoutRequest) (Checkout, error)
	GetPayment(ctx context.Context, paymentID string) (Payment, error)
	Refund(ctx context.Context, paymentID string) error
	// ParseWebhook valida la firma y devuelve el id de pago a consultar.
	// ok=false con err=nil significa "evento que no nos interesa".
	ParseWebhook(r *http.Request, body []byte) (paymentID string, ok bool, err error)
}
