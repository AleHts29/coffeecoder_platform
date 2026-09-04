-- CoffeeCoder · 0001_init
-- PostgreSQL 16. gen_random_uuid() es nativo desde PG13.

BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Identidad
-- ---------------------------------------------------------------------------

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext NOT NULL UNIQUE,
  password_hash text,                       -- NULL si solo entra por OAuth
  name          text NOT NULL DEFAULT '',
  role          text NOT NULL DEFAULT 'student'
                CHECK (role IN ('student', 'admin')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Identidades OAuth (Google, GitHub). Un user puede tener varias.
CREATE TABLE auth_identities (
  provider     text NOT NULL CHECK (provider IN ('google', 'github')),
  provider_id  text NOT NULL,
  user_id      uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, provider_id)
);

CREATE INDEX auth_identities_user_idx ON auth_identities (user_id);

-- Refresh tokens: guardamos solo el hash, revocación explícita.
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash  bytea NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);

-- ---------------------------------------------------------------------------
-- Catálogo
-- ---------------------------------------------------------------------------

-- Niveles con nomenclatura de tueste: suave / medio / intenso.
-- price_cents siempre en la moneda base (USD); el pricing regional
-- se resuelve en la capa de billing, no en el catálogo.

CREATE TABLE careers (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         text NOT NULL UNIQUE,
  title        text NOT NULL,
  subtitle     text NOT NULL DEFAULT '',
  description  text NOT NULL DEFAULT '',
  level        text NOT NULL DEFAULT 'medio'
               CHECK (level IN ('suave', 'medio', 'intenso')),
  price_cents  integer NOT NULL CHECK (price_cents >= 0),
  status       text NOT NULL DEFAULT 'draft'
               CHECK (status IN ('draft', 'published', 'archived')),
  position     integer NOT NULL DEFAULT 0,   -- orden en el catálogo
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER careers_updated_at BEFORE UPDATE ON careers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE courses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         text NOT NULL UNIQUE,
  title        text NOT NULL,
  subtitle     text NOT NULL DEFAULT '',
  description  text NOT NULL DEFAULT '',
  level        text NOT NULL DEFAULT 'medio'
               CHECK (level IN ('suave', 'medio', 'intenso')),
  price_cents  integer NOT NULL CHECK (price_cents >= 0),
  status       text NOT NULL DEFAULT 'draft'
               CHECK (status IN ('draft', 'published', 'archived')),
  position     integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER courses_updated_at BEFORE UPDATE ON courses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Secuencia de cursos dentro de una carrera.
CREATE TABLE career_courses (
  career_id  uuid NOT NULL REFERENCES careers (id) ON DELETE CASCADE,
  course_id  uuid NOT NULL REFERENCES courses (id) ON DELETE RESTRICT,
  position   integer NOT NULL,
  PRIMARY KEY (career_id, course_id),
  UNIQUE (career_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX career_courses_course_idx ON career_courses (course_id);

CREATE TABLE modules (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  uuid NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
  title      text NOT NULL,
  position   integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE TRIGGER modules_updated_at BEFORE UPDATE ON modules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE lessons (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id       uuid NOT NULL REFERENCES modules (id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text NOT NULL DEFAULT '',
  video_provider  text NOT NULL DEFAULT 'bunny'
                  CHECK (video_provider IN ('bunny', 'mux', 'cloudflare')),
  video_asset_id  text,                      -- NULL hasta que se sube el video
  video_status    text NOT NULL DEFAULT 'none'
                  CHECK (video_status IN ('none', 'uploading', 'processing', 'ready', 'failed')),
  duration_s      integer NOT NULL DEFAULT 0 CHECK (duration_s >= 0),
  is_free_sample  boolean NOT NULL DEFAULT false,
  position        integer NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (module_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE TRIGGER lessons_updated_at BEFORE UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX lessons_module_idx ON lessons (module_id);
CREATE INDEX modules_course_idx ON modules (course_id);

-- ---------------------------------------------------------------------------
-- Comercio
-- ---------------------------------------------------------------------------

-- Una orden = un producto (curso o carrera). Sin carrito por diseño.
CREATE TABLE orders (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  product_type         text NOT NULL CHECK (product_type IN ('course', 'career')),
  product_id           uuid NOT NULL,
  amount_cents         integer NOT NULL CHECK (amount_cents >= 0),
  currency             char(3) NOT NULL DEFAULT 'USD',
  provider             text NOT NULL
                       CHECK (provider IN ('mercadopago', 'stripe', 'manual')),
  provider_payment_id  text,                 -- id externo; clave de idempotencia
  status               text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'approved', 'rejected', 'refunded')),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE UNIQUE INDEX orders_provider_payment_uq
  ON orders (provider, provider_payment_id)
  WHERE provider_payment_id IS NOT NULL;

CREATE INDEX orders_user_idx ON orders (user_id);

-- Enrollment con scope polimórfico: 'course' o 'career'.
-- El acceso a un curso es: enrollment directo O enrollment a una carrera
-- que hoy contenga el curso (JOIN con career_courses en tiempo de consulta).
CREATE TABLE enrollments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  scope         text NOT NULL CHECK (scope IN ('course', 'career')),
  scope_id      uuid NOT NULL,
  order_id      uuid REFERENCES orders (id) ON DELETE SET NULL,  -- NULL: alta manual
  activated_at  timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,                 -- reembolso / baja administrativa
  UNIQUE (user_id, scope, scope_id)
);

CREATE INDEX enrollments_user_idx ON enrollments (user_id) WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- Progreso
-- ---------------------------------------------------------------------------

-- Tabla de escritura caliente: un UPSERT por heartbeat del player (~15 s).
CREATE TABLE lesson_progress (
  user_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  lesson_id     uuid NOT NULL REFERENCES lessons (id) ON DELETE CASCADE,
  seconds       integer NOT NULL DEFAULT 0 CHECK (seconds >= 0),
  completed     boolean NOT NULL DEFAULT false,
  completed_at  timestamptz,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);

CREATE INDEX lesson_progress_user_recent_idx
  ON lesson_progress (user_id, updated_at DESC);

-- Agregado materializado por curso: lo actualiza el módulo progress
-- cuando una lección pasa a completed. Lectura instantánea del dashboard.
CREATE TABLE course_progress (
  user_id            uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  course_id          uuid NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
  completed_lessons  integer NOT NULL DEFAULT 0,
  total_lessons      integer NOT NULL DEFAULT 0,
  last_lesson_id     uuid REFERENCES lessons (id) ON DELETE SET NULL,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, course_id)
);

COMMIT;
