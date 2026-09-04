package catalog

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

type Handler struct {
	svc    *Service
	logger *slog.Logger
}

func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, logger: logger}
}

// Mount registra las rutas públicas del catálogo bajo el router recibido.
func (h *Handler) Mount(r chi.Router) {
	r.Get("/careers", h.listCareers)
	r.Get("/careers/{slug}", h.getCareer)
	r.Get("/courses", h.listCourses)
	r.Get("/courses/{slug}", h.getCourse)
}

// --- DTOs: shape público explícito. Ningún struct de store sale directo. ---

type courseDTO struct {
	ID          string `json:"id"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	Subtitle    string `json:"subtitle"`
	Description string `json:"description"`
	Level       string `json:"level"`
	PriceCents  int32  `json:"price_cents"`
	Position    int32  `json:"position"`
	LessonCount int32  `json:"lesson_count"`
	DurationS   int32  `json:"duration_s"`
}

type careerDTO struct {
	ID          string `json:"id"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	Subtitle    string `json:"subtitle"`
	Description string `json:"description"`
	Level       string `json:"level"`
	PriceCents  int32  `json:"price_cents"`
	Position    int32  `json:"position"`
	CourseCount int32  `json:"course_count"`
	LessonCount int32  `json:"lesson_count"`
	DurationS   int32  `json:"duration_s"`
}

type careerDetailDTO struct {
	careerDTO
	Courses []courseDTO `json:"courses"`
}

type lessonDTO struct {
	ID           string `json:"id"`
	Title        string `json:"title"`
	Description  string `json:"description"`
	DurationS    int32  `json:"duration_s"`
	IsFreeSample bool   `json:"is_free_sample"`
	Position     int32  `json:"position"`
}

type moduleDTO struct {
	ID       string      `json:"id"`
	Title    string      `json:"title"`
	Position int32       `json:"position"`
	Lessons  []lessonDTO `json:"lessons"`
}

type careerRefDTO struct {
	Slug       string `json:"slug"`
	Title      string `json:"title"`
	PriceCents int32  `json:"price_cents"`
}

type courseDetailDTO struct {
	courseDTO
	Modules []moduleDTO    `json:"modules"`
	Careers []careerRefDTO `json:"careers"`
}

func toCourseDTO(c CourseSummary) courseDTO {
	return courseDTO{
		ID: c.ID.String(), Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle,
		Description: c.Description, Level: c.Level, PriceCents: c.PriceCents,
		Position: c.Position, LessonCount: c.LessonCount, DurationS: c.DurationS,
	}
}

func toCareerDTO(c CareerSummary) careerDTO {
	return careerDTO{
		ID: c.ID.String(), Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle,
		Description: c.Description, Level: c.Level, PriceCents: c.PriceCents,
		Position: c.Position, CourseCount: c.CourseCount,
		LessonCount: c.LessonCount, DurationS: c.DurationS,
	}
}

func toCourseDTOs(in []CourseSummary) []courseDTO {
	out := make([]courseDTO, 0, len(in))
	for _, c := range in {
		out = append(out, toCourseDTO(c))
	}
	return out
}

func toModuleDTOs(in []Module) []moduleDTO {
	out := make([]moduleDTO, 0, len(in))
	for _, m := range in {
		lessons := make([]lessonDTO, 0, len(m.Lessons))
		for _, l := range m.Lessons {
			lessons = append(lessons, lessonDTO{
				ID: l.LessonID.String(), Title: l.LessonTitle, Description: l.Description,
				DurationS: l.DurationS, IsFreeSample: l.IsFreeSample, Position: l.LessonPosition,
			})
		}
		out = append(out, moduleDTO{ID: m.ID.String(), Title: m.Title, Position: m.Position, Lessons: lessons})
	}
	return out
}

func toCareerRefDTOs(in []store.Career) []careerRefDTO {
	out := make([]careerRefDTO, 0, len(in))
	for _, c := range in {
		out = append(out, careerRefDTO{Slug: c.Slug, Title: c.Title, PriceCents: c.PriceCents})
	}
	return out
}

// --- handlers ---

func (h *Handler) listCareers(w http.ResponseWriter, r *http.Request) {
	careers, err := h.svc.ListCareers(r.Context())
	if err != nil {
		h.fail(w, "list careers", err)
		return
	}
	out := make([]careerDTO, 0, len(careers))
	for _, c := range careers {
		out = append(out, toCareerDTO(c))
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) getCareer(w http.ResponseWriter, r *http.Request) {
	career, err := h.svc.GetCareer(r.Context(), chi.URLParam(r, "slug"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "esa carrera no existe o ya no está disponible")
		return
	} else if err != nil {
		h.fail(w, "get career", err)
		return
	}
	httpx.JSON(w, http.StatusOK, careerDetailDTO{
		careerDTO: toCareerDTO(career.CareerSummary),
		Courses:   toCourseDTOs(career.Courses),
	})
}

func (h *Handler) listCourses(w http.ResponseWriter, r *http.Request) {
	courses, err := h.svc.ListCourses(r.Context())
	if err != nil {
		h.fail(w, "list courses", err)
		return
	}
	httpx.JSON(w, http.StatusOK, toCourseDTOs(courses))
}

func (h *Handler) getCourse(w http.ResponseWriter, r *http.Request) {
	course, err := h.svc.GetCourse(r.Context(), chi.URLParam(r, "slug"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "ese curso no existe o ya no está disponible")
		return
	} else if err != nil {
		h.fail(w, "get course", err)
		return
	}
	httpx.JSON(w, http.StatusOK, courseDetailDTO{
		courseDTO: toCourseDTO(course.CourseSummary),
		Modules:   toModuleDTOs(course.Modules),
		Careers:   toCareerRefDTOs(course.Careers),
	})
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("catalog: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}
