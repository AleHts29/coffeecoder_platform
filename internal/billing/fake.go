package billing

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"sync"

	"github.com/google/uuid"
)

// Fake es el provider de desarrollo y tests: el checkout "redirige" a la
// página de resultado, y `make dev-pay ORDER=<id>` (o un test) manda un
// webhook sin firma con el id de pago "fake-<orden>". Se persiste como
// 'mercadopago' para respetar el CHECK de orders.provider.
type Fake struct {
	frontendURL string

	mu       sync.Mutex
	payments map[string]Payment
	refunded map[string]bool
}

func NewFake(frontendURL string) *Fake {
	return &Fake{frontendURL: strings.TrimRight(frontendURL, "/"), payments: map[string]Payment{}, refunded: map[string]bool{}}
}

func (f *Fake) Name() string { return "mercadopago" }

func (f *Fake) CreateCheckout(_ context.Context, req CheckoutRequest) (Checkout, error) {
	id := "fake-" + req.OrderID.String()
	f.mu.Lock()
	f.payments[id] = Payment{ID: id, Status: PaymentApproved, OrderID: req.OrderID, AmountCents: req.AmountCents, Currency: req.Currency}
	f.mu.Unlock()
	return Checkout{ProviderRef: "pref-" + id, URL: f.frontendURL + "/checkout/resultado?orden=" + req.OrderID.String() + "&estado=pendiente&simulado=1"}, nil
}

// SetStatus permite a los tests simular rechazos.
func (f *Fake) SetStatus(paymentID string, status PaymentStatus) {
	f.mu.Lock()
	defer f.mu.Unlock()
	p := f.payments[paymentID]
	p.Status = status
	f.payments[paymentID] = p
}

func (f *Fake) GetPayment(_ context.Context, paymentID string) (Payment, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if p, ok := f.payments[paymentID]; ok {
		return p, nil
	}
	// Pago que no creó este proceso (ej: `make dev-pay` tras reiniciar):
	// se deduce la orden del id.
	if rest, ok := strings.CutPrefix(paymentID, "fake-"); ok {
		if id, err := uuid.Parse(rest); err == nil {
			return Payment{ID: paymentID, Status: PaymentApproved, OrderID: id}, nil
		}
	}
	return Payment{}, errors.New("billing: pago desconocido")
}

func (f *Fake) Refund(_ context.Context, paymentID string) error {
	f.mu.Lock()
	f.refunded[paymentID] = true
	f.mu.Unlock()
	return nil
}

func (f *Fake) Refunded(paymentID string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.refunded[paymentID]
}

func (f *Fake) ParseWebhook(_ *http.Request, body []byte) (string, bool, error) {
	var ev struct {
		Type string `json:"type"`
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &ev); err != nil || ev.Data.ID == "" {
		return "", false, errors.New("billing: webhook fake inválido")
	}
	return ev.Data.ID, ev.Type == "" || ev.Type == "payment", nil
}
