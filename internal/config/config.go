package config

import (
	"fmt"
	"os"
	"time"
)

type Config struct {
	Env           string
	HTTPAddr      string
	DatabaseURL   string
	PublicBaseURL string // URL pública de la API (para callbacks OAuth)
	FrontendURL   string // URL de la PWA (para redirects post-login)

	JWTSecret       string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	OAuth OAuthConfig
	Video VideoConfig
	Bunny BunnyConfig
	MP    MercadoPagoConfig
}

// VideoConfig elige la implementación de media.VideoProvider.
// "bunny" en producción; "fake" para desarrollo sin credenciales
// (reproduce FakeURL, un HLS público, para probar el player).
type VideoConfig struct {
	Provider    string // bunny | fake
	FakeURL     string
	PlaybackTTL time.Duration
}

type OAuthConfig struct {
	GoogleClientID     string
	GoogleClientSecret string
	GitHubClientID     string
	GitHubClientSecret string
}

type BunnyConfig struct {
	LibraryID     string
	APIKey        string // API key de la librería (escritura): crear videos, TUS
	WebhookSecret string // API key de solo lectura: firma HMAC de los webhooks
	TokenAuthKey  string // Token Authentication Key del pull zone
	CDNHostname   string // vz-xxxx.b-cdn.net
	APIBaseURL    string // override para tests
}

type MercadoPagoConfig struct {
	AccessToken   string
	WebhookSecret string
}

func Load() (Config, error) {
	cfg := Config{
		Env:           getenv("APP_ENV", "development"),
		HTTPAddr:      getenv("HTTP_ADDR", ":8080"),
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		PublicBaseURL: getenv("PUBLIC_BASE_URL", "http://localhost:8080"),
		FrontendURL:   getenv("FRONTEND_URL", "http://localhost:5173"),
		JWTSecret:     os.Getenv("JWT_SECRET"),
		OAuth: OAuthConfig{
			GoogleClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
			GoogleClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
			GitHubClientID:     os.Getenv("GITHUB_CLIENT_ID"),
			GitHubClientSecret: os.Getenv("GITHUB_CLIENT_SECRET"),
		},
		Video: VideoConfig{
			Provider: getenv("VIDEO_PROVIDER", "bunny"),
			FakeURL:  getenv("FAKE_VIDEO_URL", "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"),
		},
		Bunny: BunnyConfig{
			LibraryID:     os.Getenv("BUNNY_LIBRARY_ID"),
			APIKey:        os.Getenv("BUNNY_API_KEY"),
			WebhookSecret: os.Getenv("BUNNY_WEBHOOK_SECRET"),
			TokenAuthKey:  os.Getenv("BUNNY_TOKEN_AUTH_KEY"),
			CDNHostname:   os.Getenv("BUNNY_CDN_HOSTNAME"),
			APIBaseURL:    getenv("BUNNY_API_BASE_URL", "https://video.bunnycdn.com"),
		},
		MP: MercadoPagoConfig{
			AccessToken:   os.Getenv("MP_ACCESS_TOKEN"),
			WebhookSecret: os.Getenv("MP_WEBHOOK_SECRET"),
		},
	}

	var err error
	if cfg.AccessTokenTTL, err = parseDuration("ACCESS_TOKEN_TTL", 15*time.Minute); err != nil {
		return cfg, err
	}
	if cfg.RefreshTokenTTL, err = parseDuration("REFRESH_TOKEN_TTL", 30*24*time.Hour); err != nil {
		return cfg, err
	}
	if cfg.Video.PlaybackTTL, err = parseDuration("PLAYBACK_TTL", 6*time.Hour); err != nil {
		return cfg, err
	}
	if cfg.Video.Provider != "bunny" && cfg.Video.Provider != "fake" {
		return cfg, fmt.Errorf("VIDEO_PROVIDER inválido: %q (bunny | fake)", cfg.Video.Provider)
	}
	if cfg.Env != "development" && cfg.Video.Provider == "fake" {
		return cfg, fmt.Errorf("VIDEO_PROVIDER=fake solo se permite en development")
	}

	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL es requerida")
	}
	if cfg.Env != "development" && cfg.JWTSecret == "" {
		return cfg, fmt.Errorf("JWT_SECRET es requerida fuera de development")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDuration(key string, fallback time.Duration) (time.Duration, error) {
	v := os.Getenv(key)
	if v == "" {
		return fallback, nil
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return 0, fmt.Errorf("%s inválida: %w", key, err)
	}
	return d, nil
}
