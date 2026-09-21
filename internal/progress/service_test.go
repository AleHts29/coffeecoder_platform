package progress

import (
	"context"
	"errors"
	"log/slog"
	"testing"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func setup(t *testing.T) (*Service, *store.Queries, uuid.UUID) {
	t.Helper()
	q, _ := testutil.Queries(t)
	ctx := context.Background()
	u, err := q.CreateUser(ctx, store.CreateUserParams{Email: "p-" + uuid.NewString()[:8] + "@test.dev", Name: "Alumno"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := q.CreateEnrollment(ctx, store.CreateEnrollmentParams{UserID: u.ID, Scope: "course", ScopeID: testutil.CourseGoDesdeCero}); err != nil {
		t.Fatal(err)
	}
	return NewService(q, slog.Default()), q, u.ID
}

func TestHeartbeat_PositionAndThreshold(t *testing.T) {
	svc, q, user := setup(t)
	ctx := context.Background()
	lesson, _ := q.GetLesson(ctx, testutil.LessonGoPaid) // 615 s en el seed
	dur := lesson.DurationS

	res, err := svc.Heartbeat(ctx, user, testutil.LessonGoPaid, 120, "")
	if err != nil || res.Seconds != 120 || res.Completed {
		t.Fatalf("primer heartbeat = %+v, %v", res, err)
	}
	// Seek hacia atrás: el máximo se conserva (retomar en el segundo correcto).
	res, _ = svc.Heartbeat(ctx, user, testutil.LessonGoPaid, 30, "")
	if res.Seconds != 120 {
		t.Fatalf("seek atrás pisó el máximo: %d", res.Seconds)
	}
	// Por debajo del umbral no completa.
	res, _ = svc.Heartbeat(ctx, user, testutil.LessonGoPaid, threshold(dur)-1, "")
	if res.Completed {
		t.Fatal("completó antes del 90%")
	}
	// Cruza el umbral: completa y materializa course_progress.
	res, err = svc.Heartbeat(ctx, user, testutil.LessonGoPaid, threshold(dur), "")
	if err != nil || !res.Completed {
		t.Fatalf("al 90%%: %+v, %v", res, err)
	}
	cp, err := q.GetCourseProgress(ctx, store.GetCourseProgressParams{UserID: user, CourseID: testutil.CourseGoDesdeCero})
	if err != nil || cp.CompletedLessons != 1 || cp.TotalLessons != 11 { // 10 video + 1 lectura
		t.Fatalf("course_progress = %+v, %v", cp, err)
	}
	// Más allá de la duración se recorta.
	res, _ = svc.Heartbeat(ctx, user, testutil.LessonGoPaid, dur+500, "")
	if res.Seconds != dur {
		t.Fatalf("no recortó a la duración: %d", res.Seconds)
	}
}

func TestHeartbeat_DailyActivityIsClamped(t *testing.T) {
	svc, _, user := setup(t)
	ctx := context.Background()
	// Salto de 300 s en un solo heartbeat: suma como máximo 30 s.
	if _, err := svc.Heartbeat(ctx, user, testutil.LessonGoPaid, 300, "UTC"); err != nil {
		t.Fatal(err)
	}
	// Avance normal de 15 s.
	if _, err := svc.Heartbeat(ctx, user, testutil.LessonGoPaid, 315, "UTC"); err != nil {
		t.Fatal(err)
	}
	d, err := svc.Dashboard(ctx, user, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	if d.WeekSeconds != 45 || d.StreakDays != 1 {
		t.Fatalf("week=%d streak=%d, want 45 y 1", d.WeekSeconds, d.StreakDays)
	}
	if d.Continue == nil || d.Continue.LessonID != testutil.LessonGoPaid || d.Continue.Seconds != 315 {
		t.Fatalf("continue = %+v", d.Continue)
	}
	if len(d.Courses) != 1 || d.Courses[0].Status != StatusInProgress {
		t.Fatalf("cursos sueltos = %+v", d.Courses)
	}
}

func TestComplete_AllLessonsReach100(t *testing.T) {
	svc, q, user := setup(t)
	ctx := context.Background()
	rows, err := q.GetCourseCurriculum(ctx, testutil.CourseGoDesdeCero)
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range rows {
		if _, err := svc.Complete(ctx, user, r.LessonID, ""); err != nil {
			t.Fatalf("complete %s: %v", r.LessonTitle, err)
		}
	}
	view, err := svc.CourseProgress(ctx, user, "go-desde-cero")
	if err != nil {
		t.Fatal(err)
	}
	if view.Summary.CompletedLessons != view.Summary.TotalLessons || view.Summary.TotalLessons != int32(len(rows)) {
		t.Fatalf("progreso = %d/%d", view.Summary.CompletedLessons, view.Summary.TotalLessons)
	}
	d, err := svc.Dashboard(ctx, user, "")
	if err != nil {
		t.Fatal(err)
	}
	if d.Courses[0].Status != StatusCompleted {
		t.Fatalf("status = %s", d.Courses[0].Status)
	}
	if d.Continue != nil {
		t.Fatal("con todo completado no hay 'seguí donde quedaste'")
	}
	// Completar dos veces es idempotente.
	if _, err := svc.Complete(ctx, user, rows[0].LessonID, ""); err != nil {
		t.Fatal(err)
	}
}

func TestCourseProgress_MaterializesOnFirstRead(t *testing.T) {
	svc, _, user := setup(t)
	view, err := svc.CourseProgress(context.Background(), user, "go-desde-cero")
	if err != nil {
		t.Fatal(err)
	}
	if view.Summary.TotalLessons != 11 || view.Summary.CompletedLessons != 0 || len(view.Lessons) != 0 {
		t.Fatalf("view = %+v", view.Summary)
	}
}

// Criterio 7: un curso mixto suma las horas de video y de lectura, y la
// lectura completa una sola vez aunque se marque dos veces.
func TestArticleCompletionAndMixedTotals(t *testing.T) {
	svc, q, user := setup(t)
	ctx := context.Background()

	article, err := q.GetLesson(ctx, testutil.LessonArticle)
	if err != nil {
		t.Fatal(err)
	}
	if article.Kind != "article" || article.DurationS == 0 {
		t.Fatalf("lección de lectura del seed = %+v", article)
	}
	// Un artículo no acepta heartbeats.
	if _, err := svc.Heartbeat(ctx, user, testutil.LessonArticle, 10, "UTC"); !errors.Is(err, ErrNotVideo) {
		t.Fatalf("heartbeat en artículo: %v", err)
	}

	if _, err := svc.Complete(ctx, user, testutil.LessonArticle, "UTC"); err != nil {
		t.Fatal(err)
	}
	d, err := svc.Dashboard(ctx, user, "UTC")
	if err != nil {
		t.Fatal(err)
	}
	if d.WeekSeconds != article.DurationS {
		t.Fatalf("actividad tras leer = %d s, want %d", d.WeekSeconds, article.DurationS)
	}
	// Completar de nuevo no vuelve a sumar.
	if _, err := svc.Complete(ctx, user, testutil.LessonArticle, "UTC"); err != nil {
		t.Fatal(err)
	}
	d, _ = svc.Dashboard(ctx, user, "UTC")
	if d.WeekSeconds != article.DurationS {
		t.Fatalf("completar dos veces sumó dos veces: %d s", d.WeekSeconds)
	}
	view, err := svc.CourseProgress(ctx, user, "go-desde-cero")
	if err != nil || view.Summary.CompletedLessons != 1 || view.Summary.TotalLessons != 11 {
		t.Fatalf("progreso del curso mixto = %+v, %v", view.Summary, err)
	}
}

func TestAccessRequired(t *testing.T) {
	svc, q, user := setup(t)
	ctx := context.Background()
	if _, err := svc.Heartbeat(ctx, user, testutil.LessonRedisPay, 10, ""); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("heartbeat sin acceso: %v", err)
	}
	if _, err := svc.Complete(ctx, user, testutil.LessonRedisPay, ""); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("complete sin acceso: %v", err)
	}
	if _, err := svc.CourseProgress(ctx, user, "redis-y-colas"); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("progress sin acceso: %v", err)
	}
	if _, err := svc.CourseProgress(ctx, user, "no-existe"); !errors.Is(err, ErrCourseNotFound) {
		t.Fatalf("curso inexistente: %v", err)
	}
	// La muestra gratis tampoco registra progreso sin enrollment al curso.
	stranger, _ := q.CreateUser(ctx, store.CreateUserParams{Email: "s-" + uuid.NewString()[:8] + "@test.dev"})
	if _, err := svc.Heartbeat(ctx, stranger.ID, testutil.LessonGoFree, 10, ""); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("muestra gratis sin enrollment: %v", err)
	}
}

func TestDashboard_CareerSegments(t *testing.T) {
	svc, q, user := setup(t)
	ctx := context.Background()
	if _, err := q.CreateEnrollment(ctx, store.CreateEnrollmentParams{UserID: user, Scope: "career", ScopeID: testutil.CareerBackendGo}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Complete(ctx, user, testutil.LessonGoPaid, ""); err != nil {
		t.Fatal(err)
	}
	d, err := svc.Dashboard(ctx, user, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(d.Careers) != 1 || len(d.Careers[0].Courses) != 4 {
		t.Fatalf("careers = %+v", d.Careers)
	}
	c := d.Careers[0]
	if c.TotalLessons != 41 || c.CompletedLessons != 1 {
		t.Fatalf("carrera %d/%d", c.CompletedLessons, c.TotalLessons)
	}
	if c.Courses[0].Status != StatusInProgress || c.Courses[1].Status != StatusPending {
		t.Fatalf("segmentos = %s, %s", c.Courses[0].Status, c.Courses[1].Status)
	}
	// Cursos con total conocido aunque no haya course_progress materializado.
	if c.Courses[1].TotalLessons != 12 {
		t.Fatalf("total del curso pendiente = %d", c.Courses[1].TotalLessons)
	}
}
