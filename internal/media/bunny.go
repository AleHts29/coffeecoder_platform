package media

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/alejandro/coffeecoder/internal/config"
)

// Bunny implementa VideoProvider sobre Bunny Stream.
// Referencias (docs vigentes al 2026-09-04):
//   - crear video:  POST {api}/library/{lib}/videos  {title}  → guid
//   - TUS:          https://video.bunnycdn.com/tusupload con headers
//     AuthorizationSignature = sha256hex(lib + apiKey + expire + videoId)
//   - get video:    GET {api}/library/{lib}/videos/{guid} → status, length
//   - playback:     https://{cdn}/{guid}/playlist.m3u8 con token de pull zone
type Bunny struct {
	cfg    config.BunnyConfig
	http   *http.Client
	tusURL string
}

func NewBunny(cfg config.BunnyConfig) *Bunny {
	return &Bunny{
		cfg:    cfg,
		http:   &http.Client{Timeout: 15 * time.Second},
		tusURL: "https://video.bunnycdn.com/tusupload",
	}
}

func (b *Bunny) Name() string { return "bunny" }

func (b *Bunny) CreateVideo(ctx context.Context, title string) (string, error) {
	if b.cfg.LibraryID == "" || b.cfg.APIKey == "" {
		return "", fmt.Errorf("media: configuración de Bunny incompleta (library id / api key)")
	}
	body, _ := json.Marshal(map[string]string{"title": title})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		fmt.Sprintf("%s/library/%s/videos", b.cfg.APIBaseURL, b.cfg.LibraryID), bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("AccessKey", b.cfg.APIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	var out struct {
		GUID string `json:"guid"`
	}
	if err := b.do(req, &out); err != nil {
		return "", fmt.Errorf("media: creando video en Bunny: %w", err)
	}
	if out.GUID == "" {
		return "", fmt.Errorf("media: Bunny no devolvió guid")
	}
	return out.GUID, nil
}

func (b *Bunny) UploadTicket(assetID string, ttl time.Duration) (UploadTicket, error) {
	if b.cfg.LibraryID == "" || b.cfg.APIKey == "" {
		return UploadTicket{}, fmt.Errorf("media: configuración de Bunny incompleta (library id / api key)")
	}
	expires := time.Now().Add(ttl)
	sig := sha256.Sum256([]byte(fmt.Sprintf("%s%s%d%s", b.cfg.LibraryID, b.cfg.APIKey, expires.Unix(), assetID)))
	return UploadTicket{
		Endpoint: b.tusURL,
		Headers: map[string]string{
			"AuthorizationSignature": hex.EncodeToString(sig[:]),
			"AuthorizationExpire":    fmt.Sprintf("%d", expires.Unix()),
			"VideoId":                assetID,
			"LibraryId":              b.cfg.LibraryID,
		},
		ExpiresAt: expires,
	}, nil
}

// bunnyVideoStatus según la API de Bunny Stream (GET video → status).
const (
	bunnyCreated      = 0
	bunnyUploaded     = 1
	bunnyProcessing   = 2
	bunnyTranscoding  = 3
	bunnyFinished     = 4
	bunnyError        = 5
	bunnyUploadFailed = 6
)

func (b *Bunny) GetAsset(ctx context.Context, assetID string) (AssetInfo, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		fmt.Sprintf("%s/library/%s/videos/%s", b.cfg.APIBaseURL, b.cfg.LibraryID, assetID), nil)
	if err != nil {
		return AssetInfo{}, err
	}
	req.Header.Set("AccessKey", b.cfg.APIKey)
	req.Header.Set("Accept", "application/json")

	var out struct {
		Status int   `json:"status"`
		Length int32 `json:"length"`
	}
	if err := b.do(req, &out); err != nil {
		return AssetInfo{}, fmt.Errorf("media: consultando video en Bunny: %w", err)
	}

	info := AssetInfo{DurationS: out.Length}
	switch out.Status {
	case bunnyCreated:
		info.Status = StatusUploading
	case bunnyUploaded, bunnyProcessing, bunnyTranscoding:
		info.Status = StatusProcessing
	case bunnyFinished:
		info.Status = StatusReady
	case bunnyError, bunnyUploadFailed:
		info.Status = StatusFailed
	default:
		// 7 JitSegmenting, 8 JitPlaylistsCreated: reproducible.
		info.Status = StatusReady
	}
	return info, nil
}

// SignedPlaybackURL firma el playlist HLS con token de directorio
// (token_path=/{guid}/) para que el playlist y sus segmentos compartan
// la misma firma. Requiere Token Authentication activado en el pull
// zone de la librería.
func (b *Bunny) SignedPlaybackURL(assetID string, ttl time.Duration) (string, error) {
	if b.cfg.TokenAuthKey == "" || b.cfg.CDNHostname == "" {
		return "", fmt.Errorf("media: configuración de Bunny incompleta (token key / cdn hostname)")
	}
	raw := fmt.Sprintf("https://%s/%s/playlist.m3u8", b.cfg.CDNHostname, assetID)
	return SignCDNURL(raw, b.cfg.TokenAuthKey, time.Now().Add(ttl).Unix(), "/"+assetID+"/")
}

func (b *Bunny) do(req *http.Request, out any) error {
	res, err := b.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf("HTTP %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return json.Unmarshal(body, out)
}
