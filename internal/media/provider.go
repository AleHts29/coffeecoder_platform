// Package media abstrae al proveedor de video. El dominio habla con
// VideoProvider; Bunny, Mux o Cloudflare son detalles intercambiables.
package media

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/alejandro/coffeecoder/internal/config"
)

type VideoProvider interface {
	// CreateVideo registra un asset y devuelve su id externo más la URL
	// de upload (TUS o PUT según provider).
	CreateVideo(ctx context.Context, title string) (assetID, uploadURL string, err error)

	// SignedPlaybackURL devuelve la URL HLS firmada, válida por ttl,
	// para un asset ya transcodificado.
	SignedPlaybackURL(assetID string, ttl time.Duration) (string, error)
}

// Bunny implementa VideoProvider sobre Bunny Stream.
type Bunny struct {
	cfg config.BunnyConfig
}

func NewBunny(cfg config.BunnyConfig) *Bunny {
	return &Bunny{cfg: cfg}
}

func (b *Bunny) CreateVideo(ctx context.Context, title string) (string, string, error) {
	// P4: POST https://video.bunnycdn.com/library/{LibraryID}/videos
	// con AccessKey b.cfg.APIKey; devuelve guid → assetID y la URL TUS.
	return "", "", fmt.Errorf("media: CreateVideo no implementado (P4)")
}

// SignedPlaybackURL implementa el esquema de token auth de Bunny:
// token = base64url( sha256( tokenKey + path + expires ) )
// URL final: https://{cdn}/{assetID}/playlist.m3u8?token={t}&expires={e}
func (b *Bunny) SignedPlaybackURL(assetID string, ttl time.Duration) (string, error) {
	if b.cfg.TokenAuthKey == "" || b.cfg.CDNHostname == "" {
		return "", fmt.Errorf("media: configuración de Bunny incompleta")
	}
	path := fmt.Sprintf("/%s/playlist.m3u8", assetID)
	expires := time.Now().Add(ttl).Unix()

	h := sha256.Sum256([]byte(fmt.Sprintf("%s%s%d", b.cfg.TokenAuthKey, path, expires)))
	token := base64.URLEncoding.EncodeToString(h[:])
	token = strings.TrimRight(token, "=")

	return fmt.Sprintf("https://%s%s?token=%s&expires=%d",
		b.cfg.CDNHostname, path, token, expires), nil
}
