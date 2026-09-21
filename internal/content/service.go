package content

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrLessonNotFound = errors.New("esa lección no existe")
	ErrNoAccess       = errors.New("necesitás comprar el curso para ver esta lección")
	ErrNotArticle     = errors.New("esa lección no es de lectura")
	ErrDemoNotFound   = errors.New("esa demo no existe")
	ErrInvalidDemo    = errors.New("demo inválida")
	ErrSlugTaken      = errors.New("ya hay una demo con ese slug en este curso")
)

const (
	// maxDemoBytes: tope de docs/DEMOS.md. La CSP es la protección real;
	// esto evita cargar mamotretos a la base.
	maxDemoBytes = 200 << 10
	minHeightPx  = 120
	maxHeightPx  = 1600
)

type Service struct {
	q      *store.Queries
	secret string
}

func NewService(q *store.Queries, secret string) *Service {
	return &Service{q: q, secret: secret}
}

// Demo es la referencia que viaja al frontend: nunca el HTML.
type Demo struct {
	ID       uuid.UUID
	Slug     string
	Title    string
	HeightPx int32
	FrameURL string
}

// Content es una lección de lectura resuelta: texto + demos referenciadas.
type Content struct {
	Kind         string
	BodyMD       string
	ReadingTimeS int32
	Demos        []Demo
}

// Get verifica acceso con la misma regla que el playback de video
// (muestra gratis sin sesión; enrollment para el resto) y devuelve el
// cuerpo con las demos que el texto referencia, ya firmadas.
func (s *Service) Get(ctx context.Context, userID, lessonID uuid.UUID) (Content, error) {
	lesson, err := s.q.GetLesson(ctx, lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Content{}, ErrLessonNotFound
	} else if err != nil {
		return Content{}, err
	}

	ok, err := s.q.HasLessonAccess(ctx, store.HasLessonAccessParams{UserID: userID, ID: lessonID})
	if err != nil {
		return Content{}, err
	}
	if ok == nil || !*ok {
		return Content{}, ErrNoAccess
	}

	demos, err := s.resolveDemos(ctx, lesson.CourseID, lesson.BodyMd)
	if err != nil {
		return Content{}, err
	}
	return Content{
		Kind: lesson.Kind, BodyMD: lesson.BodyMd,
		ReadingTimeS: lesson.DurationS, Demos: demos,
	}, nil
}

// resolveDemos busca en la biblioteca del curso las demos que el texto
// referencia. Un slug inexistente simplemente no viaja: el frontend lo
// omite para el alumno y lo marca en la preview del admin.
func (s *Service) resolveDemos(ctx context.Context, courseID uuid.UUID, body string) ([]Demo, error) {
	slugs := DemoSlugs(body)
	if len(slugs) == 0 {
		return []Demo{}, nil
	}
	rows, err := s.q.ListDemosBySlugs(ctx, store.ListDemosBySlugsParams{CourseID: courseID, Slugs: slugs})
	if err != nil {
		return nil, err
	}
	now := time.Now()
	out := make([]Demo, 0, len(rows))
	for _, r := range rows {
		out = append(out, Demo{
			ID: r.ID, Slug: r.Slug, Title: r.Title, HeightPx: r.HeightPx,
			FrameURL: FrameURL(s.secret, r.ID, now),
		})
	}
	return out, nil
}

// Frame devuelve el HTML de una demo si la firma es válida y no venció.
func (s *Service) Frame(ctx context.Context, demoID uuid.UUID, exp, sig string) (string, error) {
	if !VerifyFrame(s.secret, demoID, exp, sig, time.Now()) {
		return "", ErrNoAccess
	}
	demo, err := s.q.GetDemo(ctx, demoID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrDemoNotFound
	} else if err != nil {
		return "", err
	}
	return demo.Html, nil
}

// --- Admin ---

// DemoInput es el formulario de una demo.
type DemoInput struct {
	Slug     string
	Title    string
	HTML     string
	HeightPx int32
}

var slugRe = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)

// forbidden son las reglas técnicas de docs/DEMOS.md que se pueden
// verificar por texto. No reemplazan a la CSP: son feedback temprano
// para quien escribe la demo.
var forbidden = []struct{ needle, rule string }{
	{"<script src=", "no puede cargar scripts externos (regla 1: un solo archivo)"},
	{"<iframe", "no puede incrustar otro iframe (regla 2: sin red)"},
	{"fetch(", "no puede usar fetch (regla 2: sin red)"},
	{"XMLHttpRequest", "no puede usar XMLHttpRequest (regla 2: sin red)"},
	{"WebSocket", "no puede usar WebSocket (regla 2: sin red)"},
	{"EventSource", "no puede usar EventSource (regla 2: sin red)"},
	{"localStorage", "no puede usar localStorage (regla 3: sin storage)"},
	{"sessionStorage", "no puede usar sessionStorage (regla 3: sin storage)"},
	{"document.cookie", "no puede usar document.cookie (regla 3: sin storage)"},
	{"window.parent", "no puede acceder a window.parent (regla 3: sin acceso al exterior)"},
	{"window.top", "no puede acceder a window.top (regla 3: sin acceso al exterior)"},
}

func (in *DemoInput) normalize() error {
	in.Title = strings.TrimSpace(in.Title)
	in.Slug = strings.TrimSpace(strings.ToLower(in.Slug))
	in.HTML = strings.TrimSpace(in.HTML)

	if in.Title == "" {
		return fmt.Errorf("%w: el título es obligatorio", ErrInvalidDemo)
	}
	if !slugRe.MatchString(in.Slug) {
		return fmt.Errorf("%w: el slug va en minúsculas, con números y guiones (ej: channels-buffer)", ErrInvalidDemo)
	}
	if in.HTML == "" {
		return fmt.Errorf("%w: el HTML no puede estar vacío", ErrInvalidDemo)
	}
	if len(in.HTML) > maxDemoBytes {
		return fmt.Errorf("%w: el HTML pesa %d KB y el máximo son 200 KB (regla 4)", ErrInvalidDemo, len(in.HTML)>>10)
	}
	lower := strings.ToLower(in.HTML)
	for _, f := range forbidden {
		if strings.Contains(lower, strings.ToLower(f.needle)) {
			return fmt.Errorf("%w: la demo %s", ErrInvalidDemo, f.rule)
		}
	}
	if in.HeightPx == 0 {
		in.HeightPx = 420
	}
	if in.HeightPx < minHeightPx || in.HeightPx > maxHeightPx {
		return fmt.Errorf("%w: el alto va entre %d y %d píxeles", ErrInvalidDemo, minHeightPx, maxHeightPx)
	}
	return nil
}

// DemoSummary es la fila de la biblioteca (sin HTML).
type DemoSummary struct {
	ID        uuid.UUID
	Slug      string
	Title     string
	HeightPx  int32
	SizeBytes int32
	UsedBy    []store.ListLessonsUsingDemoRow
}

func (s *Service) ListDemos(ctx context.Context, courseID uuid.UUID) ([]DemoSummary, error) {
	rows, err := s.q.ListDemosByCourse(ctx, courseID)
	if err != nil {
		return nil, err
	}
	out := make([]DemoSummary, 0, len(rows))
	for _, r := range rows {
		used, err := s.q.ListLessonsUsingDemo(ctx, store.ListLessonsUsingDemoParams{CourseID: courseID, Slug: r.Slug})
		if err != nil {
			return nil, err
		}
		out = append(out, DemoSummary{ID: r.ID, Slug: r.Slug, Title: r.Title, HeightPx: r.HeightPx, SizeBytes: r.SizeBytes, UsedBy: used})
	}
	return out, nil
}

func (s *Service) GetDemo(ctx context.Context, id uuid.UUID) (store.Demo, error) {
	d, err := s.q.GetDemo(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.Demo{}, ErrDemoNotFound
	}
	return d, err
}

func (s *Service) CreateDemo(ctx context.Context, courseID uuid.UUID, in DemoInput) (store.Demo, error) {
	if err := in.normalize(); err != nil {
		return store.Demo{}, err
	}
	d, err := s.q.CreateDemo(ctx, store.CreateDemoParams{
		CourseID: courseID, Slug: in.Slug, Title: in.Title, Html: in.HTML, HeightPx: in.HeightPx,
	})
	return d, mapErr(err)
}

func (s *Service) UpdateDemo(ctx context.Context, id uuid.UUID, in DemoInput) (store.Demo, error) {
	if err := in.normalize(); err != nil {
		return store.Demo{}, err
	}
	d, err := s.q.UpdateDemo(ctx, store.UpdateDemoParams{
		ID: id, Slug: in.Slug, Title: in.Title, Html: in.HTML, HeightPx: in.HeightPx,
	})
	return d, mapErr(err)
}

func (s *Service) DeleteDemo(ctx context.Context, id uuid.UUID) error {
	return s.q.DeleteDemo(ctx, id)
}

// SignFrameURL expone la firma para que el admin previsualice.
func (s *Service) SignFrameURL(id uuid.UUID) string {
	return FrameURL(s.secret, id, time.Now())
}

func mapErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrDemoNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505":
			return ErrSlugTaken
		case "23514":
			return fmt.Errorf("%w: %s", ErrInvalidDemo, pgErr.ConstraintName)
		}
	}
	return err
}
