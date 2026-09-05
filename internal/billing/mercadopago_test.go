package billing

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/config"
)

func TestMercadoPago_CreateCheckoutAndGetPayment(t *testing.T) {
	orderID := uuid.New()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer TEST-token" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		switch r.Method + " " + r.URL.Path {
		case "POST /checkout/preferences":
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			items := body["items"].([]any)[0].(map[string]any)
			if items["unit_price"] != 66150.0 || items["currency_id"] != "ARS" || items["quantity"] != 1.0 {
				t.Errorf("item = %v", items)
			}
			if body["external_reference"] != orderID.String() {
				t.Errorf("external_reference = %v", body["external_reference"])
			}
			if body["payment_methods"].(map[string]any)["installments"] != 12.0 {
				t.Errorf("installments = %v", body["payment_methods"])
			}
			if !strings.HasPrefix(body["notification_url"].(string), "https://api.test/api/v1/webhooks/mercadopago") {
				t.Errorf("notification_url = %v", body["notification_url"])
			}
			if body["auto_return"] != "approved" || !strings.Contains(body["back_urls"].(map[string]any)["success"].(string), "estado=aprobado") {
				t.Errorf("back_urls = %v", body["back_urls"])
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"id": "pref-1", "init_point": "https://mp.test/init"})
		case "GET /v1/payments/123":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"id": 123, "status": "approved", "external_reference": orderID.String(),
				"transaction_amount": 66150, "currency_id": "ARS",
			})
		case "POST /v1/payments/123/refunds":
			if r.Header.Get("X-Idempotency-Key") == "" {
				t.Error("refund sin X-Idempotency-Key")
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"id": 9, "status": "approved"})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()

	mp := NewMercadoPago(config.MercadoPagoConfig{AccessToken: "TEST-token", WebhookSecret: "s", APIBaseURL: srv.URL}, "https://api.test", "https://front.test")
	ck, err := mp.CreateCheckout(context.Background(), CheckoutRequest{OrderID: orderID, Title: "Go", AmountCents: 6615000, Currency: "ARS", PayerEmail: "a@b.c"})
	if err != nil || ck.URL != "https://mp.test/init" || ck.ProviderRef != "pref-1" {
		t.Fatalf("checkout = %+v, %v", ck, err)
	}
	p, err := mp.GetPayment(context.Background(), "123")
	if err != nil || p.Status != PaymentApproved || p.OrderID != orderID || p.AmountCents != 6615000 || p.ID != "123" {
		t.Fatalf("payment = %+v, %v", p, err)
	}
	if err := mp.Refund(context.Background(), "123"); err != nil {
		t.Fatal(err)
	}
}

func TestMercadoPago_ParseWebhookSignature(t *testing.T) {
	mp := NewMercadoPago(config.MercadoPagoConfig{WebhookSecret: "clave-secreta"}, "", "")
	body := []byte(`{"action":"payment.updated","type":"payment","data":{"id":"123456789"}}`)
	req := func(sig string) *http.Request {
		r := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/mercadopago?data.id=123456789&type=payment", strings.NewReader(string(body)))
		r.Header.Set("x-request-id", "req-abc")
		if sig != "" {
			r.Header.Set("x-signature", sig)
		}
		return r
	}
	v1 := SignMPManifest("clave-secreta", "123456789", "req-abc", "1700000000")

	id, ok, err := mp.ParseWebhook(req("ts=1700000000,v1="+v1), body)
	if err != nil || !ok || id != "123456789" {
		t.Fatalf("firma válida: id=%q ok=%v err=%v", id, ok, err)
	}
	if _, _, err := mp.ParseWebhook(req("ts=1700000000,v1=deadbeef"), body); err == nil {
		t.Fatal("firma inválida aceptada")
	}
	if _, _, err := mp.ParseWebhook(req(""), body); err == nil {
		t.Fatal("sin firma aceptado")
	}
	// Otro tipo de evento con firma válida: se ignora sin error.
	r := httptest.NewRequest(http.MethodPost, "/x?data.id=123456789&type=merchant_order", strings.NewReader("{}"))
	r.Header.Set("x-request-id", "req-abc")
	r.Header.Set("x-signature", "ts=1700000000,v1="+v1)
	if _, ok, err := mp.ParseWebhook(r, []byte("{}")); err != nil || ok {
		t.Fatalf("merchant_order: ok=%v err=%v", ok, err)
	}
	// Manifest oficial: id:{data.id};request-id:{x-request-id};ts:{ts};
	if SignMPManifest("k", "1", "r", "2") != SignMPManifest("k", "1", "r", "2") || SignMPManifest("k", "1", "", "2") == SignMPManifest("k", "1", "r", "2") {
		t.Fatal("manifest inconsistente")
	}
}
