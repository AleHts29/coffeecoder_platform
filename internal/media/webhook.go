package media

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
)

// WebhookEvent es el cuerpo del webhook de Bunny Stream.
type WebhookEvent struct {
	VideoLibraryID int64  `json:"VideoLibraryId"`
	VideoGUID      string `json:"VideoGuid"`
	Status         int    `json:"Status"`
}

// Códigos de Status del webhook (distintos a los del GET video).
const (
	whQueued                 = 0
	whProcessing             = 1
	whEncoding               = 2
	whFinished               = 3
	whResolutionFinished     = 4
	whFailed                 = 5
	whPresignedUploadStarted = 6
	whPresignedUploadDone    = 7
	whPresignedUploadFailed  = 8
)

// WebhookStatus normaliza el código del webhook. ok=false para eventos
// informativos que no cambian el estado (captions, títulos generados).
func WebhookStatus(code int) (AssetStatus, bool) {
	switch code {
	case whPresignedUploadStarted:
		return StatusUploading, true
	case whQueued, whProcessing, whEncoding, whPresignedUploadDone:
		return StatusProcessing, true
	case whFinished, whResolutionFinished:
		return StatusReady, true
	case whFailed, whPresignedUploadFailed:
		return StatusFailed, true
	default:
		return "", false
	}
}

// VerifyWebhookSignature valida X-BunnyStream-Signature:
// lowercase hex de HMAC-SHA256(rawBody) con la API key de solo lectura
// de la librería como secreto. Comparación en tiempo constante.
func VerifyWebhookSignature(secret string, rawBody []byte, signature string) bool {
	if secret == "" || signature == "" {
		return false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	expected := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signature))
}

// SignWebhookBody genera la firma tal como la produce Bunny (para tests
// y para reenviar eventos a mano en desarrollo).
func SignWebhookBody(secret string, rawBody []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	return hex.EncodeToString(mac.Sum(nil))
}

func ParseWebhook(rawBody []byte) (WebhookEvent, error) {
	var ev WebhookEvent
	if err := json.Unmarshal(rawBody, &ev); err != nil {
		return ev, fmt.Errorf("media: webhook JSON inválido: %w", err)
	}
	if ev.VideoGUID == "" {
		return ev, fmt.Errorf("media: webhook sin VideoGuid")
	}
	return ev, nil
}
