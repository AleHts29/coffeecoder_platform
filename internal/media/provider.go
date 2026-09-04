// Package media abstrae al proveedor de video. El dominio habla con
// VideoProvider; Bunny (o un fake de desarrollo) son detalles
// intercambiables detrás de la interfaz.
package media

import (
	"context"
	"time"
)

// AssetStatus es el estado del asset según el provider, ya normalizado
// al vocabulario de la base (lessons.video_status).
type AssetStatus string

const (
	StatusUploading  AssetStatus = "uploading"
	StatusProcessing AssetStatus = "processing"
	StatusReady      AssetStatus = "ready"
	StatusFailed     AssetStatus = "failed"
)

// AssetInfo es lo que el dominio necesita saber de un asset remoto.
type AssetInfo struct {
	Status    AssetStatus
	DurationS int32
}

// UploadTicket son las credenciales de corta vida para que el browser
// del admin suba el archivo directo al provider (TUS resumable).
type UploadTicket struct {
	Endpoint  string            `json:"endpoint"`
	Headers   map[string]string `json:"headers"`
	ExpiresAt time.Time         `json:"expires_at"`
}

type VideoProvider interface {
	// Name identifica al provider tal como se persiste en
	// lessons.video_provider ('bunny', ...).
	Name() string

	// CreateVideo registra un asset vacío y devuelve su id externo.
	CreateVideo(ctx context.Context, title string) (assetID string, err error)

	// UploadTicket devuelve endpoint y headers para el upload TUS del
	// asset, válidos por ttl.
	UploadTicket(assetID string, ttl time.Duration) (UploadTicket, error)

	// GetAsset consulta estado y duración del asset.
	GetAsset(ctx context.Context, assetID string) (AssetInfo, error)

	// SignedPlaybackURL devuelve la URL HLS firmada, válida por ttl,
	// para un asset ya transcodificado.
	SignedPlaybackURL(assetID string, ttl time.Duration) (string, error)
}
