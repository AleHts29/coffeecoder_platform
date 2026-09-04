-- CoffeeCoder · 0002_daily_activity
-- Racha y horas de estudio del dashboard. Una fila por usuario y día;
-- el heartbeat suma el avance real (delta de posición acotado), así
-- que un seek no infla las horas. Lectura acotada a ~1 año por usuario:
-- no es la tabla caliente de posición (lesson_progress).

BEGIN;

CREATE TABLE daily_activity (
  user_id  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  day      date NOT NULL,
  seconds  integer NOT NULL DEFAULT 0 CHECK (seconds >= 0),
  PRIMARY KEY (user_id, day)
);

COMMIT;
