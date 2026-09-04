package testutil

import "github.com/google/uuid"

// IDs fijos de db/seed/dev.sql, para que los tests hablen de contenido real.
var (
	CareerBackendGo   = uuid.MustParse("00000000-0000-4000-8000-010000000001")
	CourseGoDesdeCero = uuid.MustParse("00000000-0000-4000-8000-020000000001") // en la carrera
	CourseRedis       = uuid.MustParse("00000000-0000-4000-8000-020000000005") // fuera de la carrera

	LessonGoFree   = uuid.MustParse("00000000-0000-4000-8000-040000010101") // curso 1, muestra gratis
	LessonGoPaid   = uuid.MustParse("00000000-0000-4000-8000-040000010102") // curso 1, paga
	LessonRedisPay = uuid.MustParse("00000000-0000-4000-8000-040000050102") // curso 5, paga
)
