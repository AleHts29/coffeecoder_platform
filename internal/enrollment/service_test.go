package enrollment

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func TestManualEnrollAndRevoke(t *testing.T) {
	q, _ := testutil.Queries(t)
	svc := NewService(q)
	ctx := context.Background()
	u, _ := q.CreateUser(ctx, store.CreateUserParams{Email: "e-" + uuid.NewString()[:8] + "@test.dev", Name: "Manual"})

	if _, err := svc.Enroll(ctx, u.ID, "bundle", testutil.CareerBackendGo); !errors.Is(err, ErrInvalidScope) {
		t.Fatalf("scope inválido: %v", err)
	}
	if _, err := svc.Enroll(ctx, u.ID, "career", uuid.New()); !errors.Is(err, ErrProductNotFound) {
		t.Fatalf("carrera inexistente: %v", err)
	}
	if _, err := svc.Enroll(ctx, uuid.New(), "career", testutil.CareerBackendGo); !errors.Is(err, ErrUserNotFound) {
		t.Fatalf("usuario inexistente: %v", err)
	}

	e, err := svc.Enroll(ctx, u.ID, "career", testutil.CareerBackendGo)
	if err != nil || e.OrderID.Valid {
		t.Fatalf("alta manual = %+v, %v", e, err)
	}
	ok, _ := q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: u.ID, ScopeID: testutil.CourseGoDesdeCero})
	if !ok {
		t.Fatal("sin acceso tras alta manual")
	}

	_, rows, err := svc.GetStudent(ctx, u.ID)
	if err != nil || len(rows) != 1 || rows[0].ProductTitle != "Backend Developer con Go" {
		t.Fatalf("detalle = %+v, %v", rows, err)
	}
	students, err := svc.ListStudents(ctx, "manual", 10, 0)
	if err != nil || len(students) == 0 || students[0].ActiveEnrollments != 1 {
		t.Fatalf("búsqueda = %+v, %v", students, err)
	}

	if _, err := svc.Revoke(ctx, e.ID); err != nil {
		t.Fatal(err)
	}
	ok, _ = q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: u.ID, ScopeID: testutil.CourseGoDesdeCero})
	if ok {
		t.Fatal("acceso vigente tras revocar")
	}
	// Revocar dos veces mantiene la fecha; re-enrolar reactiva.
	first, _ := svc.Revoke(ctx, e.ID)
	second, _ := svc.Revoke(ctx, e.ID)
	if !first.RevokedAt.Time.Equal(second.RevokedAt.Time) {
		t.Fatal("la fecha de revocación se movió")
	}
	again, err := svc.Enroll(ctx, u.ID, "career", testutil.CareerBackendGo)
	if err != nil || again.ID != e.ID || again.RevokedAt.Valid {
		t.Fatalf("reactivación = %+v, %v", again, err)
	}
	if _, err := svc.Revoke(ctx, uuid.New()); !errors.Is(err, ErrEnrollmentNotFound) {
		t.Fatalf("revocar inexistente: %v", err)
	}
}
