-- CoffeeCoder · 0003_articles_and_demos
-- Lecciones de lectura (artículos en Markdown) y biblioteca de demos
-- interactivas por curso. Las demos son HTML autocontenido que solo se
-- sirve por URL firmada con CSP propia (ver docs/DEMOS.md).

BEGIN;

-- Tipo de lección. 'video' es lo que había; 'article' usa body_md.
ALTER TABLE lessons
  ADD COLUMN kind text NOT NULL DEFAULT 'video'
    CHECK (kind IN ('video', 'article')),
  ADD COLUMN body_md text NOT NULL DEFAULT '';

-- Coherencia: una lección de lectura no puede arrastrar un video.
ALTER TABLE lessons
  ADD CONSTRAINT lessons_kind_video_status_chk
  CHECK (kind = 'video' OR video_status = 'none');

-- Biblioteca de demos por curso. El HTML nunca sale por la API salvo
-- por GET /demos/{id}/frame, que verifica firma y aplica la CSP.
CREATE TABLE demos (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  uuid NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
  slug       text NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title      text NOT NULL,
  html       text NOT NULL,
  height_px  integer NOT NULL DEFAULT 420
             CHECK (height_px BETWEEN 120 AND 1600),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, slug)
);

CREATE TRIGGER demos_updated_at BEFORE UPDATE ON demos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
