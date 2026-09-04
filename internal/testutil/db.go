// Package testutil da a los tests una base Postgres real y aislada:
// aplica migraciones y seed una vez por proceso, y cada test corre en
// una transacción que se revierte al terminar.
package testutil

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	once sync.Once
	pool *pgxpool.Pool
	prep error
)

// Queries devuelve un *store.Queries sobre una transacción que se
// revierte en t.Cleanup. Si TEST_DATABASE_URL no está definida, el test
// se salta (los unitarios puros siguen corriendo).
func Queries(t *testing.T) (*store.Queries, pgx.Tx) {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL no definida: test de integración omitido (usá `make test`)")
	}

	once.Do(func() { prep = prepare(url) })
	if prep != nil {
		t.Fatalf("preparando base de tests: %v", prep)
	}

	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	t.Cleanup(func() { _ = tx.Rollback(ctx) })
	return store.New(tx), tx
}

func prepare(url string) error {
	ctx := context.Background()
	var err error
	pool, err = pgxpool.New(ctx, url)
	if err != nil {
		return err
	}

	// Migraciones pendientes según schema_migrations (mismo registro que
	// `make migrate`); el seed es idempotente y se aplica siempre.
	if _, err := pool.Exec(ctx, "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"); err != nil {
		return err
	}
	root := repoRoot()
	files, _ := filepath.Glob(filepath.Join(root, "db", "migrations", "*.sql"))
	sort.Strings(files)
	for _, f := range files {
		name := filepath.Base(f)
		var applied bool
		if err := pool.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE name = $1)", name).Scan(&applied); err != nil {
			return err
		}
		if applied {
			continue
		}
		if err := execFile(ctx, f); err != nil {
			return err
		}
		if _, err := pool.Exec(ctx, "INSERT INTO schema_migrations (name) VALUES ($1)", name); err != nil {
			return err
		}
	}
	return execFile(ctx, filepath.Join(root, "db", "seed", "dev.sql"))
}

func execFile(ctx context.Context, path string) error {
	sql, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	_, err = pool.Exec(ctx, string(sql))
	return err
}

func repoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(file), "..", "..")
}
