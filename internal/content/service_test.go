package content

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/store"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

const secret = "secreto-de-test"

func setup(t *testing.T) (*Service, *store.Queries) {
	t.Helper()
	q, _ := testutil.Queries(t)
	return NewService(q, secret), q
}

func newUser(t *testing.T, q *store.Queries) uuid.UUID {
	t.Helper()
	u, err := q.CreateUser(context.Background(), store.CreateUserParams{Email: "c-" + uuid.NewString()[:8] + "@test.dev"})
	if err != nil {
		t.Fatal(err)
	}
	return u.ID
}

// Criterio 1 y 3: la muestra gratis se lee sin sesión y trae su demo
// firmada; el contenido pago exige acceso.
func TestGet_AccessRules(t *testing.T) {
	svc, q := setup(t)
	ctx := context.Background()

	c, err := svc.Get(ctx, uuid.Nil, testutil.LessonArticle)
	if err != nil {
		t.Fatalf("visitante en muestra gratis: %v", err)
	}
	if c.Kind != "article" || !strings.Contains(c.BodyMD, "::demo[channels-buffer]") || c.ReadingTimeS == 0 {
		t.Fatalf("contenido = %+v", c)
	}
	if len(c.Demos) != 1 || c.Demos[0].Slug != "channels-buffer" || c.Demos[0].HeightPx != 420 {
		t.Fatalf("demos = %+v", c.Demos)
	}
	if !strings.Contains(c.Demos[0].FrameURL, "sig=") {
		t.Fatalf("la demo no viene firmada: %s", c.Demos[0].FrameURL)
	}
	// Solo viaja la demo referenciada, no toda la biblioteca.
	for _, d := range c.Demos {
		if d.Slug == "lfo-amplitud" {
			t.Fatal("viajó una demo que el texto no referencia")
		}
	}

	// Lección paga: visitante y alumno sin enrollment quedan afuera.
	if _, err := svc.Get(ctx, uuid.Nil, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("visitante en lección paga: %v", err)
	}
	user := newUser(t, q)
	if _, err := svc.Get(ctx, user, testutil.LessonGoPaid); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("alumno sin enrollment: %v", err)
	}
	if _, err := svc.Get(ctx, user, uuid.New()); !errors.Is(err, ErrLessonNotFound) {
		t.Fatalf("lección inexistente: %v", err)
	}
	if _, err := q.CreateEnrollment(ctx, store.CreateEnrollmentParams{UserID: user, Scope: "course", ScopeID: testutil.CourseGoDesdeCero}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Get(ctx, user, testutil.LessonGoPaid); err != nil {
		t.Fatalf("con enrollment: %v", err)
	}
}

// Criterio 3: el HTML solo sale por el frame y solo con firma válida.
func TestFrame_SignatureRequired(t *testing.T) {
	svc, _ := setup(t)
	ctx := context.Background()

	c, err := svc.Get(ctx, uuid.Nil, testutil.LessonArticle)
	if err != nil {
		t.Fatal(err)
	}
	url := c.Demos[0].FrameURL
	exp := url[strings.Index(url, "exp=")+4 : strings.Index(url, "&sig=")]
	sig := url[strings.Index(url, "&sig=")+5:]

	html, err := svc.Frame(ctx, testutil.DemoChannels, exp, sig)
	if err != nil || !strings.Contains(html, "<!doctype html>") {
		t.Fatalf("frame con firma válida: %v", err)
	}
	for _, bad := range [][2]string{{exp, "firma-falsa"}, {"99999999999", sig}, {"0", sig}} {
		if _, err := svc.Frame(ctx, testutil.DemoChannels, bad[0], bad[1]); !errors.Is(err, ErrNoAccess) {
			t.Fatalf("frame con exp=%q sig=%q: %v", bad[0], bad[1], err)
		}
	}
	// La firma de una demo no sirve para otra.
	if _, err := svc.Frame(ctx, testutil.DemoLFO, exp, sig); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("firma reutilizada entre demos: %v", err)
	}
}

// Criterio 5: la validación dice qué regla de DEMOS.md se rompe.
func TestCreateDemo_Validation(t *testing.T) {
	svc, _ := setup(t)
	ctx := context.Background()
	ok := `<!doctype html><html><body><script>const x=1</script></body></html>`

	cases := []struct{ name, html, want string }{
		{"script externo", `<script src="https://cdn.test/d3.js"></script>` + ok, "scripts externos"},
		{"fetch", `<script>fetch('/api')</script>`, "fetch"},
		{"xhr", `<script>new XMLHttpRequest()</script>`, "XMLHttpRequest"},
		{"websocket", `<script>new WebSocket('ws://x')</script>`, "WebSocket"},
		{"localStorage", `<script>localStorage.setItem('a',1)</script>`, "localStorage"},
		{"parent", `<script>window.parent.postMessage(1)</script>`, "window.parent"},
		{"iframe", `<iframe src="x"></iframe>`, "iframe"},
		{"vacío", "   ", "vacío"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "x-" + uuid.NewString()[:6], Title: "T", HTML: c.html, HeightPx: 300})
			if !errors.Is(err, ErrInvalidDemo) || !strings.Contains(err.Error(), c.want) {
				t.Fatalf("err = %v, quería que mencionara %q", err, c.want)
			}
		})
	}

	// Slug y alto fuera de rango.
	if _, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "Con Mayúsculas", Title: "T", HTML: ok}); !errors.Is(err, ErrInvalidDemo) {
		t.Fatalf("slug inválido: %v", err)
	}
	if _, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "alto", Title: "T", HTML: ok, HeightPx: 5000}); !errors.Is(err, ErrInvalidDemo) {
		t.Fatalf("alto inválido: %v", err)
	}
	if _, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "grande", Title: "T", HTML: strings.Repeat("a", 210<<10)}); !errors.Is(err, ErrInvalidDemo) {
		t.Fatalf("demo enorme: %v", err)
	}
	// Slug repetido dentro del curso.
	if _, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "channels-buffer", Title: "T", HTML: ok}); !errors.Is(err, ErrSlugTaken) {
		t.Fatalf("slug repetido: %v", err)
	}
}

// Criterio 2: crear una demo y referenciarla desde un artículo.
func TestCreateDemo_AndReference(t *testing.T) {
	svc, q := setup(t)
	ctx := context.Background()

	d, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{
		Slug: "lfo-copia", Title: "LFO (copia)", HTML: "<!doctype html><html><body><input type=range></body></html>", HeightPx: 520,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(svc.SignFrameURL(d.ID), d.ID.String()) {
		t.Fatal("preview del admin sin URL firmada")
	}

	// La insertamos en la lección de lectura (muestra gratis) y la leemos
	// como alumno sin sesión, igual que en la preview del admin.
	target := testutil.LessonArticle
	if _, err := q.UpdateLesson(ctx, store.UpdateLessonParams{
		ID: target, Title: "Con demo", BodyMd: "Texto.\n\n::demo[lfo-copia]\n", DurationS: 60, IsFreeSample: true,
	}); err != nil {
		t.Fatal(err)
	}
	c, err := svc.Get(ctx, uuid.Nil, target)
	if err != nil || len(c.Demos) != 1 || c.Demos[0].Slug != "lfo-copia" || c.Demos[0].HeightPx != 520 {
		t.Fatalf("demos resueltas = %+v, %v", c.Demos, err)
	}

	// Aparece en la biblioteca con las lecciones que la usan.
	lib, err := svc.ListDemos(ctx, testutil.CourseGoDesdeCero)
	if err != nil {
		t.Fatal(err)
	}
	var found *DemoSummary
	for i := range lib {
		if lib[i].Slug == "lfo-copia" {
			found = &lib[i]
		}
	}
	if found == nil || found.SizeBytes == 0 || len(found.UsedBy) != 1 {
		t.Fatalf("biblioteca = %+v", lib)
	}

	// Un slug que no existe en la biblioteca simplemente no viaja.
	if _, err := q.UpdateLesson(ctx, store.UpdateLessonParams{ID: target, Title: "Con demo", BodyMd: "::demo[no-existe]\n", DurationS: 60, IsFreeSample: true}); err != nil {
		t.Fatal(err)
	}
	c, err = svc.Get(ctx, uuid.Nil, target)
	if err != nil || len(c.Demos) != 0 {
		t.Fatalf("slug inexistente = %+v, %v", c.Demos, err)
	}
}

func TestUpdateAndDeleteDemo(t *testing.T) {
	svc, _ := setup(t)
	ctx := context.Background()
	d, err := svc.CreateDemo(ctx, testutil.CourseGoDesdeCero, DemoInput{Slug: "tmp", Title: "T", HTML: "<html><body>x</body></html>", HeightPx: 200})
	if err != nil {
		t.Fatal(err)
	}
	up, err := svc.UpdateDemo(ctx, d.ID, DemoInput{Slug: "tmp2", Title: "T2", HTML: "<html><body>y</body></html>", HeightPx: 300})
	if err != nil || up.Slug != "tmp2" || up.HeightPx != 300 {
		t.Fatalf("update = %+v, %v", up, err)
	}
	if err := svc.DeleteDemo(ctx, d.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.GetDemo(ctx, d.ID); !errors.Is(err, ErrDemoNotFound) {
		t.Fatalf("tras borrar: %v", err)
	}
	if _, err := svc.Frame(ctx, d.ID, "", ""); !errors.Is(err, ErrNoAccess) {
		t.Fatalf("frame de demo borrada sin firma: %v", err)
	}
	// Con firma válida pero ya borrada: 404, no 500.
	url := FrameURL(secret, d.ID, time.Now())
	exp := url[strings.Index(url, "exp=")+4 : strings.Index(url, "&sig=")]
	sig := url[strings.Index(url, "&sig=")+5:]
	if _, err := svc.Frame(ctx, d.ID, exp, sig); !errors.Is(err, ErrDemoNotFound) {
		t.Fatalf("frame de demo borrada: %v", err)
	}
}
