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

## Video (P4)

- `media.VideoProvider` con dos implementaciones: `Bunny` (real) y `Fake`
  (desarrollo, `VIDEO_PROVIDER=fake`: reproduce un HLS público sin
  credenciales; `make dev-videos` marca las lecciones del seed como listas).
- Playback: `GET /lessons/{id}/playback` con auth opcional. Visitantes solo
  ven muestras gratis (401 si no), alumnos sin enrollment reciben 403, video
  no procesado 409. Devuelve la URL HLS firmada con TTL `PLAYBACK_TTL` (6 h).
- Firma de URLs: esquema vigente de bunny.net (`HS256-` + HMAC-SHA256, token
  de directorio `token_path=/{guid}/` para playlist y segmentos), verificada
  contra los vectores oficiales de `BunnyWay/BunnyCDN.TokenAuthentication`.
  Requiere Token Authentication activado en el pull zone de la librería.
- Upload: `POST /admin/lessons/{id}/video` crea el asset y devuelve el ticket
  TUS (endpoint + headers firmados) para que el browser suba directo.
  `POST /admin/lessons/{id}/video/sync` consulta estado y duración a mano.
- Webhook `POST /webhooks/bunny`: HMAC-SHA256 del cuerpo con la API key de
  solo lectura (`BUNNY_WEBHOOK_SECRET`), comparación en tiempo constante.
- Player (`/cursos/:slug/lecciones/:id`): hls.js (nativo en Safari), velocidad,
  autoplay de la siguiente, modo cine, sidebar de currícula. Chunk propio.

## Progreso (P5)

- `POST /lessons/{id}/heartbeat` `{seconds, tz}` cada 15 s desde el player (y
  al pausar, ocultar la pestaña o salir, con `keepalive`). Upsert con
  `GREATEST` en `lesson_progress`; completa sola al 90 % de la duración y
  refresca `course_progress`. El primer heartbeat de una lección también
  refresca el agregado para que el curso pase a "en curso".
- `POST /lessons/{id}/complete` marca manualmente. Ambos exigen enrollment
  al curso (las muestras gratis no registran progreso sin compra).
- `GET /me/courses/{slug}/progress`: agregado + posición por lección (el
  player retoma en el segundo guardado). 403 si no compró.
- `GET /me/dashboard?tz=`: "seguí donde quedaste", racha, horas de la semana,
  carreras con estado por curso, cursos sueltos. Lee solo `course_progress`
  y `daily_activity` (migración 0002: una fila por usuario y día; cada
  heartbeat suma el avance real acotado a 30 s, así un seek no infla las
  horas). Nunca agrega sobre `lesson_progress`.
- `make migrate` registra lo aplicado en `schema_migrations` y es idempotente.

## Pagos y emails (P6)

- `billing.PaymentProvider`: `MercadoPago` (Checkout Pro: preference con
  hasta 12 cuotas, `external_reference` = id de orden, `back_urls` a
  `/checkout/resultado`, webhook firmado) y `Fake` (`BILLING_PROVIDER=fake`,
  solo development: `make dev-pay ORDER=<id>` aprueba la orden).
- Precio regional interino: el catálogo está en USD; `BILLING_USD_RATE` y
  `BILLING_CURRENCY` (ARS) convierten al crear la orden. El monto queda
  fijado en la orden.
- `POST /orders` crea (o reutiliza la pending reciente) y devuelve
  `checkout_url`; `GET /orders/{id}`; `GET /me/orders`. 409 si ya tiene acceso.
- Webhook `POST /webhooks/mercadopago`: valida `x-signature`
  (`hex(HMAC-SHA256(secret, "id:{data.id};request-id:{x-request-id};ts:{ts};"))`),
  consulta `GET /v1/payments/{id}` y aplica `ApproveOrder` con
  `WHERE status = 'pending'`: reenviar N veces genera un solo enrollment.
  Una carrera da acceso a todos sus cursos por el JOIN de `access.sql`.
- `POST /admin/orders/{id}/refund`: reembolsa en el provider
  (`X-Idempotency-Key`), marca `refunded` y revoca el enrollment.
  `GET /admin/orders` lista para P7.
- `internal/mail`: Resend (`RESEND_API_KEY`) o log en development. Bienvenida
  al registrarse y confirmación de compra, asíncronos y best-effort.
- Frontend: `/checkout` (resumen + único botón), `/checkout/resultado`
  (polling de la orden hasta salir de pending), `/cuenta` (perfil y compras).

## Admin (P7)

- Contenido: `internal/catalog` (`admin_service.go`) con CRUD de carreras,
  cursos, módulos y lecciones. Reordenar recibe la lista completa de ids y
  la aplica en una transacción (las UNIQUE de posición son DEFERRABLE).
  El camino de una carrera se reemplaza entero (`PUT /admin/careers/{id}/courses`).
  Slug derivado del título si va vacío; 409 si está en uso o si se intenta
  borrar un curso que forma parte de una carrera.
- Alumnos: `internal/enrollment` — búsqueda, detalle con accesos, alta manual
  (`POST /admin/students/{id}/enrollments`, sin orden) y revocación.
- Ventas: `GET /admin/orders` + reembolso (P6).
- Video: el editor de curso sube por TUS (`tus-js-client`) con el ticket
  firmado y consulta el estado cada 5 s hasta `ready`/`failed`.
- UI en `/admin/*` (chunk propio, guard por rol): contenido, editor de
  curso, editor de carrera, ventas, alumnos. Los botones destructivos
  viven solo acá; la confirmación es un `<dialog>` con el rojo relleno.
- Tests: `testutil.Savepoint` para provocar errores de Postgres esperados
  sin abortar la transacción del test.

## Tests

`make test` crea `coffeecoder_test`, aplica migraciones y seed una vez, y
corre cada test de integración dentro de una transacción que se revierte
(`internal/testutil`). Sin `TEST_DATABASE_URL` los de integración se saltan.

## Plan de implementación

P1 fundaciones ✓ → P2 auth ✓ → P3 catálogo ✓ → P4 video ✓ → P5 progreso ✓ → P6 pagos ✓ → P7 admin ✓ →
P5 progreso → P6 pagos → P7 admin → P8 pulido UX.
