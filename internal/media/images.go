package media

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/alejandro/coffeecoder/internal/config"
)

// MaxImageBytes: tope de una imagen de artículo.
const MaxImageBytes = 5 << 20

var imageExt = map[string]string{
	"image/jpeg":    ".jpg",
	"image/png":     ".png",
	"image/webp":    ".webp",
	"image/gif":     ".gif",
	"image/avif":    ".avif",
	"image/svg+xml": ".svg",
}

// ImageStore guarda las imágenes que el admin pega en un artículo. No
// llevan URL firmada: van por CDN con nombre aleatorio (limitación
// conocida, documentada en ESTADO.md).
type ImageStore interface {
	Put(ctx context.Context, data []byte, contentType string) (url string, err error)
}

// randomName evita adivinar URLs de imágenes de cursos pagos.
func randomName(contentType string) (string, error) {
	ext, ok := imageExt[strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))]
	if !ok {
		return "", fmt.Errorf("media: tipo de imagen no soportado (%s)", contentType)
	}
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return time.Now().UTC().Format("2006/01/") + hex.EncodeToString(buf) + ext, nil
}

// BunnyStorage sube a una storage zone de Bunny y devuelve la URL del
// pull zone público.
type BunnyStorage struct {
	cfg  config.ImageConfig
	http *http.Client
}

func NewBunnyStorage(cfg config.ImageConfig) *BunnyStorage {
	return &BunnyStorage{cfg: cfg, http: &http.Client{Timeout: 30 * time.Second}}
}

func (b *BunnyStorage) Put(ctx context.Context, data []byte, contentType string) (string, error) {
	if b.cfg.StorageZone == "" || b.cfg.StorageKey == "" || b.cfg.PublicBaseURL == "" {
		return "", fmt.Errorf("media: configuración de Bunny Storage incompleta")
	}
	name, err := randomName(contentType)
	if err != nil {
		return "", err
	}
	endpoint := fmt.Sprintf("https://%s/%s/%s", b.cfg.StorageHost, b.cfg.StorageZone, name)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	req.Header.Set("AccessKey", b.cfg.StorageKey)
	req.Header.Set("Content-Type", contentType)

	res, err := b.http.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
		return "", fmt.Errorf("media: Bunny Storage HTTP %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	return strings.TrimRight(b.cfg.PublicBaseURL, "/") + "/" + name, nil
}

// LocalStore guarda en disco y sirve desde el propio binario (/uploads).
// Solo desarrollo: en producción se usa Bunny Storage.
type LocalStore struct {
	dir string
}

func NewLocalStore(dir string) *LocalStore { return &LocalStore{dir: dir} }

func (l *LocalStore) Dir() string { return l.dir }

func (l *LocalStore) Put(_ context.Context, data []byte, contentType string) (string, error) {
	name, err := randomName(contentType)
	if err != nil {
		return "", err
	}
	full := filepath.Join(l.dir, filepath.FromSlash(name))
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(full, data, 0o644); err != nil {
		return "", err
	}
	return "/uploads/" + path.Clean(name), nil
}

// NewImageStore elige la implementación según config.
func NewImageStore(cfg config.ImageConfig) ImageStore {
	if cfg.Provider == "local" {
		return NewLocalStore(cfg.LocalDir)
	}
	return NewBunnyStorage(cfg)
}
