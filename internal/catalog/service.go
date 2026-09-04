// Package catalog expone carreras, cursos y currícula al público.
// Solo lee: el CRUD vive en admin (P7). Nunca expone video_asset_id.
package catalog

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/alejandro/coffeecoder/internal/store"
)

var ErrNotFound = errors.New("no encontramos lo que buscás")

const statusPublished = "published"

type Service struct {
	q *store.Queries
}

func NewService(q *store.Queries) *Service {
	return &Service{q: q}
}

// Stats son los agregados de currícula de un curso.
type Stats struct {
	LessonCount int32
	DurationS   int32
}

// CourseSummary es un curso con sus agregados, para cards y listas.
type CourseSummary struct {
	store.Course
	Stats
}

// CareerSummary es una carrera con los agregados de sus cursos publicados.
type CareerSummary struct {
	store.Career
	CourseCount int32
	Stats
}

// CareerDetail es la página de venta: carrera + "el camino".
type CareerDetail struct {
	CareerSummary
	Courses []CourseSummary
}

// Module agrupa lecciones ya ordenadas.
type Module struct {
	ID       uuid.UUID
	Title    string
	Position int32
	Lessons  []store.GetCourseCurriculumRow
}

// CourseDetail es la página de curso: currícula y carreras que lo incluyen.
type CourseDetail struct {
	CourseSummary
	Modules []Module
	Careers []store.Career
}

func (s *Service) ListCareers(ctx context.Context) ([]CareerSummary, error) {
	careers, err := s.q.ListPublishedCareers(ctx)
	if err != nil {
		return nil, err
	}
	stats, err := s.statsByCourse(ctx)
	if err != nil {
		return nil, err
	}

	out := make([]CareerSummary, 0, len(careers))
	for _, c := range careers {
		courses, err := s.publishedCareerCourses(ctx, c.ID, stats)
		if err != nil {
			return nil, err
		}
		out = append(out, summarizeCareer(c, courses))
	}
	return out, nil
}

func (s *Service) GetCareer(ctx context.Context, slug string) (CareerDetail, error) {
	career, err := s.q.GetCareerBySlug(ctx, slug)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && career.Status != statusPublished) {
		return CareerDetail{}, ErrNotFound
	} else if err != nil {
		return CareerDetail{}, err
	}

	stats, err := s.statsByCourse(ctx)
	if err != nil {
		return CareerDetail{}, err
	}
	courses, err := s.publishedCareerCourses(ctx, career.ID, stats)
	if err != nil {
		return CareerDetail{}, err
	}
	return CareerDetail{
		CareerSummary: summarizeCareer(career, courses),
		Courses:       courses,
	}, nil
}

func (s *Service) ListCourses(ctx context.Context) ([]CourseSummary, error) {
	courses, err := s.q.ListPublishedCourses(ctx)
	if err != nil {
		return nil, err
	}
	stats, err := s.statsByCourse(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]CourseSummary, 0, len(courses))
	for _, c := range courses {
		out = append(out, CourseSummary{Course: c, Stats: stats[c.ID]})
	}
	return out, nil
}

func (s *Service) GetCourse(ctx context.Context, slug string) (CourseDetail, error) {
	course, err := s.q.GetCourseBySlug(ctx, slug)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && course.Status != statusPublished) {
		return CourseDetail{}, ErrNotFound
	} else if err != nil {
		return CourseDetail{}, err
	}

	rows, err := s.q.GetCourseCurriculum(ctx, course.ID)
	if err != nil {
		return CourseDetail{}, err
	}
	careers, err := s.q.ListPublishedCareersForCourse(ctx, course.ID)
	if err != nil {
		return CourseDetail{}, err
	}

	modules, stats := groupCurriculum(rows)
	return CourseDetail{
		CourseSummary: CourseSummary{Course: course, Stats: stats},
		Modules:       modules,
		Careers:       careers,
	}, nil
}

// --- helpers ---

func (s *Service) statsByCourse(ctx context.Context) (map[uuid.UUID]Stats, error) {
	rows, err := s.q.ListCourseStats(ctx)
	if err != nil {
		return nil, err
	}
	m := make(map[uuid.UUID]Stats, len(rows))
	for _, r := range rows {
		m[r.CourseID] = Stats{LessonCount: r.LessonCount, DurationS: r.DurationS}
	}
	return m, nil
}

// publishedCareerCourses devuelve los cursos publicados de una carrera en
// el orden del camino. Los borradores no se muestran al público aunque
// ya estén enlazados a la carrera.
func (s *Service) publishedCareerCourses(ctx context.Context, careerID uuid.UUID, stats map[uuid.UUID]Stats) ([]CourseSummary, error) {
	rows, err := s.q.ListCareerCourses(ctx, careerID)
	if err != nil {
		return nil, err
	}
	out := make([]CourseSummary, 0, len(rows))
	for _, r := range rows {
		if r.Status != statusPublished {
			continue
		}
		out = append(out, CourseSummary{
			Course: store.Course{
				ID: r.ID, Slug: r.Slug, Title: r.Title, Subtitle: r.Subtitle,
				Description: r.Description, Level: r.Level, PriceCents: r.PriceCents,
				Status: r.Status, Position: r.CareerPosition,
				CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt,
			},
			Stats: stats[r.ID],
		})
	}
	return out, nil
}

func summarizeCareer(c store.Career, courses []CourseSummary) CareerSummary {
	sum := CareerSummary{Career: c, CourseCount: int32(len(courses))}
	for _, course := range courses {
		sum.LessonCount += course.LessonCount
		sum.DurationS += course.DurationS
	}
	return sum
}

// groupCurriculum convierte las filas planas (ya ordenadas por módulo y
// lección) en módulos con sus lecciones, y calcula los agregados de paso.
func groupCurriculum(rows []store.GetCourseCurriculumRow) ([]Module, Stats) {
	var (
		modules []Module
		stats   Stats
	)
	for _, r := range rows {
		if len(modules) == 0 || modules[len(modules)-1].ID != r.ModuleID {
			modules = append(modules, Module{ID: r.ModuleID, Title: r.ModuleTitle, Position: r.ModulePosition})
		}
		last := &modules[len(modules)-1]
		last.Lessons = append(last.Lessons, r)
		stats.LessonCount++
		stats.DurationS += r.DurationS
	}
	return modules, stats
}
