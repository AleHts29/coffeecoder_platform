# SPEC — CoffeeCoder

Especificación funcional y roadmap. Las reglas técnicas transversales
están en `CLAUDE.md`; el design system en `docs/DESIGN.md`.

## 1. Producto

CoffeeCoder vende formación de backend en profundidad bajo una tesis:
catálogo chico y profundo, experiencia de aprendizaje excepcional.
Dos niveles de contenido:

- **Curso**: unidad atómica. Módulos ordenados → lecciones en video.
- **Carrera**: secuencia curada de cursos con una promesa profesional
  ("Backend Developer con Go"). Es el producto comercial principal.

Un solo instructor (el dueño de la plataforma). Sin marketplace, sin
instructores invitados, sin clases en vivo en el MVP.

## 2. Modelo de negocio

- **Compra única** por curso o por carrera. Sin suscripciones.
- **Acceso perpetuo** con actualizaciones del contenido incluidas.
  Los enrollments no vencen (el campo `revoked_at` existe solo para
  reembolsos o bajas administrativas).
- La **carrera es el ancla de precio**: curso individual como puerta
  de entrada, carrera con precio ~2.5x el curso para que se perciba
  como la decisión obvia. Precios firmes, sin descuentos permanentes.
- Comprar una carrera da acceso a los cursos que la carrera contenga
  **hoy y en el futuro** (resuelto por diseño de datos, ver CLAUDE.md).
- **Mercado Pago con cuotas** para LATAM (crítico para conversión en
  Argentina). Stripe se agrega después para internacional. Los precios
  regionales se resuelven en billing, no en el catálogo.

## 3. Roles

- **student**: compra, mira, progresa.
- **admin**: el instructor. CRUD de contenido, ventas, alumnos.

## 4. Mapa de pantallas (MVP)

Públicas:
1. **Landing**: propuesta de valor, carreras destacadas, CTA a catálogo.
2. **Catálogo**: carreras primero (protagonistas), cursos debajo.
   Filtro por nivel (tueste) y tema.
3. **Página de carrera** (pantalla de venta principal): hero con
   título, promesa, metadatos (cursos, horas, lecciones); card de
   compra sticky con precio, "Comprar carrera", acceso de por vida /
   actualizaciones / certificado, mención de cuotas; y "El camino":
   lista vertical conectada de cursos con nodos de estado (para
   compradores: check = completado, anillo = en curso con barra y CTA
   Continuar, vacío = pendiente; para visitantes: todos vacíos).
4. **Página de curso**: currícula expandible por módulos, lecciones de
   muestra gratis reproducibles, CTA de compra, y aviso de a qué
   carrera pertenece (upsell al bundle).
5. **Checkout**: resumen del producto, pago con Mercado Pago
   (redirect a preference), estados de retorno éxito/pendiente/error.
6. **Login / Registro**: email+contraseña y OAuth Google/GitHub.

Del alumno:
7. **Dashboard**: hero "seguí donde quedaste" (última lección con
   posición exacta y CTA Continuar), racha y horas de la semana en
   datos mono, "Mis carreras" con progreso por segmentos (un segmento
   por curso: lleno/medio/vacío), "Cursos sueltos" con barras.
8. **Player** (layout teatro): video protagonista arriba, debajo
   título de lección + acciones (Marcar completada secundario,
   Siguiente lección primario) + tabs Resumen/Notas/Recursos/Preguntas
   (solo Resumen funcional en MVP; el resto oculto o "próximamente").
   Sidebar derecha colapsable: progreso del curso, módulos como
   acordeones (completados colapsados con check), lección activa con
   borde caramelo, duraciones en mono. Controles: velocidad, calidad
   (la da HLS), CC si hay, autoplay de siguiente.
9. **Perfil / Mis compras**: datos básicos, historial de órdenes.

Admin:
10. **Gestión de contenido**: CRUD de carreras/cursos/módulos/lecciones
    con reordenamiento; upload de video con estado de transcodificación
    visible (uploading → processing → ready / failed).
11. **Ventas**: listado de órdenes con estado y producto.
12. **Alumnos**: listado con búsqueda, opción de alta manual de
    enrollment (scope curso o carrera) y revocación.

## 5. API (resumen)

Ya cableada en `internal/server/server.go`. Público: auth completa,
catálogo de carreras/cursos. Autenticado: `/me`, `/me/dashboard`,
`/lessons/{id}/playback|heartbeat|complete`, `/orders`. Webhooks:
`/webhooks/mercadopago`, `/webhooks/bunny`. Admin: CRUD de contenido.
Convención de errores: `{ "error": "mensaje en español" }`.

## 6. Fases y criterios de aceptación

### P1 — Fundaciones ✓ (semilla incluida)
Esquema validado, queries sqlc, estructura de módulos, docker-compose,
Makefile, tokens. **Criterio:** `make db-up migrate sqlc` corre limpio
y `go build ./...` compila (esto último queda pendiente de la primera
sesión de Claude Code).

### P2 — Auth ✓ (semilla incluida, sin compilar)
Registro, login, refresh rotado con detección de reuso, OAuth
Google/GitHub, RBAC. **Criterios:** build limpio; tests de service
(registro duplicado, login inválido, rotación, reuso revoca familia);
flujo OAuth probado con credenciales reales; ningún endpoint devuelve
`password_hash`.

### P3 — Catálogo + scaffold frontend
Handlers públicos usando las queries existentes de `catalog.sql`;
scaffold de la PWA (Vite + TS + Tailwind v4 con tokens + TanStack
Query) con layout base (header con wordmark `coffeecoder_`), páginas
de catálogo, carrera y curso consumiendo la API real, y seed de
contenido de desarrollo. **Criterios:** las tres páginas públicas
renderizan datos reales del seed; la currícula no expone
`video_asset_id`; lighthouse accesibilidad > 90 en catálogo.

### P4 — Video (mayor riesgo técnico: hacerla apenas exista P3)
Implementar `media.Bunny` real (create video, TUS upload desde admin,
webhook de transcodificación → `video_status`), endpoint `playback`
con verificación de acceso + URL firmada TTL 6 h, player HLS (hls.js)
con velocidad y autoplay. **Criterios:** subir un video real de prueba
end-to-end hasta reproducirlo con URL firmada; una URL vencida o sin
enrollment devuelve 401/403; verificar la firma contra la doc vigente
de Bunny token authentication.

### P5 — Progreso
Heartbeats desde el player (cada 15 s + al pausar/salir), umbral de
completado 90% o acción manual, `RefreshCourseProgress` tras completar,
dashboard con continue-watching real. **Criterios:** cerrar el tab y
volver retoma en el segundo correcto; completar la última lección deja
el curso en 100%; el dashboard no hace agregaciones sobre
`lesson_progress`.

### P6 — Pagos + emails
Crear orden + preference de Mercado Pago (con cuotas), webhook
idempotente `pending → approved` → crear enrollment → email de
confirmación vía Resend. Reembolso manual desde admin revoca
enrollment. **Criterios:** compra de prueba en sandbox de MP end-to-end;
reenviar el mismo webhook N veces genera exactamente un enrollment;
comprar carrera habilita todos sus cursos al instante.

### P7 — Admin
Las tres pantallas de admin del mapa. Reordenamiento con `position`
(las constraints UNIQUE son DEFERRABLE justamente para reordenar en
una transacción). **Criterios:** crear un curso completo desde cero
solo por UI; reordenar módulos no rompe; alta manual de enrollment
funciona (necesaria para operar antes de P6 en staging).

### P8 — Pulido
Estados vacíos con voz de marca, loading/error states consistentes,
responsive fino (el player en mobile: sidebar como bottom sheet),
metadatos OG por curso/carrera, performance (code splitting por ruta).
**Criterio:** revisión visual contra `docs/DESIGN.md` pantalla por
pantalla.

## 7. Fuera de alcance del MVP (no implementar)

Quizzes, certificados, transcripciones, notas, comentarios/Q&A,
suscripciones, multi-instructor, clases en vivo, app mobile nativa,
i18n (todo en español rioplatense neutro profesional), modo claro.
Están en el roadmap post-MVP; el diseño de datos ya los contempla
donde era barato hacerlo.
