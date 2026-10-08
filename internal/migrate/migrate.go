// Package migrate aplica las migraciones pendientes de db/migrations,
// en orden y una sola vez cada una (registro en schema_migrations).
// Lo usan el binario al arrancar, `api migrate` y los tests.
package migrate

import (
	"context"
	"fmt"
	"io/fs"
	"log/slog"
	"path"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"
)

// lockKey identifica el advisory lock de migraciones: dos instancias que
// arrancan juntas no aplican la misma migración dos veces.
const lockKey = 20260908

// Up aplica los *.sql de dir dentro de fsys que no estén en
// schema_migrations. Cada archivo maneja su propia transacción.
func Up(ctx context.Context, pool *pgxpool.Pool, fsys fs.FS, dir string, logger *slog.Logger) error {
	conn, err := pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()

	if _, err := conn.Exec(ctx, "SELECT pg_advisory_lock($1)", lockKey); err != nil {
		return fmt.Errorf("migrate: lock: %w", err)
	}
	defer func() { _, _ = conn.Exec(context.Background(), "SELECT pg_advisory_unlock($1)", lockKey) }()

	if _, err := conn.Exec(ctx, "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"); err != nil {
		return fmt.Errorf("migrate: schema_migrations: %w", err)
	}

	names, err := fs.Glob(fsys, path.Join(dir, "*.sql"))
	if err != nil {
		return err
	}
	sort.Strings(names)
	for _, f := range names {
		name := path.Base(f)
		var applied bool
		if err := conn.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE name = $1)", name).Scan(&applied); err != nil {
			return err
		}
		if applied {
			continue
		}
		sql, err := fs.ReadFile(fsys, f)
		if err != nil {
			return err
		}
		// Sin argumentos pgx usa el protocolo simple: el archivo entero,
		// con varias sentencias y su BEGIN/COMMIT, va en un solo Exec.
		if _, err := conn.Exec(ctx, string(sql)); err != nil {
			return fmt.Errorf("migrate: %s: %w", name, err)
		}
		if _, err := conn.Exec(ctx, "INSERT INTO schema_migrations (name) VALUES ($1)", name); err != nil {
			return err
		}
		logger.Info("migración aplicada", "name", name)
	}
	return nil
}
