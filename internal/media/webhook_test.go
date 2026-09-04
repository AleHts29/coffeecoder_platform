package media

import "testing"

func TestVerifyWebhookSignature(t *testing.T) {
	body := []byte(`{"VideoLibraryId":133,"VideoGuid":"657bb740-a71b-4529-a012-528021c31a92","Status":3}`)
	sig := SignWebhookBody("read-only-key", body)

	if !VerifyWebhookSignature("read-only-key", body, sig) {
		t.Fatal("firma válida rechazada")
	}
	if VerifyWebhookSignature("otra-key", body, sig) {
		t.Fatal("firma con otra clave aceptada")
	}
	if VerifyWebhookSignature("read-only-key", append(body, ' '), sig) {
		t.Fatal("cuerpo alterado aceptado")
	}
	if VerifyWebhookSignature("", body, sig) || VerifyWebhookSignature("read-only-key", body, "") {
		t.Fatal("secreto o firma vacíos aceptados")
	}
}

func TestWebhookStatus(t *testing.T) {
	cases := map[int]AssetStatus{0: StatusProcessing, 1: StatusProcessing, 2: StatusProcessing, 3: StatusReady, 4: StatusReady, 5: StatusFailed, 6: StatusUploading, 7: StatusProcessing, 8: StatusFailed}
	for code, want := range cases {
		got, ok := WebhookStatus(code)
		if !ok || got != want {
			t.Errorf("status %d = %q, %v; want %q", code, got, ok, want)
		}
	}
	for _, code := range []int{9, 10, 99} {
		if _, ok := WebhookStatus(code); ok {
			t.Errorf("status %d debería ser informativo", code)
		}
	}
}
