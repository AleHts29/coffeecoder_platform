# CoffeeCoder — tareas de desarrollo.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# --- Toolchain --------------------------------------------------------------
# GOTOOLCHAIN=auto hace que cualquier Go >= 1.21 del PATH baje y use la version
# que pide go.mod. Asi el proyecto no depende de que gvm apunte al Go correcto.
# GOROOT queda fuera del entorno por el mismo motivo.
export GOTOOLCHAIN := auto
unexport GOROOT

GO           := go
BIN          := $(CURDIR)/bin
SQLC         := $(BIN)/sqlc
SQLC_VERSION := v1.30.0

# Node: si el del PATH es viejo, se usa uno mas nuevo de nvm/homebrew.
NODE_BIN := $(shell ./scripts/node-path.sh)
WEB_PATH := $(if $(NODE_BIN),$(NODE_BIN):$(PATH),$(PATH))
NPM      := PATH="$(WEB_PATH)" npm --prefix web

# --- Config -----------------------------------------------------------------
DB_URL      ?= postgres://coffee:coffee@localhost:5432/coffeecoder?sslmode=disable
TEST_DB_URL ?= postgres://coffee:coffee@localhost:5432/coffeecoder_test?sslmode=disable
ENV_FILE := .env
# Carga .env en el entorno de las recetas que lo necesitan.
LOAD_ENV := set -a && [ -f $(ENV_FILE) ] && source $(ENV_FILE); set +a

.PHONY: help
help: ## Lista las tareas
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-14s %s\n", $$1, $$2}'

.PHONY: tools
tools: $(SQLC) ## Instala sqlc en ./bin

$(SQLC):
	GOBIN=$(BIN) $(GO) install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)

.PHONY: db-up
db-up: ## Levanta Postgres 16 en Docker
	docker compose up -d db

.PHONY: db-down
db-down: ## Baja Postgres
	docker compose down

.PHONY: migrate
migrate: ## Aplica las migraciones pendientes (registro en schema_migrations)
	@$(MAKE) -s migrate-url URL="$(DB_URL)"

.PHONY: migrate-url
migrate-url:
	@psql "$(URL)" -q -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
	@for f in db/migrations/*.sql; do \
		n=$$(basename $$f); \
		if psql "$(URL)" -Atc "SELECT 1 FROM schema_migrations WHERE name='$$n'" | grep -q 1; then continue; fi; \
		echo "==> $$n"; \
		psql "$(URL)" -q -v ON_ERROR_STOP=1 -f $$f && psql "$(URL)" -q -c "INSERT INTO schema_migrations (name) VALUES ('$$n')"; \
	done

.PHONY: seed
seed: ## Carga contenido de desarrollo (db/seed/dev.sql, idempotente)
	psql "$(DB_URL)" -v ON_ERROR_STOP=1 -q -f db/seed/dev.sql

.PHONY: sqlc
sqlc: $(SQLC) ## Regenera internal/store desde db/queries
	$(SQLC) generate

.PHONY: build
build: ## Compila todo
	$(GO) build ./...

.PHONY: run
run: ## Levanta la API (HTTP_ADDR de .env)
	@$(LOAD_ENV); $(GO) run ./cmd/api

.PHONY: test-db
test-db: ## Crea la base de tests (coffeecoder_test) si no existe
	@psql "$(DB_URL)" -Atc "SELECT 1 FROM pg_database WHERE datname='coffeecoder_test'" | grep -q 1 || \
		psql "$(DB_URL)" -c "CREATE DATABASE coffeecoder_test"

.PHONY: test
test: test-db ## Tests (unitarios + integración contra coffeecoder_test)
	@$(MAKE) -s migrate-url URL="$(TEST_DB_URL)"
	@TEST_DATABASE_URL="$(TEST_DB_URL)" $(GO) test ./...

.PHONY: dev-videos
dev-videos: ## Marca las lecciones del seed como 'ready' con assets fake (VIDEO_PROVIDER=fake)
	psql "$(DB_URL)" -Atc "UPDATE lessons SET video_provider='bunny', video_asset_id='fake-'||id, video_status='ready' WHERE video_asset_id IS NULL"

.PHONY: vet
vet: ## go vet
	$(GO) vet ./...

.PHONY: dev
dev: db-up migrate sqlc run ## db-up + migrate + sqlc + run

# --- Frontend ---------------------------------------------------------------
.PHONY: web-install
web-install: ## Instala dependencias de web/
	$(NPM) install --no-audit --no-fund

.PHONY: web-dev
web-dev: ## Vite en :5173 con proxy /api → API local
	$(NPM) run dev

.PHONY: web-build
web-build: ## Typecheck + build de producción en web/dist
	$(NPM) run build

.PHONY: web-typecheck
web-typecheck: ## Solo tsc
	$(NPM) run typecheck
