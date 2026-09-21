package content

import (
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestFrameURLRoundTrip(t *testing.T) {
	const secret = "clave-de-firma"
	id := uuid.New()
	now := time.Now()

	raw := FrameURL(secret, id, now)
	if !strings.HasPrefix(raw, "/api/v1/demos/"+id.String()+"/frame?") {
		t.Fatalf("URL inesperada: %s", raw)
	}
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	exp, sig := u.Query().Get("exp"), u.Query().Get("sig")

	if !VerifyFrame(secret, id, exp, sig, now) {
		t.Fatal("firma válida rechazada")
	}
	if VerifyFrame("otra-clave", id, exp, sig, now) {
		t.Fatal("firma aceptada con otra clave")
	}
	if VerifyFrame(secret, uuid.New(), exp, sig, now) {
		t.Fatal("firma de una demo sirvió para otra")
	}
	if VerifyFrame(secret, id, exp, sig[:len(sig)-2]+"xx", now) {
		t.Fatal("firma alterada aceptada")
	}
	if VerifyFrame(secret, id, exp, sig, now.Add(FrameTTL+time.Minute)) {
		t.Fatal("firma vencida aceptada")
	}
	// Extender la expiración a mano invalida la firma.
	if VerifyFrame(secret, id, "99999999999", sig, now) {
		t.Fatal("exp manipulada aceptada")
	}
	if VerifyFrame(secret, id, "no-es-un-numero", sig, now) {
		t.Fatal("exp inválida aceptada")
	}
}
