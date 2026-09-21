# CLAUDE.md — CoffeeCoder

Plataforma de carreras y cursos de programación. Marca: CoffeeCoder.
Un solo instructor (Alejandro), compra única por curso o carrera, video
grabado. Este archivo define las reglas del proyecto; la especificación
funcional completa está en `docs/SPEC.md` y el design system en
`docs/DESIGN.md`. **Leé los tres antes de escribir código.**

## Estado actual

**MVP completo (P1–P8) desde el 2026-09-07.** El detalle por fase, las
decisiones y los pendientes están en `docs/ESTADO.md`, que se actualiza
en cada implementación: leelo antes de planificar.

Resumen de lo que hay hoy:

- Backend Go por módulos en `internal/` (auth, catalog, content, media,
  progress, enrollment, billing, mail), PWA React en `web/`, y un binario
  que sirve las dos cosas en producción (`WEB_DIST`).
- `db/migrations/0001_init.sql` está validado contra PostgreSQL 16 real y
  es canónico: no lo reescribas, extendelo con migraciones nuevas.
  `make migrate` es idempotente vía `schema_migrations`.
- Lecciones de **video** y de **lectura** (Markdown + demos interactivas,
  ver `docs/DEMOS.md`). Categorías de catálogo. Dos cursos sembrados:
  "Go desde cero" y "Producción Musical con Ableton" (este último en
  draft, con su propio seed generado por `make seed-gen`).
- Tests de integración contra Postgres: `make test` (base
  `coffeecoder_test`, ver `internal/testutil`; IDs del seed en
  `testutil/seed.go`).
- Proveedores con doble implementación: video (Bunny / fake), pagos
  (Mercado Pago / fake), imágenes y adjuntos (Bunny Storage / disco
  local). Los `fake` y `local` solo corren en `APP_ENV=development`.

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
   barras; `daily_activity` (una fila por usuario y día) alimenta racha
   y horas. Nunca agregar sobre la tabla caliente en lecturas.
3. **Webhooks idempotentes** por `(provider, provider_payment_id)`:
   la transición `pending → approved` con `WHERE status = 'pending'`
   es el punto de idempotencia; si el UPDATE devuelve 0 filas, cortar.
4. **Una orden = un producto.** No hay carrito. La carrera es el bundle.
5. **`video_asset_id` nunca sale por la API.** La reproducción pasa por
   `GET /lessons/{id}/playback`, que verifica acceso y devuelve la URL
   HLS firmada con TTL corto.
6. **El contenido de lectura sigue la misma regla.** `lessons.body_md` y
   `demos.html` solo salen por `GET /lessons/{id}/content` (verifica
   acceso) y `GET /demos/{id}/frame` (verifica firma HMAC). Jamás por
   la currícula ni por ningún endpoint público.
7. **Las demos se sirven por URL firmada, nunca con `srcdoc`.** Un
   iframe `srcdoc` hereda la CSP de la plataforma; con `src` la demo
   tiene su propia CSP `sandbox` y queda en un origen opaco. Ver
   `docs/DEMOS.md`.

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
- Las demos interactivas siguen `docs/DEMOS.md`: HTML autocontenido, solo
  tokens Grafito, y si llevan sonido, el helper `createAudio()` copiado
  tal cual (Web Audio nativa, opt-in, sin autoplay).
- Niveles de dificultad con nomenclatura de tueste: suave / medio /
  intenso (así está en el CHECK de la base).

## Flujo de trabajo con Claude web

Claude web arma los planes leyendo el repo conectado por GitHub (este
`CLAUDE.md`, `docs/SPEC.md`, `docs/DESIGN.md`, `docs/ESTADO.md`); Claude
Code los implementa. **Al cerrar cada implementación: actualizar
`docs/ESTADO.md` (estado, decisiones nuevas, pendientes), commitear y
pushear**, así Claude web planifica sobre el estado real. Los planes
llegan pegados en la sesión.

## Flujo de trabajo esperado

El MVP por fases (P1–P8 en `docs/SPEC.md`) ya está cerrado. Lo que
llega ahora son planes puntuales: implementalos completos, con build
limpio, tests en verde y un resumen corto de las decisiones tomadas.
Ante ambigüedad funcional, preguntar antes de asumir; ante ambigüedad
técnica menor, decidir y documentar en una línea.
