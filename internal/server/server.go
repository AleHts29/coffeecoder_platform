package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/config"
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

		// --- Público (P2, P3) ---
		r.Route("/auth", authHandler.Mount)

		r.Get("/careers", todo)
		r.Get("/careers/{slug}", todo)
		r.Get("/courses", todo)
		r.Get("/courses/{slug}", todo) // incluye currícula, sin asset ids

		// --- Webhooks (P6): fuera de auth de usuario, firma propia ---
		r.Post("/webhooks/mercadopago", todo)
		r.Post("/webhooks/bunny", todo)

		// --- Autenticado (P4, P5, P6) ---
		r.Group(func(r chi.Router) {
			r.Use(auth.Middleware(cfg.JWTSecret))

			r.Get("/me", todo)
			r.Get("/me/dashboard", todo) // continue-watching + progreso

			r.Get("/lessons/{id}/playback", todo) // URL firmada Bunny (P4)
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
				r.Post("/lessons/{id}/video", todo) // inicia upload a Bunny
			})
		})
	})

	return r
}

func todo(w http.ResponseWriter, _ *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
