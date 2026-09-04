# CoffeeCoder

Plataforma de carreras y cursos. Monolito modular en Go + React PWA.

> **Para Claude Code:** empezá por `CLAUDE.md` (reglas del proyecto),
> `docs/SPEC.md` (especificación y fases) y `docs/DESIGN.md` (design
> system). P1 y P2 compilan y están probados; la próxima fase es P3.

## Stack

- **Backend:** Go 1.25, Chi, PostgreSQL 16, pgx/v5, sqlc v1.30
- **Frontend:** React 18 + Vite + TypeScript, Tailwind v4, TanStack Query.
  Router: **TanStack Router, code-based** (rutas tipadas en `web/src/router.tsx`, sin plugin de generación).
- **Video:** Bunny Stream (HLS + URLs firmadas), abstraído en `internal/media`
- **Pagos:** Mercado Pago (webhooks idempotentes), abstraído en `internal/billing`

## Estructura

```
cmd/api/            entry point del binario
internal/
  config/           configuración por env
  server/           router Chi, middleware, mapa de rutas
  auth/             P2 · registro, login, OAuth, JWT, RBAC
  catalog/          P3 · carreras, cursos, currícula
  media/            P4 · provider de video (Bunny), URLs firmadas
  progress/         P5 · heartbeats, completado, agregados
  enrollment/       P6 · acceso por scope (course|career)
  billing/          P6 · órdenes, Mercado Pago, webhooks
  store/            generado por sqlc (no editar a mano)
db/
  migrations/       SQL plano, aplicado en orden por make migrate
  queries/          queries fuente de sqlc
web/                React PWA (Vite)
  src/router.tsx    rutas + loaders (precargan en TanStack Query)
  src/pages/        una página por ruta
  src/components/   UI (Button fuerza la jerarquía de 4 niveles)
  src/lib/          api, queries, formato
  src/styles/       tokens.css (canónico) + index.css
```

## Desarrollo

```bash
cp .env.example .env   # ajustá HTTP_ADDR si el :8080 está ocupado
make tools      # instala sqlc en ./bin
make db-up      # Postgres 16 en Docker (puerto 5432)
make migrate    # aplica db/migrations/*.sql (solo sobre base vacía)
make sqlc       # regenera internal/store
make seed       # contenido de desarrollo (idempotente)
make run        # levanta la API (lee .env)
make web-install && make web-dev   # PWA en :5173 con proxy a la API
make help       # lista todas las tareas
```

El Makefile resuelve el toolchain solo: `GOTOOLCHAIN=auto` baja el Go
que pide `go.mod` aunque el `go` del PATH sea viejo, y
`scripts/node-path.sh` elige un Node >= 20 de nvm/Homebrew para `web/`.

## Decisiones de diseño

- **Enrollment con scope polimórfico** (`course` | `career`): comprar una
  carrera da acceso a los cursos que la carrera contenga *hoy*, resuelto
  por JOIN en tiempo de consulta (ver `db/queries/access.sql`). Agregar
  un curso a una carrera no requiere backfill.
- **`lesson_progress` es la tabla caliente** (un upsert por heartbeat del
  player); `course_progress` es el agregado materializado que lee el
  dashboard. Nunca agregar sobre la tabla caliente en requests de lectura.
- **Una orden = un producto.** Sin carrito: la carrera ya es el bundle.
  Idempotencia de webhooks por `(provider, provider_payment_id)`.
- **`video_asset_id` nunca sale por la API pública.** La reproducción
  pasa por `GET /lessons/{id}/playback`, que verifica acceso y firma.

## Auth (P2)

- Contraseñas con **argon2id** (parámetros OWASP, formato PHC autodescriptivo).
- Access token **JWT HS256** de vida corta (15 min default).
- Refresh tokens **opacos con rotación**: solo se persiste el hash sha256;
  cada refresh revoca el usado y emite uno nuevo. El reuso de un token
  revocado se trata como robo y revoca todas las sesiones del usuario.
- En web el refresh viaja en **cookie HttpOnly** (path /api/v1/auth);
  en mobile puede ir por body. El access token vive solo en memoria
  del cliente.
- **OAuth Google/GitHub** con state anti-CSRF en cookie; si el email ya
  existe, la identidad se vincula a la cuenta local.
- RBAC por middleware: `auth.Middleware` + `auth.RequireRole("admin")`.

## Plan de implementación

P1 fundaciones ✓ → P2 auth ✓ → P3 catálogo ✓ → P4 video →
P5 progreso → P6 pagos → P7 admin → P8 pulido UX.
