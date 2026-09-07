package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/billing"
	"github.com/alejandro/coffeecoder/internal/catalog"
	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/enrollment"
	"github.com/alejandro/coffeecoder/internal/mail"
	"github.com/alejandro/coffeecoder/internal/media"
	"github.com/alejandro/coffeecoder/internal/progress"
	"github.com/alejandro/coffeecoder/internal/store"
)

// New arma el router completo. Cada módulo registra sus rutas acá;
// los handlers concretos viven en internal/<modulo> y se van
// implementando en P2..P7 según el plan.
func New(cfg config.Config, pool *pgxpool.Pool, logger *slog.Logger) (http.Handler, error) {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	catalogSvc := catalog.NewService(store.New(pool))

	r.Route("/api/v1", func(r chi.Router) {
		q := store.New(pool)
		mailer := mail.New(cfg.Mail, logger)
		authSvc := auth.NewService(cfg, q)
		authHandler := auth.NewHandler(cfg, authSvc, mailer, logger)
		catalogHandler := catalog.NewHandler(catalogSvc, logger)
		catalogAdmin := catalog.NewAdminHandler(catalog.NewAdminService(q, pool), logger)
		enrollmentAdmin := enrollment.NewHandler(enrollment.NewService(q), logger)
		mediaSvc := media.NewService(q, newVideoProvider(cfg), cfg.Video.PlaybackTTL, logger)
		mediaHandler := media.NewHandler(mediaSvc, cfg.Bunny.WebhookSecret, logger)
		progressHandler := progress.NewHandler(progress.NewService(q, logger), logger)
		billingSvc := billing.NewService(q, newPaymentProvider(cfg), mailer, cfg.Billing, cfg.FrontendURL, logger)
		billingHandler := billing.NewHandler(billingSvc, q, logger)

		// --- Público (P2, P3) ---
		r.Route("/auth", authHandler.Mount)
		catalogHandler.Mount(r) // /careers, /courses: currícula sin asset ids

		// --- Webhooks (P4, P6): fuera de auth de usuario, firma propia ---
		billingHandler.MountWebhooks(r) // /webhooks/mercadopago
		mediaHandler.MountWebhooks(r)   // /webhooks/bunny

		// --- Auth opcional (P4): muestras gratis para visitantes ---
		r.Group(func(r chi.Router) {
			r.Use(auth.OptionalMiddleware(cfg.JWTSecret))
			mediaHandler.MountPlayback(r) // /lessons/{id}/playback
		})

		// --- Autenticado (P5, P6) ---
		r.Group(func(r chi.Router) {
			r.Use(auth.Middleware(cfg.JWTSecret))

			r.Get("/me", authHandler.Me)
			progressHandler.Mount(r) // heartbeat, complete, /me/dashboard, /me/courses/{slug}/progress
			billingHandler.Mount(r)  // /orders, /orders/{id}, /me/orders
		})

		// --- Admin (P7) ---
		r.Group(func(r chi.Router) {
			r.Use(auth.Middleware(cfg.JWTSecret), auth.RequireRole("admin"))
			r.Route("/admin", func(r chi.Router) {
				catalogAdmin.Mount(r)        // CRUD carreras/cursos/módulos/lecciones + orden
				enrollmentAdmin.Mount(r)     // /students, alta y baja de enrollments
				mediaHandler.MountAdmin(r)   // /lessons/{id}/video, /video/sync
				billingHandler.MountAdmin(r) // /orders, /orders/{id}/refund
			})
		})
	})

	// PWA compilada (producción): assets + index.html con OG por producto.
	if cfg.WebDist != "" {
		if err := mountWeb(r, cfg.WebDist, cfg.FrontendURL, catalogSvc); err != nil {
			return nil, err
		}
	}

	return r, nil
}

// newVideoProvider elige la implementación según config. El resto del
// server solo conoce la interfaz.
func newVideoProvider(cfg config.Config) media.VideoProvider {
	if cfg.Video.Provider == "fake" {
		return media.NewFake(cfg.Video.FakeURL)
	}
	return media.NewBunny(cfg.Bunny)
}

func newPaymentProvider(cfg config.Config) billing.PaymentProvider {
	if cfg.Billing.Provider == "fake" {
		return billing.NewFake(cfg.FrontendURL)
	}
	return billing.NewMercadoPago(cfg.MP, cfg.PublicBaseURL, cfg.FrontendURL)
}

func todo(w http.ResponseWriter, _ *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
