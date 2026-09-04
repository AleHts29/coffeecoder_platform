package media

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Fake es el provider de desarrollo y tests: no habla con nadie,
// reproduce siempre la misma URL HLS pública y marca los assets como
// ready al consultarlos. Se persiste como 'bunny' para respetar el
// CHECK de video_provider sin sumar un valor de mentira al esquema.
type Fake struct {
	URL string

	mu     sync.Mutex
	assets map[string]AssetInfo
}

func NewFake(url string) *Fake {
	return &Fake{URL: url, assets: map[string]AssetInfo{}}
}

func (f *Fake) Name() string { return "bunny" }

func (f *Fake) CreateVideo(_ context.Context, _ string) (string, error) {
	id := "fake-" + uuid.NewString()
	f.mu.Lock()
	f.assets[id] = AssetInfo{Status: StatusReady, DurationS: 600}
	f.mu.Unlock()
	return id, nil
}

func (f *Fake) UploadTicket(assetID string, ttl time.Duration) (UploadTicket, error) {
	return UploadTicket{
		Endpoint:  "fake://upload",
		Headers:   map[string]string{"VideoId": assetID},
		ExpiresAt: time.Now().Add(ttl),
	}, nil
}

// GetAsset: los assets creados por el fake son ready con 10 min; los
// que vienen de `make dev-videos` (fake-<uuid de lección>) también.
func (f *Fake) GetAsset(_ context.Context, assetID string) (AssetInfo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if info, ok := f.assets[assetID]; ok {
		return info, nil
	}
	return AssetInfo{Status: StatusReady, DurationS: 600}, nil
}

func (f *Fake) SignedPlaybackURL(assetID string, ttl time.Duration) (string, error) {
	if f.URL == "" {
		return "", fmt.Errorf("media: FAKE_VIDEO_URL vacía")
	}
	return fmt.Sprintf("%s#asset=%s&expires=%d", f.URL, assetID, time.Now().Add(ttl).Unix()), nil
}
