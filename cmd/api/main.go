package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/db"
	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/migrate"
	"github.com/alejandro/coffeecoder/internal/server"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	// `api migrate`: solo aplica migraciones y sale. Necesita únicamente
	// DATABASE_URL, no la config completa del server.
	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		if err := runMigrate(logger); err != nil {
			logger.Error("migrate", "err", err)
			os.Exit(1)
		}
		return
	}

	cfg, err := config.Load()
	if err != nil {
		logger.Error("config", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("db connect", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		logger.Error("db ping", "err", err)
		os.Exit(1)
	}

	// Las migraciones van antes de servir: si una falla, el proceso no
	// levanta y el deploy anterior sigue atendiendo.
	if err := migrate.Up(ctx, pool, db.Migrations, "migrations", logger); err != nil {
		logger.Error("migrate", "err", err)
		os.Exit(1)
	}

	handler, err := server.New(cfg, pool, logger)
	if err != nil {
		logger.Error("server", "err", err)
		os.Exit(1)
	}

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		logger.Info("http server listening", "addr", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

func runMigrate(logger *slog.Logger) error {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return errors.New("DATABASE_URL es requerida")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return err
	}
	defer pool.Close()
	return migrate.Up(ctx, pool, db.Migrations, "migrations", logger)
}
