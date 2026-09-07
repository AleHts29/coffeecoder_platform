package catalog

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func TestAdmin_CreateCourseFromScratchAndReorder(t *testing.T) {
	q, tx := testutil.Queries(t)
	svc := NewAdminService(q, nil)
	pub := NewService(q)
	ctx := context.Background()

	course, err := svc.CreateCourse(ctx, ProductInput{Title: "Concurrencia en Go: Canales y Señales", PriceCents: 5900})
	if err != nil {
		t.Fatal(err)
	}
	if course.Slug != "concurrencia-en-go-canales-y-senales" || course.Status != "draft" || course.Level != "medio" {
		t.Fatalf("curso = %+v", course)
	}
	testutil.Savepoint(t, tx, func(q *store.Queries) {
		if _, err := NewAdminService(q, nil).CreateCourse(ctx, ProductInput{Title: "Otro", Slug: course.Slug, PriceCents: 1}); !errors.Is(err, ErrSlugTaken) {
			t.Fatalf("slug repetido: %v", err)
		}
	})
	if _, err := svc.CreateCourse(ctx, ProductInput{Title: "X", Level: "fuerte"}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("tueste inválido: %v", err)
	}

	m1, err := svc.CreateModule(ctx, course.ID, "Fundamentos")
	if err != nil {
		t.Fatal(err)
	}
	m2, _ := svc.CreateModule(ctx, course.ID, "Patrones")
	m3, _ := svc.CreateModule(ctx, course.ID, "Producción")
	if m1.Position != 1 || m2.Position != 2 || m3.Position != 3 {
		t.Fatalf("posiciones = %d %d %d", m1.Position, m2.Position, m3.Position)
	}
	l1, _ := svc.CreateLesson(ctx, m1.ID, LessonInput{Title: "Goroutines", DurationS: 600, IsFreeSample: true})
	l2, _ := svc.CreateLesson(ctx, m1.ID, LessonInput{Title: "Channels", DurationS: 900})
	if _, err := svc.CreateLesson(ctx, m1.ID, LessonInput{Title: " "}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("lección sin título: %v", err)
	}

	// Reordenar módulos: 3,1,2. La constraint DEFERRABLE permite el
	// intercambio dentro de la transacción.
	if err := svc.ReorderModules(ctx, course.ID, []uuid.UUID{m3.ID, m1.ID, m2.ID}); err != nil {
		t.Fatalf("reorder: %v", err)
	}
	_, modules, err := svc.GetCourse(ctx, course.ID)
	if err != nil {
		t.Fatal(err)
	}
	if modules[0].ID != m3.ID || modules[1].ID != m1.ID || modules[2].ID != m2.ID {
		t.Fatalf("orden = %v", []string{modules[0].Title, modules[1].Title, modules[2].Title})
	}
	if modules[0].Position != 1 || modules[2].Position != 3 || len(modules[1].Lessons) != 2 || modules[1].Lessons[0].VideoStatus != "none" {
		t.Fatalf("detalle = %+v", modules)
	}
	// Lista incompleta o con ids ajenos: rechazada.
	if err := svc.ReorderModules(ctx, course.ID, []uuid.UUID{m1.ID, m2.ID}); !errors.Is(err, ErrBadReorder) {
		t.Fatalf("reorder parcial: %v", err)
	}
	if err := svc.ReorderLessons(ctx, m1.ID, []uuid.UUID{l2.ID, l1.ID}); err != nil {
		t.Fatal(err)
	}
	_, modules, _ = svc.GetCourse(ctx, course.ID)
	if modules[1].Lessons[0].ID != l2.ID {
		t.Fatal("las lecciones no se reordenaron")
	}

	// Hasta publicar, el público no lo ve.
	if _, err := pub.GetCourse(ctx, course.Slug); !errors.Is(err, ErrNotFound) {
		t.Fatalf("borrador visible: %v", err)
	}
	if _, err := svc.UpdateCourse(ctx, course.ID, ProductInput{Slug: course.Slug, Title: course.Title, PriceCents: 5900, Status: "published", Level: "intenso"}); err != nil {
		t.Fatal(err)
	}
	detail, err := pub.GetCourse(ctx, course.Slug)
	if err != nil || detail.Level != "intenso" || len(detail.Modules) != 1 || detail.LessonCount != 2 { // los módulos vacíos no se publican
		t.Fatalf("publicado = %+v, %v", detail, err)
	}

	// Borrar: lección, módulo (cascade) y curso.
	if err := svc.DeleteLesson(ctx, l1.ID); err != nil {
		t.Fatal(err)
	}
	if err := svc.DeleteModule(ctx, m2.ID); err != nil {
		t.Fatal(err)
	}
	if err := svc.DeleteCourse(ctx, course.ID); err != nil {
		t.Fatal(err)
	}
	if _, _, err := svc.GetCourse(ctx, course.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("tras borrar: %v", err)
	}
}

func TestAdmin_CareerPathAndDeleteGuard(t *testing.T) {
	q, tx := testutil.Queries(t)
	svc := NewAdminService(q, nil)
	ctx := context.Background()

	career, err := svc.CreateCareer(ctx, ProductInput{Title: "Backend con Datos", PriceCents: 9900, Status: "published"})
	if err != nil {
		t.Fatal(err)
	}
	// Camino: redis → postgres (orden explícito).
	pg := uuid.MustParse("00000000-0000-4000-8000-020000000003")
	if err := svc.SetCareerCourses(ctx, career.ID, []uuid.UUID{testutil.CourseRedis, pg}); err != nil {
		t.Fatal(err)
	}
	_, courses, _ := svc.GetCareer(ctx, career.ID)
	if len(courses) != 2 || courses[0].ID != testutil.CourseRedis || courses[1].CareerPosition != 2 {
		t.Fatalf("camino = %+v", courses)
	}
	// Reemplazo con orden invertido y sin redis.
	if err := svc.SetCareerCourses(ctx, career.ID, []uuid.UUID{pg}); err != nil {
		t.Fatal(err)
	}
	_, courses, _ = svc.GetCareer(ctx, career.ID)
	if len(courses) != 1 || courses[0].ID != pg {
		t.Fatalf("camino tras reemplazo = %+v", courses)
	}
	if err := svc.SetCareerCourses(ctx, career.ID, []uuid.UUID{pg, pg}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("repetido: %v", err)
	}
	if err := svc.SetCareerCourses(ctx, career.ID, []uuid.UUID{uuid.New()}); !errors.Is(err, ErrInvalid) {
		t.Fatalf("inexistente: %v", err)
	}

	// Un curso dentro de una carrera no se puede borrar (RESTRICT).
	testutil.Savepoint(t, tx, func(q *store.Queries) {
		if err := NewAdminService(q, nil).DeleteCourse(ctx, pg); !errors.Is(err, ErrInUse) {
			t.Fatalf("borrar curso en carrera: %v", err)
		}
	})
	// Borrar la carrera limpia el camino (CASCADE) y libera el curso.
	if err := svc.DeleteCareer(ctx, career.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := q.GetCourse(ctx, pg); err != nil {
		t.Fatalf("el curso debe seguir existiendo: %v", err)
	}
}

func TestSlugify(t *testing.T) {
	cases := map[string]string{
		"Go desde cero": "go-desde-cero", "  APIs REST: Go & Chi!  ": "apis-rest-go-chi",
		"Programación Ñandú": "programacion-nandu", "---": "",
	}
	for in, want := range cases {
		if got := Slugify(in); got != want {
			t.Errorf("Slugify(%q) = %q, want %q", in, got, want)
		}
	}
}
