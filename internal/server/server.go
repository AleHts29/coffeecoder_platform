package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/catalog"
	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/media"
	"github.com/alejandro/coffeecoder/internal/store"
)

// New arma el router completo. Cada módulo registra sus rutas acá;
// los handlers concretos viven en internal/<modulo> y se van
// implementando en P2..P7 según el plan.
func New(cfg config.Config, pool *pgxpool.Pool, logger *slog.Logger) http.Handler {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	r.Route("/api/v1", func(r chi.Router) {
		q := store.New(pool)
		authSvc := auth.NewService(cfg, q)
		authHandler := auth.NewHandler(cfg, authSvc, logger)
		catalogHandler := catalog.NewHandler(catalog.NewService(q), logger)
		mediaSvc := media.NewService(q, newVideoProvider(cfg), cfg.Video.PlaybackTTL, logger)
		mediaHandler := media.NewHandler(mediaSvc, cfg.Bunny.WebhookSecret, logger)

		// --- Público (P2, P3) ---
		r.Route("/auth", authHandler.Mount)
		catalogHandler.Mount(r) // /careers, /courses: currícula sin asset ids

		// --- Webhooks (P4, P6): fuera de auth de usuario, firma propia ---
		r.Post("/webhooks/mercadopago", todo)
		mediaHandler.MountWebhooks(r) // /webhooks/bunny

		// --- Auth opcional (P4): muestras gratis para visitantes ---
		r.Group(func(r chi.Router) {
			r.Use(auth.OptionalMiddleware(cfg.JWTSecret))
			mediaHandler.MountPlayback(r) // /lessons/{id}/playback
		})

		// --- Autenticado (P5, P6) ---
		r.Group(func(r chi.Router) {
			r.Use(auth.Middleware(cfg.JWTSecret))

			r.Get("/me", authHandler.Me)
			r.Get("/me/dashboard", todo) // continue-watching + progreso

			r.Post("/lessons/{id}/heartbeat", todo)
			r.Post("/lessons/{id}/complete", todo)

			r.Post("/orders", todo) // crea orden + preference de MP
			r.Get("/orders/{id}", todo)
		})

		// --- Admin (P7) ---
		r.Group(func(r chi.Router) {
			r.Use(auth.Middleware(cfg.JWTSecret), auth.RequireRole("admin"))
			r.Route("/admin", func(r chi.Router) {
				r.Post("/careers", todo)
				r.Post("/courses", todo)
				r.Post("/courses/{id}/modules", todo)
				r.Post("/modules/{id}/lessons", todo)
				mediaHandler.MountAdmin(r) // /lessons/{id}/video, /video/sync
			})
		})
	})

	return r
}

// newVideoProvider elige la implementación según config. El resto del
// server solo conoce la interfaz.
func newVideoProvider(cfg config.Config) media.VideoProvider {
	if cfg.Video.Provider == "fake" {
		return media.NewFake(cfg.Video.FakeURL)
	}
	return media.NewBunny(cfg.Bunny)
}

func todo(w http.ResponseWriter, _ *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
