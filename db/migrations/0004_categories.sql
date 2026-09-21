-- CoffeeCoder · 0004_categories
-- Categorías de catálogo. El catálogo deja de ser solo backend: una
-- categoría agrupa cursos y carreras de un mismo dominio (programación,
-- producción musical, …) y el catálogo público filtra por ella.

BEGIN;

CREATE TABLE categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name       text NOT NULL,
  position   integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Nullable: un producto sin categoría sigue siendo válido y aparece en
-- el catálogo sin chip de categoría.
ALTER TABLE courses ADD COLUMN category_id uuid REFERENCES categories (id) ON DELETE SET NULL;
ALTER TABLE careers ADD COLUMN category_id uuid REFERENCES categories (id) ON DELETE SET NULL;

CREATE INDEX courses_category_idx ON courses (category_id);
CREATE INDEX careers_category_idx ON careers (category_id);

-- Las dos categorías iniciales. Idempotente por slug.
INSERT INTO categories (id, slug, name, position) VALUES
  ('00000000-0000-4000-8000-060000000001', 'programacion', 'Programación', 1),
  ('00000000-0000-4000-8000-060000000002', 'produccion-musical', 'Producción musical', 2)
ON CONFLICT (slug) DO NOTHING;

-- Todo lo que había hasta ahora es programación.
UPDATE courses SET category_id = '00000000-0000-4000-8000-060000000001' WHERE category_id IS NULL;
UPDATE careers SET category_id = '00000000-0000-4000-8000-060000000001' WHERE category_id IS NULL;

COMMIT;
