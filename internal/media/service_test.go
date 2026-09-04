package media

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func newTestService(t *testing.T) (*Service, *store.Queries, *Fake) {
	t.Helper()
	q, _ := testutil.Queries(t)
	fake := NewFake("https://cdn.test/sample.m3u8")
	return NewService(q, fake, 6*time.Hour, slog.Default()), q, fake
}

func newUser(t *testing.T, q *store.Queries) uuid.UUID {
	t.Helper()
	u, err := q.CreateUser(context.Background(), store.CreateUserParams{
		Email: "alumno-" + uuid.NewString()[:8] + "@test.dev", Name: "Alumno",
	})
	if err != nil {
		t.Fatal(err)
	}
	return u.ID
}

func enroll(t *testing.T, q *store.Queries, user uuid.UUID, scope string, scopeID uuid.UUID) store.Enrollment {
	t.Helper()
	e, err := q.CreateEnrollment(context.Background(), store.CreateEnrollmentParams{
		UserID: user, Scope: scope, ScopeID: scopeID,
	})
	if err != nil {
		t.Fatal(err)
	}
	return e
}

// markReady simula un upload + webhook exitoso sobre una lección del seed.
func markReady(t *testing.T, svc *Service, lesson uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	if _, err := svc.StartUpload(ctx, lesson); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.SyncVideo(ctx, lesson); err != nil {
		t.Fatal(err)
	}
}

func TestPlayback_AccessRules(t *testing.T) {
	svc, q, _ := newTestService(t)
	ctx := context.Background()
	for _, l := range []uuid.UUID{testutil.LessonGoFree, testutil.LessonGoPaid, testutil.LessonRedisPay} {
		markReady(t, svc, l)
	}
	user := newUser(t, q)
	other := newUser(t, q)

	t.Run("visitante ve la muestra gratis", func(t *testing.T) {
		pb, err := svc.Playback(ctx, uuid.Nil, testutil.LessonGoFree)
		if err != nil || pb.URL == "" {
			t.Fatalf("playback = %+v, %v", pb, err)
		}
	})
	t.Run("visitante no ve lección paga", func(t *testing.T) {
		if _, err := svc.Playback(ctx, uuid.Nil, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("err = %v, want ErrNoAccess", err)
		}
	})
	t.Run("usuario sin enrollment no ve lección paga", func(t *testing.T) {
		if _, err := svc.Playback(ctx, user, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("err = %v, want ErrNoAccess", err)
		}
	})
	t.Run("enrollment de carrera habilita el curso contenido y no otros", func(t *testing.T) {
		enroll(t, q, user, "career", testutil.CareerBackendGo)
		if _, err := svc.Playback(ctx, user, testutil.LessonGoPaid); err != nil {
			t.Fatalf("con carrera: %v", err)
		}
		if _, err := svc.Playback(ctx, user, testutil.LessonRedisPay); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("curso fuera de la carrera: err = %v", err)
		}
	})
	t.Run("enrollment directo de curso", func(t *testing.T) {
		enroll(t, q, other, "course", testutil.CourseRedis)
		if _, err := svc.Playback(ctx, other, testutil.LessonRedisPay); err != nil {
			t.Fatalf("con curso: %v", err)
		}
		if _, err := svc.Playback(ctx, other, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("otro curso: err = %v", err)
		}
	})
	t.Run("enrollment revocado no cuenta", func(t *testing.T) {
		revoked := newUser(t, q)
		e := enroll(t, q, revoked, "course", testutil.CourseGoDesdeCero)
		if _, err := q.RevokeEnrollment(ctx, e.ID); err != nil {
			t.Fatal(err)
		}
		if _, err := svc.Playback(ctx, revoked, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("revocado: err = %v", err)
		}
	})
	t.Run("lección inexistente", func(t *testing.T) {
		if _, err := svc.Playback(ctx, user, uuid.New()); !errors.Is(err, ErrLessonNotFound) {
			t.Fatalf("err = %v", err)
		}
	})
}

func TestPlayback_NotReadyUntilProcessed(t *testing.T) {
	svc, q, _ := newTestService(t)
	ctx := context.Background()
	user := newUser(t, q)
	enroll(t, q, user, "course", testutil.CourseGoDesdeCero)

	// Sin video asociado.
	if _, err := svc.Playback(ctx, user, testutil.LessonGoPaid); !errors.Is(err, ErrNotReady) {
		t.Fatalf("sin asset: err = %v", err)
	}

	// Upload iniciado: sigue sin estar listo.
	ticket, err := svc.StartUpload(ctx, testutil.LessonGoPaid)
	if err != nil || ticket.Headers["VideoId"] == "" {
		t.Fatalf("StartUpload = %+v, %v", ticket, err)
	}
	if _, err := svc.Playback(ctx, user, testutil.LessonGoPaid); !errors.Is(err, ErrNotReady) {
		t.Fatalf("uploading: err = %v", err)
	}

	// Webhook "finished" → ready con duración del provider.
	assetID := ticket.Headers["VideoId"]
	if err := svc.ApplyWebhook(ctx, WebhookEvent{VideoGUID: assetID, Status: whFinished}); err != nil {
		t.Fatal(err)
	}
	lesson, err := q.GetLesson(ctx, testutil.LessonGoPaid)
	if err != nil {
		t.Fatal(err)
	}
	if lesson.VideoStatus != "ready" || lesson.DurationS != 600 {
		t.Fatalf("tras webhook: status=%s duration=%d", lesson.VideoStatus, lesson.DurationS)
	}
	pb, err := svc.Playback(ctx, user, testutil.LessonGoPaid)
	if err != nil || pb.URL == "" {
		t.Fatalf("ready: %+v, %v", pb, err)
	}

	// Webhook "failed" pisa el estado; los informativos no.
	if err := svc.ApplyWebhook(ctx, WebhookEvent{VideoGUID: assetID, Status: whFailed}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Playback(ctx, user, testutil.LessonGoPaid); !errors.Is(err, ErrNotReady) {
		t.Fatalf("failed: err = %v", err)
	}
	if err := svc.ApplyWebhook(ctx, WebhookEvent{VideoGUID: "desconocido", Status: whFinished}); err != nil {
		t.Fatalf("asset desconocido debería ignorarse: %v", err)
	}
}
