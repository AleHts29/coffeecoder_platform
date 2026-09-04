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
	Bunny BunnyConfig
	MP    MercadoPagoConfig
}

type OAuthConfig struct {
	GoogleClientID     string
	GoogleClientSecret string
	GitHubClientID     string
	GitHubClientSecret string
}

type BunnyConfig struct {
	LibraryID    string
	APIKey       string
	TokenAuthKey string
	CDNHostname  string
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
		Bunny: BunnyConfig{
			LibraryID:    os.Getenv("BUNNY_LIBRARY_ID"),
			APIKey:       os.Getenv("BUNNY_API_KEY"),
			TokenAuthKey: os.Getenv("BUNNY_TOKEN_AUTH_KEY"),
			CDNHostname:  os.Getenv("BUNNY_CDN_HOSTNAME"),
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
