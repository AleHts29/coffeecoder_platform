package billing

import (
	"context"
	"errors"
	"log/slog"
	"testing"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/mail"
	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func setup(t *testing.T) (*Service, *Fake, *store.Queries, store.User) {
	t.Helper()
	q, _ := testutil.Queries(t)
	user, err := q.CreateUser(context.Background(), store.CreateUserParams{Email: "b-" + uuid.NewString()[:8] + "@test.dev", Name: "Comprador Uno"})
	if err != nil {
		t.Fatal(err)
	}
	fake := NewFake("http://front.test")
	cfg := config.BillingConfig{Provider: "fake", Currency: "ARS", USDRate: 1350}
	return NewService(q, fake, mail.NewLog(slog.Default()), cfg, "http://front.test", slog.Default()), fake, q, user
}

func TestCreateOrder_ConvertsAndRejectsOwned(t *testing.T) {
	svc, _, q, user := setup(t)
	ctx := context.Background()

	res, err := svc.CreateOrder(ctx, user, "course", testutil.CourseGoDesdeCero)
	if err != nil {
		t.Fatal(err)
	}
	// USD 49 × 1350 = ARS 66.150
	if res.Order.AmountCents != 6615000 || res.Order.Currency != "ARS" || res.Order.Status != "pending" {
		t.Fatalf("orden = %+v", res.Order)
	}
	if res.CheckoutURL == "" {
		t.Fatal("sin checkout url")
	}
	// Segundo intento sin pagar: misma orden, sin duplicar pendings.
	again, err := svc.CreateOrder(ctx, user, "course", testutil.CourseGoDesdeCero)
	if err != nil || again.Order.ID != res.Order.ID {
		t.Fatalf("segunda orden = %v, %v (esperaba reutilizar %v)", again.Order.ID, err, res.Order.ID)
	}

	if _, err := svc.CreateOrder(ctx, user, "course", uuid.MustParse("00000000-0000-4000-8000-020000000006")); !errors.Is(err, ErrProductNotFound) {
		t.Fatalf("curso borrador: %v", err)
	}
	if _, err := svc.CreateOrder(ctx, user, "career", uuid.New()); !errors.Is(err, ErrProductNotFound) {
		t.Fatalf("carrera inexistente: %v", err)
	}

	// Con acceso previo, no se vende dos veces.
	if _, err := q.CreateEnrollment(ctx, store.CreateEnrollmentParams{UserID: user.ID, Scope: "career", ScopeID: testutil.CareerBackendGo}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateOrder(ctx, user, "course", testutil.CourseGoDesdeCero); !errors.Is(err, ErrAlreadyOwned) {
		t.Fatalf("curso incluido en la carrera comprada: %v", err)
	}
	if _, err := svc.CreateOrder(ctx, user, "career", testutil.CareerBackendGo); !errors.Is(err, ErrAlreadyOwned) {
		t.Fatalf("carrera comprada: %v", err)
	}
}

func TestWebhook_IdempotentApproval(t *testing.T) {
	svc, _, q, user := setup(t)
	ctx := context.Background()
	res, err := svc.CreateOrder(ctx, user, "course", testutil.CourseRedis)
	if err != nil {
		t.Fatal(err)
	}
	paymentID := "fake-" + res.Order.ID.String()

	// El mismo webhook N veces → exactamente un enrollment.
	for i := 0; i < 5; i++ {
		if err := svc.HandlePayment(ctx, paymentID); err != nil {
			t.Fatalf("webhook %d: %v", i, err)
		}
	}
	order, _ := q.GetOrder(ctx, res.Order.ID)
	if order.Status != "approved" || order.ProviderPaymentID == nil || *order.ProviderPaymentID != paymentID {
		t.Fatalf("orden tras webhook = %+v", order)
	}
	enrollments, _ := q.ListUserEnrollments(ctx, user.ID)
	if len(enrollments) != 1 || enrollments[0].Scope != "course" || enrollments[0].ScopeID != testutil.CourseRedis {
		t.Fatalf("enrollments = %+v", enrollments)
	}
	ok, _ := q.HasLessonAccess(ctx, store.HasLessonAccessParams{UserID: user.ID, ID: testutil.LessonRedisPay})
	if ok == nil || !*ok {
		t.Fatal("sin acceso a la lección tras aprobar")
	}
	// Pago desconocido: se ignora sin error.
	if err := svc.HandlePayment(ctx, "fake-"+uuid.NewString()); err != nil {
		t.Fatalf("pago de orden inexistente: %v", err)
	}
}

func TestWebhook_CareerGrantsAllCourses(t *testing.T) {
	svc, _, q, user := setup(t)
	ctx := context.Background()
	res, err := svc.CreateOrder(ctx, user, "career", testutil.CareerBackendGo)
	if err != nil {
		t.Fatal(err)
	}
	if res.Order.AmountCents != 129*1350*100 {
		t.Fatalf("monto carrera = %d", res.Order.AmountCents)
	}
	if err := svc.HandlePayment(ctx, "fake-"+res.Order.ID.String()); err != nil {
		t.Fatal(err)
	}
	courses, _ := q.ListCareerCourses(ctx, testutil.CareerBackendGo)
	for _, c := range courses {
		ok, _ := q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: user.ID, ScopeID: c.ID})
		if !ok {
			t.Fatalf("sin acceso a %s tras comprar la carrera", c.Slug)
		}
	}
	ok, _ := q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: user.ID, ScopeID: testutil.CourseRedis})
	if ok {
		t.Fatal("la carrera no incluye redis")
	}
	enrollments, _ := q.ListUserEnrollments(ctx, user.ID)
	if len(enrollments) != 1 {
		t.Fatalf("la carrera no se explota en N enrollments: %d", len(enrollments))
	}
}

func TestWebhook_RejectedAndRefund(t *testing.T) {
	svc, fake, q, user := setup(t)
	ctx := context.Background()

	rejected, _ := svc.CreateOrder(ctx, user, "course", testutil.CourseRedis)
	fake.SetStatus("fake-"+rejected.Order.ID.String(), PaymentRejected)
	if err := svc.HandlePayment(ctx, "fake-"+rejected.Order.ID.String()); err != nil {
		t.Fatal(err)
	}
	o, _ := q.GetOrder(ctx, rejected.Order.ID)
	if o.Status != "rejected" {
		t.Fatalf("status = %s", o.Status)
	}
	if e, _ := q.ListUserEnrollments(ctx, user.ID); len(e) != 0 {
		t.Fatal("un rechazo no da acceso")
	}
	if _, err := svc.Refund(ctx, rejected.Order.ID); !errors.Is(err, ErrNotRefundable) {
		t.Fatalf("reembolsar rechazada: %v", err)
	}

	approved, _ := svc.CreateOrder(ctx, user, "course", testutil.CourseRedis)
	if err := svc.HandlePayment(ctx, "fake-"+approved.Order.ID.String()); err != nil {
		t.Fatal(err)
	}
	refunded, err := svc.Refund(ctx, approved.Order.ID)
	if err != nil || refunded.Status != "refunded" {
		t.Fatalf("refund = %+v, %v", refunded, err)
	}
	if !fake.Refunded("fake-" + approved.Order.ID.String()) {
		t.Fatal("no se reembolsó en el provider")
	}
	ok, _ := q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: user.ID, ScopeID: testutil.CourseRedis})
	if ok {
		t.Fatal("el reembolso debe revocar el acceso")
	}
	// Volver a comprar tras el reembolso reactiva el enrollment (ON CONFLICT).
	again, _ := svc.CreateOrder(ctx, user, "course", testutil.CourseRedis)
	if err := svc.HandlePayment(ctx, "fake-"+again.Order.ID.String()); err != nil {
		t.Fatal(err)
	}
	ok, _ = q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: user.ID, ScopeID: testutil.CourseRedis})
	if !ok {
		t.Fatal("recompra tras reembolso no dio acceso")
	}
}
