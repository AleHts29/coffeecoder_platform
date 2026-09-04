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

	// Migraciones solo sobre base vacía (no son idempotentes); el seed sí lo es.
	var hasUsers bool
	if err := pool.QueryRow(ctx, "SELECT to_regclass('public.users') IS NOT NULL").Scan(&hasUsers); err != nil {
		return err
	}
	root := repoRoot()
	if !hasUsers {
		files, _ := filepath.Glob(filepath.Join(root, "db", "migrations", "*.sql"))
		sort.Strings(files)
		for _, f := range files {
			if err := execFile(ctx, f); err != nil {
				return err
			}
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
