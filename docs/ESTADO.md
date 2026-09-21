# CoffeeCoder · Estado del proyecto

> Documento vivo. Lo actualiza Claude Code al cerrar cada implementación y
> lo pushea; Claude web lo lee del repo conectado por GitHub para planificar
> sobre el estado real.
> Última actualización: 2026-09-21.

## Cómo trabajamos

- **Claude web** arma los planes (qué construir, criterios de aceptación).
- **Claude Code** (sesión en `MY_PROJECTS/coffeecoder`) los implementa, testea,
  commitea y actualiza este documento.
- Un plan útil para Claude Code tiene: objetivo en una línea, alcance (qué sí
  y qué no), criterios de aceptación verificables, y decisiones ya tomadas.
  No hace falta detallar archivos: el repo tiene reglas en `CLAUDE.md`,
  especificación en `docs/SPEC.md` y design system en `docs/DESIGN.md`.
- Para pasarle un plan a Claude Code alcanza con pegarlo en la sesión.

## Producto en una línea

Plataforma de carreras y cursos de backend en video, un solo instructor,
compra única por curso o carrera, acceso de por vida. Marca CoffeeCoder,
español rioplatense, modo oscuro "Grafito".

## Stack (fijo)

Go 1.25 · Chi v5 · PostgreSQL 16 · pgx/v5 · sqlc v1.30 · React 18 · Vite 6 ·
TypeScript · Tailwind v4 · TanStack Query · TanStack Router (code-based) ·
hls.js · Bunny Stream · Mercado Pago Checkout Pro · Resend.

## Estado: MVP completo (P1–P8) + lecciones de lectura con demos

MVP cerrado el 2026-09-07. El 2026-09-21 se sumó el plan de artículos y
demos interactivas (`PLAN-articulos-y-demos.md`), completo y verificado
contra sus ocho criterios.

| Fase | Qué hay | Verificado con |
|---|---|---|
| P1 Fundaciones | esquema `0001_init` + `0002_daily_activity`, sqlc, Makefile con toolchain resuelto, `schema_migrations` idempotente | `make migrate` ×2, build |
| P2 Auth | argon2id, JWT 15 min en memoria, refresh rotado en cookie HttpOnly con detección de reuso, OAuth Google/GitHub, RBAC, `/me`, mail de bienvenida | tests de service + curl |
| P3 Catálogo | API pública de carreras/cursos/currícula (sin `video_asset_id`), PWA: landing, catálogo con filtro por tueste, carrera ("el camino"), curso (currícula + upsell), seed idempotente | Lighthouse a11y 95 |
| P4 Video | `media.VideoProvider` (Bunny real + Fake dev), firma HS256 de bunny.net verificada con vectores oficiales, tickets TUS, webhook HMAC, playback con auth opcional (401/403/409), player HLS con velocidad/autoplay/modo cine, login/registro | tests + fake e2e |
| P5 Progreso | heartbeat 15 s con GREATEST, completado al 90 % o manual, `course_progress` materializado, `daily_activity` para racha/horas, dashboard `/panel`, nodos de estado en el camino, card de acceso | tests + e2e |
| P6 Pagos | `billing.PaymentProvider` (Mercado Pago + Fake), orden = un producto, precio regional por `BILLING_USD_RATE`, webhook `x-signature` idempotente (N reenvíos = 1 enrollment), reembolso admin, `/checkout`, `/checkout/resultado` con polling, `/cuenta`, mails Resend/log | tests + fake e2e |
| P7 Admin | CRUD carreras/cursos/módulos/lecciones con reorden transaccional, camino de carrera, upload TUS con estado, ventas con reembolso, alumnos con alta manual y revocación; UI `/admin/*` | tests + e2e + capturas |
| P8 Pulido | binario sirve la PWA (`WEB_DIST`) con OG por producto, chunks por ruta, service worker, header móvil, bottom sheet del player | Lighthouse prod: perf 85 / a11y 95 / bp 100 / SEO 100 |
| Artículos y demos | `lessons.kind` (video/article) + `body_md`; tabla `demos` por curso; `GET /lessons/{id}/content`; frame firmado con CSP sandbox; lector con Markdown + Shiki; editor Markdown con preview, "Insertar demo" y subida de imágenes; biblioteca de demos en el admin | tests + e2e + navegador (a11y 100 en el lector) |

## Lecciones de lectura y demos (2026-09-21)

- **Modelo.** `lessons.kind` es `video` o `article`; el texto va en
  `body_md` (Markdown, sin HTML crudo). CHECK de coherencia: una lección
  de lectura no puede tener video. Las demos viven en la tabla `demos`
  (por curso, `UNIQUE (course_id, slug)`) y el texto las referencia con
  una línea `::demo[slug]`. Migración `0003_articles_and_demos`.
- **Seguridad de las demos.** `GET /demos/{id}/frame?exp=&sig=` con HMAC
  sobre (id, expiración) y TTL de 30 min; responde el HTML con
  `Content-Security-Policy: sandbox allow-scripts; default-src 'none'; …;
  frame-ancestors 'self'`. **No se usa `srcdoc`**: un iframe `srcdoc`
  hereda la CSP de la plataforma y habría que aflojarla para toda la app.
- **Verificado en navegador** (criterio 4, Chrome headless, 2026-09-21):
  dentro de la demo `window.origin` es `null` y `localStorage`,
  `document.cookie` y `window.parent.document` lanzan `SecurityError`.
- **Tiempo de lectura.** Se calcula al guardar: ~200 palabras/min, los
  bloques de código a la mitad de peso, +60 s por demo, piso de 30 s.
  Suma a las horas del curso y, al completar, a `daily_activity`.
- **Progreso.** Los artículos no mandan heartbeats (el endpoint responde
  400). Se completan al entrar el final en viewport o a mano, una sola
  vez: completar de nuevo no vuelve a sumar actividad.
- **Imágenes.** `POST /admin/images` guarda en Bunny Storage
  (`IMAGE_PROVIDER=bunny`) o en disco local servido en `/uploads`
  (`local`, solo development).

## API (resumen)

Público: `GET /careers`, `/careers/{slug}`, `/courses`, `/courses/{slug}`;
`POST /auth/register|login|refresh|logout`, `GET /auth/oauth/{provider}`.
Auth opcional: `GET /lessons/{id}/playback` (muestras gratis sin sesión).
Alumno: `GET /me`, `/me/dashboard`, `/me/courses/{slug}/progress`, `/me/orders`;
`POST /lessons/{id}/heartbeat|complete`, `POST /orders`, `GET /orders/{id}`.
Webhooks: `POST /webhooks/bunny`, `/webhooks/mercadopago`.
Admin (`/admin/...`): CRUD de `careers`, `courses`, `modules`, `lessons` + `.../order`;
`lessons/{id}/video` y `/video/sync`; `orders` y `orders/{id}/refund`;
`students`, `students/{id}/enrollments`, `enrollments/{id}` (DELETE = revocar).
Contenido: `GET /lessons/{id}/content` (auth opcional, misma regla que
playback), `GET /demos/{id}/frame` (firma HMAC).
Admin de demos e imágenes: `GET|POST /admin/courses/{id}/demos`,
`GET|PUT|DELETE /admin/demos/{id}`, `POST /admin/images`.
Errores siempre `{ "error": "mensaje en español" }`.

## Decisiones tomadas (no volver a discutir salvo que cambie algo)

- Enrollment con scope polimórfico (`course` | `career`); acceso por JOIN,
  nunca se explota una carrera en N enrollments.
- `lesson_progress` es tabla caliente; el dashboard solo lee agregados.
- `video_asset_id` nunca sale por la API.
- Filtro por "tema" del catálogo no existe: el esquema no modela tema.
- Precio regional interino: catálogo en USD, `BILLING_USD_RATE` + `BILLING_CURRENCY`.
- Router: TanStack Router code-based, sin plugin de generación.
- Providers `fake` (video y pagos) solo en `APP_ENV=development`.
- Módulos sin lecciones no se publican al público; el admin los ve.
- Reordenar recibe la lista completa de ids y aplica en transacción.
- El fake de video reproduce un HLS público de prueba (Mux).
- Markdown como formato del texto; nada de MDX ni HTML libre.
- Las demos son HTML autocontenido por curso, se sirven solo por URL
  firmada con CSP propia y nunca se inyectan en el DOM de la app.
- Mermaid no se usa: cualquier diagrama se hace como demo.
- La lección de lectura del seed vive en "Go desde cero" (módulo
  "Errores y concurrencia"): el seed no tiene un curso de Concurrencia.

## Pendientes que dependen del dueño

1. Credenciales reales: Bunny (`BUNNY_*`, Token Authentication activo en el pull
   zone), Mercado Pago (`MP_ACCESS_TOKEN` de test, `MP_WEBHOOK_SECRET`,
   `BILLING_USD_RATE`, URL pública para el webhook), Resend (`RESEND_API_KEY`,
   `MAIL_FROM` con dominio verificado).
2. Decisión de diseño: `ink-faint` #7A7A78 no cumple AA 4.5:1 para texto chico
   (4.28 / 4.00 / 3.60 sobre los tres fondos). Propuesta: `#8C8C8A`.
3. Admin real: hoy el rol se asigna por SQL.
4. Deploy: `make web-build && go build ./cmd/api`, Postgres 16, `WEB_DIST`,
   `FRONTEND_URL` y `PUBLIC_BASE_URL` al mismo dominio. Sin remoto git aún.

## Limitaciones conocidas

- **Imágenes de artículos sin proteger.** Van por CDN con nombre
  aleatorio (`/2026/09/<32 hex>.png`): no se adivinan, pero quien tenga
  el link la ve sin comprar el curso. El texto y las demos sí están
  protegidos. Si hiciera falta, se resuelve con URL firmada como el video.
- Una demo borrada deja su `::demo[slug]` en los textos que la usaban;
  el alumno no ve nada ahí y el admin ve el aviso en la preview.
- Sin guardado de posición de scroll en artículos ni auto-alto de los
  iframes (el alto lo declara el admin).

## Fuera del MVP (roadmap, no implementado)

Quizzes, certificados, transcripciones, notas, comentarios/Q&A, suscripciones,
multi-instructor, clases en vivo, app nativa, i18n, modo claro, precios por
producto y país, thumbnails de video, limpieza de órdenes pendientes vencidas,
pre-render/SSR para performance de las páginas públicas.

## Cómo correr en local

```
make tools db-up migrate seed dev-videos   # una vez
make run          # API en :8081 (VIDEO_PROVIDER=fake, BILLING_PROVIDER=fake)
make web-dev      # PWA en :5173 con proxy /api
make test         # Go: unitarios + integración (coffeecoder_test)
make dev-pay ORDER=<uuid>   # aprueba una orden con el provider fake
```

La lección de lectura de ejemplo (muestra gratis, con demo) está en
`/cursos/go-desde-cero/lecciones/00000000-0000-4000-8000-040000010305`.
Las fuentes del seed de artículos están en `seed/` y se generan a
`db/seed/articles.sql`.

Usuarios locales: `test@coffeecoder.dev` (admin) y alumnos de prueba,
contraseña `Cafecito-2026!`.
