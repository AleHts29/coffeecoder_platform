package billing

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/config"
)

// MercadoPago implementa PaymentProvider con Checkout Pro:
//   - POST /checkout/preferences → init_point (redirect), cuotas habilitadas
//   - webhook firmado (x-signature) → GET /v1/payments/{id}
//   - POST /v1/payments/{id}/refunds
//
// Campos según el SDK oficial (mercadopago/sdk-go) al 2026-09-05.
type MercadoPago struct {
	cfg         config.MercadoPagoConfig
	http        *http.Client
	publicBase  string // API pública (notification_url)
	frontendURL string // back_urls
	installment int
}

func NewMercadoPago(cfg config.MercadoPagoConfig, publicBaseURL, frontendURL string) *MercadoPago {
	return &MercadoPago{
		cfg: cfg, http: &http.Client{Timeout: 15 * time.Second},
		publicBase: strings.TrimRight(publicBaseURL, "/"), frontendURL: strings.TrimRight(frontendURL, "/"),
		installment: 12,
	}
}

func (m *MercadoPago) Name() string { return "mercadopago" }

func (m *MercadoPago) CreateCheckout(ctx context.Context, req CheckoutRequest) (Checkout, error) {
	if m.cfg.AccessToken == "" {
		return Checkout{}, errors.New("billing: MP_ACCESS_TOKEN no configurado")
	}
	result := m.frontendURL + "/checkout/resultado?orden=" + req.OrderID.String()
	payload := map[string]any{
		"items": []map[string]any{{
			"id": req.OrderID.String(), "title": req.Title, "description": req.Description,
			"quantity": 1, "unit_price": float64(req.AmountCents) / 100, "currency_id": req.Currency,
		}},
		"payer":              map[string]any{"email": req.PayerEmail},
		"external_reference": req.OrderID.String(),
		"notification_url":   m.publicBase + "/api/v1/webhooks/mercadopago",
		"back_urls": map[string]string{
			"success": result + "&estado=aprobado",
			"pending": result + "&estado=pendiente",
			"failure": result + "&estado=rechazado",
		},
		"auto_return":          "approved",
		"statement_descriptor": "COFFEECODER",
		"payment_methods":      map[string]any{"installments": m.installment},
		"metadata":             map[string]any{"order_id": req.OrderID.String()},
	}
	var out struct {
		ID        string `json:"id"`
		InitPoint string `json:"init_point"`
	}
	if err := m.do(ctx, http.MethodPost, "/checkout/preferences", payload, &out, ""); err != nil {
		return Checkout{}, fmt.Errorf("billing: creando preference: %w", err)
	}
	if out.InitPoint == "" {
		return Checkout{}, errors.New("billing: Mercado Pago no devolvió init_point")
	}
	return Checkout{ProviderRef: out.ID, URL: out.InitPoint}, nil
}

func (m *MercadoPago) GetPayment(ctx context.Context, paymentID string) (Payment, error) {
	var out struct {
		ID                json.Number `json:"id"`
		Status            string      `json:"status"`
		ExternalReference string      `json:"external_reference"`
		TransactionAmount float64     `json:"transaction_amount"`
		CurrencyID        string      `json:"currency_id"`
	}
	if err := m.do(ctx, http.MethodGet, "/v1/payments/"+paymentID, nil, &out, ""); err != nil {
		return Payment{}, fmt.Errorf("billing: consultando pago %s: %w", paymentID, err)
	}
	p := Payment{
		ID: out.ID.String(), Status: mapMPStatus(out.Status),
		AmountCents: int32(math.Round(out.TransactionAmount * 100)), Currency: out.CurrencyID,
	}
	if id, err := uuid.Parse(out.ExternalReference); err == nil {
		p.OrderID = id
	}
	return p, nil
}

func mapMPStatus(s string) PaymentStatus {
	switch s {
	case "approved":
		return PaymentApproved
	case "pending", "in_process", "in_mediation", "authorized":
		return PaymentPending
	case "rejected", "cancelled":
		return PaymentRejected
	case "refunded", "charged_back":
		return PaymentRefunded
	default:
		return PaymentUnknown
	}
}

func (m *MercadoPago) Refund(ctx context.Context, paymentID string) error {
	// Reembolso total; X-Idempotency-Key evita duplicar si se reintenta.
	return m.do(ctx, http.MethodPost, "/v1/payments/"+paymentID+"/refunds", map[string]any{}, nil, "refund-"+paymentID)
}

// ParseWebhook valida x-signature (ts=...,v1=...):
//
//	v1 = hex(HMAC-SHA256(secret, "id:{data.id};request-id:{x-request-id};ts:{ts};"))
//
// data.id sale del query string (data.id) o, si no está, del cuerpo; en
// minúsculas si es alfanumérico. Solo nos interesan eventos de pago.
func (m *MercadoPago) ParseWebhook(r *http.Request, body []byte) (string, bool, error) {
	if m.cfg.WebhookSecret == "" {
		return "", false, errors.New("billing: MP_WEBHOOK_SECRET no configurado")
	}
	var ev struct {
		Type string `json:"type"`
		Data struct {
			ID json.Number `json:"id"`
		} `json:"data"`
	}
	_ = json.Unmarshal(body, &ev)

	dataID := r.URL.Query().Get("data.id")
	if dataID == "" {
		dataID = ev.Data.ID.String()
	}
	dataID = strings.ToLower(dataID)
	typ := r.URL.Query().Get("type")
	if typ == "" {
		typ = ev.Type
	}

	ts, v1 := parseSignature(r.Header.Get("x-signature"))
	if ts == "" || v1 == "" || dataID == "" {
		return "", false, errors.New("billing: webhook sin firma o sin data.id")
	}
	if !VerifyMPSignature(m.cfg.WebhookSecret, dataID, r.Header.Get("x-request-id"), ts, v1) {
		return "", false, errors.New("billing: firma de webhook inválida")
	}
	if typ != "payment" {
		return "", false, nil
	}
	return dataID, true, nil
}

func parseSignature(h string) (ts, v1 string) {
	for _, part := range strings.Split(h, ",") {
		k, v, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		switch strings.TrimSpace(k) {
		case "ts":
			ts = strings.TrimSpace(v)
		case "v1":
			v1 = strings.TrimSpace(v)
		}
	}
	return
}

// VerifyMPSignature calcula el manifest oficial y compara en tiempo constante.
func VerifyMPSignature(secret, dataID, requestID, ts, v1 string) bool {
	return hmac.Equal([]byte(SignMPManifest(secret, dataID, requestID, ts)), []byte(v1))
}

func SignMPManifest(secret, dataID, requestID, ts string) string {
	manifest := "id:" + dataID + ";"
	if requestID != "" {
		manifest += "request-id:" + requestID + ";"
	}
	manifest += "ts:" + ts + ";"
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(manifest))
	return hex.EncodeToString(mac.Sum(nil))
}

func (m *MercadoPago) do(ctx context.Context, method, path string, in any, out any, idempotencyKey string) error {
	var body io.Reader
	if in != nil {
		b, _ := json.Marshal(in)
		body = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, m.cfg.APIBaseURL+path, body)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+m.cfg.AccessToken)
	req.Header.Set("Accept", "application/json")
	if in != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if idempotencyKey != "" {
		req.Header.Set("X-Idempotency-Key", idempotencyKey)
	}
	res, err := m.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("HTTP %d: %s", res.StatusCode, strings.TrimSpace(string(raw)))
	}
	if out != nil {
		return json.Unmarshal(raw, out)
	}
	return nil
}
