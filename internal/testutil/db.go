// Package testutil da a los tests una base Postgres real y aislada:
// aplica migraciones y seed una vez por proceso, y cada test corre en
// una transacción que se revierte al terminar.
package testutil

import (
	"context"
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/db"
	"github.com/alejandro/coffeecoder/internal/migrate"
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

	// Mismas migraciones que aplica el binario al arrancar; el seed es
	// idempotente y se aplica siempre.
	if err := migrate.Up(ctx, pool, db.Migrations, "migrations", slog.Default()); err != nil {
		return err
	}
	root := repoRoot()
	for _, f := range []string{"dev.sql", "articles.sql", "curso-produccion-musical.sql"} {
		if err := execFile(ctx, filepath.Join(root, "db", "seed", f)); err != nil {
			return err
		}
	}
	return nil
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

// Savepoint corre fn en una transacción anidada que siempre se revierte.
// Sirve para provocar errores de Postgres esperados (unique, FK) sin
// abortar la transacción del test.
func Savepoint(t *testing.T, tx pgx.Tx, fn func(q *store.Queries)) {
	t.Helper()
	ctx := context.Background()
	sp, err := tx.Begin(ctx)
	if err != nil {
		t.Fatalf("savepoint: %v", err)
	}
	defer func() { _ = sp.Rollback(ctx) }()
	fn(store.New(sp))
}
