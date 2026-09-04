# CLAUDE.md — CoffeeCoder

Plataforma de carreras y cursos de programación. Marca: CoffeeCoder.
Un solo instructor (Alejandro), compra única por curso o carrera, video
grabado. Este archivo define las reglas del proyecto; la especificación
funcional completa está en `docs/SPEC.md` y el design system en
`docs/DESIGN.md`. **Leé los tres antes de escribir código.**

## Estado actual

- `db/migrations/0001_init.sql` está **validado contra PostgreSQL 16
  real** (migración + smoke tests de los flujos críticos). Es canónico:
  no lo reescribas ni "mejores" — extendelo con nuevas migraciones.
- `db/queries/*.sql` fueron validadas con `sqlc generate` v1.30
  (`make sqlc` usa el binario de `./bin`, instalado por `make tools`).
- `internal/` tiene P1 y P2 **compilados y probados** (2026-09-04):
  `go build ./...` y `go vet` limpios, y el flujo de auth verificado
  contra Postgres real (registro, login, refresh rotado, reuso revoca
  la familia, RBAC, cookie HttpOnly). Faltan los tests de service de P2.
  Tratá el código existente como diseño aprobado, no como borrador:
  mantené su estructura y decisiones, arreglá solo errores.
- El frontend (`web/`) no existe aún salvo `web/src/styles/tokens.css`,
  que es el design system canónico en formato Tailwind v4.

## Stack (fijo, no proponer alternativas)

- **Backend:** Go 1.23+, Chi v5, PostgreSQL 16, pgx/v5, sqlc.
  Monolito modular: un binario, módulos en `internal/` con límites
  claros. No microservicios, no ORMs, no frameworks adicionales.
- **Frontend:** React 18 + Vite + TypeScript, Tailwind CSS v4,
  TanStack Query. Router: TanStack Router o React Router, elegí uno y
  documentalo en una línea en el README.
- **Video:** Bunny Stream vía la interfaz `media.VideoProvider`.
  El dominio nunca conoce a Bunny directamente.
- **Pagos:** Mercado Pago primero; Stripe después detrás de la misma
  abstracción de `billing`.
- **Email:** Resend (transaccionales: compra confirmada, bienvenida).

## Estructura de módulos

```
cmd/api/            entry point
internal/config     env config
internal/server     router, middleware, wiring
internal/httpx      helpers JSON compartidos
internal/auth       P2: argon2id, JWT+refresh rotado, OAuth, RBAC
internal/catalog    P3: carreras, cursos, currícula
internal/media      P4: VideoProvider (Bunny), URLs firmadas
internal/progress   P5: heartbeats, completado, agregados
internal/enrollment P6: acceso por scope
internal/billing    P6: órdenes, Mercado Pago, webhooks
internal/store      GENERADO por sqlc — jamás editar a mano
db/migrations       SQL plano, numerado, aplicado en orden
db/queries          fuente de sqlc
web/                React PWA
```

## Reglas de datos (no negociables)

1. **Acceso por scope polimórfico.** Un enrollment es `('course', id)`
   o `('career', id)`. El acceso a un curso se resuelve por JOIN con
   `career_courses` en tiempo de consulta (ver `db/queries/access.sql`).
   Nunca explotar una compra de carrera en N enrollments de curso.
2. **`lesson_progress` es tabla caliente** (upsert por heartbeat cada
   ~15 s, con `GREATEST` para que un seek atrás no pise el máximo).
   `course_progress` es el agregado materializado que leen dashboard y
   barras. Nunca agregar sobre la tabla caliente en lecturas.
3. **Webhooks idempotentes** por `(provider, provider_payment_id)`:
   la transición `pending → approved` con `WHERE status = 'pending'`
   es el punto de idempotencia; si el UPDATE devuelve 0 filas, cortar.
4. **Una orden = un producto.** No hay carrito. La carrera es el bundle.
5. **`video_asset_id` nunca sale por la API.** La reproducción pasa por
   `GET /lessons/{id}/playback`, que verifica acceso y devuelve la URL
   HLS firmada con TTL corto.

## Reglas de código

- Todo acceso a datos vía sqlc: query en `db/queries/*.sql`, regenerar
  con `sqlc generate`. Prohibido SQL inline en handlers o services.
- Nunca serializar structs de `store` directo en respuestas: siempre
  DTOs explícitos por handler (ver `userDTO` en `internal/auth`).
- Errores al usuario en español, accionables, sin filtrar internals.
  Logs con `slog` estructurado.
- Migraciones solo aditivas una vez aplicadas; nunca editar una
  migración ya numerada.
- Tests: mínimo, tests de service para auth, enrollment/acceso,
  progreso y billing (los módulos con lógica). Integración contra
  Postgres real (docker) para las queries de acceso e idempotencia.
- El access token JWT vive solo en memoria del frontend; el refresh
  solo en cookie HttpOnly. Jamás localStorage para tokens.

## Reglas de UI

- Tokens de `web/src/styles/tokens.css` — no inventar colores ni
  tipografías fuera de esos tokens. Paleta Grafito, modo oscuro único
  en el MVP.
- Jerarquía de botones de 4 niveles (ver `docs/DESIGN.md`).
  **Máximo un botón primario (caramelo) por vista.**
- Datos (duraciones, porcentajes, numeración, timestamps) siempre en
  JetBrains Mono; UI y prosa en Space Grotesk, pesos 400/500.
- Niveles de dificultad con nomenclatura de tueste: suave / medio /
  intenso (así está en el CHECK de la base).

## Flujo de trabajo esperado

Implementar por fases (P1–P8 en `docs/SPEC.md`), cada una con sus
criterios de aceptación. Al terminar una fase: build limpio, tests en
verde, y un resumen corto de decisiones tomadas dentro de la fase.
Ante ambigüedad funcional, preguntar antes de asumir; ante ambigüedad
técnica menor, decidir y documentar en una línea.
