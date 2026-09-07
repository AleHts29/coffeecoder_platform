package catalog

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrInvalid    = errors.New("datos inválidos")
	ErrSlugTaken  = errors.New("ese slug ya está en uso")
	ErrInUse      = errors.New("no se puede borrar: el curso forma parte de una carrera")
	ErrBadReorder = errors.New("la lista de orden no coincide con los elementos existentes")
)

var (
	levels   = map[string]bool{"suave": true, "medio": true, "intenso": true}
	statuses = map[string]bool{"draft": true, "published": true, "archived": true}
)

// AdminService es el CRUD de contenido. Necesita el pool para las
// operaciones que deben ser atómicas (reordenar, reemplazar el camino).
type AdminService struct {
	q    *store.Queries
	pool *pgxpool.Pool
}

func NewAdminService(q *store.Queries, pool *pgxpool.Pool) *AdminService {
	return &AdminService{q: q, pool: pool}
}

// ProductInput es el formulario de curso y carrera (mismos campos).
type ProductInput struct {
	Slug        string
	Title       string
	Subtitle    string
	Description string
	Level       string
	PriceCents  int32
	Status      string
}

func (in *ProductInput) normalize() error {
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		return fmt.Errorf("%w: el título es obligatorio", ErrInvalid)
	}
	in.Slug = Slugify(in.Slug)
	if in.Slug == "" {
		in.Slug = Slugify(in.Title)
	}
	if in.Slug == "" {
		return fmt.Errorf("%w: no se pudo derivar un slug del título", ErrInvalid)
	}
	if in.Level == "" {
		in.Level = "medio"
	}
	if !levels[in.Level] {
		return fmt.Errorf("%w: el tueste debe ser suave, medio o intenso", ErrInvalid)
	}
	if in.Status == "" {
		in.Status = "draft"
	}
	if !statuses[in.Status] {
		return fmt.Errorf("%w: el estado debe ser draft, published o archived", ErrInvalid)
	}
	if in.PriceCents < 0 {
		return fmt.Errorf("%w: el precio no puede ser negativo", ErrInvalid)
	}
	return nil
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

// Slugify: minúsculas, sin acentos comunes, guiones.
func Slugify(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	r := strings.NewReplacer("á", "a", "é", "e", "í", "i", "ó", "o", "ú", "u", "ñ", "n", "ü", "u")
	s = r.Replace(s)
	s = slugRe.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}

// --- Carreras ---

func (s *AdminService) ListCareers(ctx context.Context) ([]store.AdminListCareersRow, error) {
	return s.q.AdminListCareers(ctx)
}

func (s *AdminService) CreateCareer(ctx context.Context, in ProductInput) (store.Career, error) {
	if err := in.normalize(); err != nil {
		return store.Career{}, err
	}
	c, err := s.q.CreateCareer(ctx, store.CreateCareerParams{
		Slug: in.Slug, Title: in.Title, Subtitle: in.Subtitle, Description: in.Description,
		Level: in.Level, PriceCents: in.PriceCents, Status: in.Status,
	})
	return c, mapErr(err)
}

func (s *AdminService) UpdateCareer(ctx context.Context, id uuid.UUID, in ProductInput) (store.Career, error) {
	if err := in.normalize(); err != nil {
		return store.Career{}, err
	}
	c, err := s.q.UpdateCareer(ctx, store.UpdateCareerParams{
		ID: id, Slug: in.Slug, Title: in.Title, Subtitle: in.Subtitle, Description: in.Description,
		Level: in.Level, PriceCents: in.PriceCents, Status: in.Status,
	})
	return c, mapErr(err)
}

func (s *AdminService) DeleteCareer(ctx context.Context, id uuid.UUID) error {
	return s.q.DeleteCareer(ctx, id)
}

// GetCareer: carrera con sus cursos (cualquier estado) en orden.
func (s *AdminService) GetCareer(ctx context.Context, id uuid.UUID) (store.Career, []store.ListCareerCoursesRow, error) {
	c, err := s.q.GetCareer(ctx, id)
	if err != nil {
		return store.Career{}, nil, mapErr(err)
	}
	courses, err := s.q.ListCareerCourses(ctx, id)
	return c, courses, err
}

// SetCareerCourses reemplaza el camino completo en una transacción.
func (s *AdminService) SetCareerCourses(ctx context.Context, careerID uuid.UUID, courseIDs []uuid.UUID) error {
	if _, err := s.q.GetCareer(ctx, careerID); err != nil {
		return mapErr(err)
	}
	seen := map[uuid.UUID]bool{}
	for _, id := range courseIDs {
		if seen[id] {
			return fmt.Errorf("%w: curso repetido", ErrInvalid)
		}
		seen[id] = true
		if _, err := s.q.GetCourse(ctx, id); err != nil {
			return fmt.Errorf("%w: curso %s inexistente", ErrInvalid, id)
		}
	}
	return s.tx(ctx, func(q *store.Queries) error {
		if err := q.DeleteCareerCourses(ctx, careerID); err != nil {
			return err
		}
		for i, id := range courseIDs {
			if err := q.InsertCareerCourse(ctx, store.InsertCareerCourseParams{CareerID: careerID, CourseID: id, Position: int32(i + 1)}); err != nil {
				return err
			}
		}
		return nil
	})
}

// --- Cursos ---

func (s *AdminService) ListCourses(ctx context.Context) ([]store.AdminListCoursesRow, error) {
	return s.q.AdminListCourses(ctx)
}

func (s *AdminService) CreateCourse(ctx context.Context, in ProductInput) (store.Course, error) {
	if err := in.normalize(); err != nil {
		return store.Course{}, err
	}
	c, err := s.q.CreateCourse(ctx, store.CreateCourseParams{
		Slug: in.Slug, Title: in.Title, Subtitle: in.Subtitle, Description: in.Description,
		Level: in.Level, PriceCents: in.PriceCents, Status: in.Status,
	})
	return c, mapErr(err)
}

func (s *AdminService) UpdateCourse(ctx context.Context, id uuid.UUID, in ProductInput) (store.Course, error) {
	if err := in.normalize(); err != nil {
		return store.Course{}, err
	}
	c, err := s.q.UpdateCourse(ctx, store.UpdateCourseParams{
		ID: id, Slug: in.Slug, Title: in.Title, Subtitle: in.Subtitle, Description: in.Description,
		Level: in.Level, PriceCents: in.PriceCents, Status: in.Status,
	})
	return c, mapErr(err)
}

func (s *AdminService) DeleteCourse(ctx context.Context, id uuid.UUID) error {
	return mapErr(s.q.DeleteCourse(ctx, id))
}

// AdminModule es un módulo con sus lecciones y el estado del video.
type AdminModule struct {
	ID       uuid.UUID
	Title    string
	Position int32
	Lessons  []AdminLesson
}

type AdminLesson struct {
	ID           uuid.UUID
	Title        string
	Description  string
	DurationS    int32
	IsFreeSample bool
	Position     int32
	VideoStatus  string
}

func (s *AdminService) GetCourse(ctx context.Context, id uuid.UUID) (store.Course, []AdminModule, error) {
	c, err := s.q.GetCourse(ctx, id)
	if err != nil {
		return store.Course{}, nil, mapErr(err)
	}
	rows, err := s.q.AdminGetCourseCurriculum(ctx, id)
	if err != nil {
		return store.Course{}, nil, err
	}
	modules := []AdminModule{}
	for _, r := range rows {
		if len(modules) == 0 || modules[len(modules)-1].ID != r.ModuleID {
			modules = append(modules, AdminModule{ID: r.ModuleID, Title: r.ModuleTitle, Position: r.ModulePosition, Lessons: []AdminLesson{}})
		}
		if !r.LessonID.Valid {
			continue
		}
		m := &modules[len(modules)-1]
		m.Lessons = append(m.Lessons, AdminLesson{
			ID: uuid.UUID(r.LessonID.Bytes), Title: deref(r.LessonTitle), Description: deref(r.Description),
			DurationS: derefI(r.DurationS), IsFreeSample: r.IsFreeSample != nil && *r.IsFreeSample,
			Position: derefI(r.LessonPosition), VideoStatus: deref(r.VideoStatus),
		})
	}
	return c, modules, nil
}

// --- Módulos ---

func (s *AdminService) CreateModule(ctx context.Context, courseID uuid.UUID, title string) (store.Module, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return store.Module{}, fmt.Errorf("%w: el título es obligatorio", ErrInvalid)
	}
	if _, err := s.q.GetCourse(ctx, courseID); err != nil {
		return store.Module{}, mapErr(err)
	}
	return s.q.CreateModule(ctx, store.CreateModuleParams{CourseID: courseID, Title: title})
}

func (s *AdminService) UpdateModule(ctx context.Context, id uuid.UUID, title string) (store.Module, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return store.Module{}, fmt.Errorf("%w: el título es obligatorio", ErrInvalid)
	}
	m, err := s.q.UpdateModule(ctx, store.UpdateModuleParams{ID: id, Title: title})
	return m, mapErr(err)
}

func (s *AdminService) DeleteModule(ctx context.Context, id uuid.UUID) error {
	return s.q.DeleteModule(ctx, id)
}

// ReorderModules recibe la lista completa de ids en el orden deseado.
// Debe ser exactamente el conjunto de módulos del curso.
func (s *AdminService) ReorderModules(ctx context.Context, courseID uuid.UUID, ids []uuid.UUID) error {
	current, err := s.q.ListModuleIDs(ctx, courseID)
	if err != nil {
		return err
	}
	if !sameSet(current, ids) {
		return ErrBadReorder
	}
	return s.tx(ctx, func(q *store.Queries) error {
		for i, id := range ids {
			if err := q.SetModulePosition(ctx, store.SetModulePositionParams{ID: id, Position: int32(i + 1)}); err != nil {
				return err
			}
		}
		return nil
	})
}

// --- Lecciones ---

type LessonInput struct {
	Title        string
	Description  string
	DurationS    int32
	IsFreeSample bool
}

func (in *LessonInput) normalize() error {
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		return fmt.Errorf("%w: el título es obligatorio", ErrInvalid)
	}
	if in.DurationS < 0 {
		return fmt.Errorf("%w: la duración no puede ser negativa", ErrInvalid)
	}
	return nil
}

func (s *AdminService) CreateLesson(ctx context.Context, moduleID uuid.UUID, in LessonInput) (store.Lesson, error) {
	if err := in.normalize(); err != nil {
		return store.Lesson{}, err
	}
	if _, err := s.q.GetModule(ctx, moduleID); err != nil {
		return store.Lesson{}, mapErr(err)
	}
	return s.q.CreateLesson(ctx, store.CreateLessonParams{
		ModuleID: moduleID, Title: in.Title, Description: in.Description, DurationS: in.DurationS, IsFreeSample: in.IsFreeSample,
	})
}

func (s *AdminService) UpdateLesson(ctx context.Context, id uuid.UUID, in LessonInput) (store.Lesson, error) {
	if err := in.normalize(); err != nil {
		return store.Lesson{}, err
	}
	l, err := s.q.UpdateLesson(ctx, store.UpdateLessonParams{
		ID: id, Title: in.Title, Description: in.Description, DurationS: in.DurationS, IsFreeSample: in.IsFreeSample,
	})
	return l, mapErr(err)
}

func (s *AdminService) DeleteLesson(ctx context.Context, id uuid.UUID) error {
	return s.q.DeleteLesson(ctx, id)
}

func (s *AdminService) ReorderLessons(ctx context.Context, moduleID uuid.UUID, ids []uuid.UUID) error {
	current, err := s.q.ListLessonIDs(ctx, moduleID)
	if err != nil {
		return err
	}
	if !sameSet(current, ids) {
		return ErrBadReorder
	}
	return s.tx(ctx, func(q *store.Queries) error {
		for i, id := range ids {
			if err := q.SetLessonPosition(ctx, store.SetLessonPositionParams{ID: id, Position: int32(i + 1)}); err != nil {
				return err
			}
		}
		return nil
	})
}

// --- helpers ---

// tx corre fn en una transacción. En tests (sin pool) usa las queries
// tal cual: ya corren dentro de la transacción del test.
func (s *AdminService) tx(ctx context.Context, fn func(q *store.Queries) error) error {
	if s.pool == nil {
		return fn(s.q)
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func sameSet(a, b []uuid.UUID) bool {
	if len(a) != len(b) {
		return false
	}
	seen := make(map[uuid.UUID]bool, len(a))
	for _, id := range a {
		seen[id] = true
	}
	for _, id := range b {
		if !seen[id] {
			return false
		}
		delete(seen, id)
	}
	return len(seen) == 0
}

func mapErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505": // unique_violation (slug)
			return ErrSlugTaken
		case "23503": // foreign_key_violation (curso en carrera)
			return ErrInUse
		case "23514": // check_violation
			return fmt.Errorf("%w: %s", ErrInvalid, pgErr.ConstraintName)
		}
	}
	return err
}

func deref(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func derefI(p *int32) int32 {
	if p == nil {
		return 0
	}
	return *p
}
