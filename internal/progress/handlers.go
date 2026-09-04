package progress

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/httpx"
)

type Handler struct {
	svc    *Service
	logger *slog.Logger
}

func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, logger: logger}
}

// Mount va detrás de auth.Middleware: todo acá es de un alumno.
func (h *Handler) Mount(r chi.Router) {
	r.Post("/lessons/{id}/heartbeat", h.heartbeat)
	r.Post("/lessons/{id}/complete", h.complete)
	r.Get("/me/dashboard", h.dashboard)
	r.Get("/me/courses/{slug}/progress", h.courseProgress)
}

// --- DTOs ---

type heartbeatRequest struct {
	Seconds int32  `json:"seconds"`
	TZ      string `json:"tz"`
}

type heartbeatDTO struct {
	Seconds   int32 `json:"seconds"`
	Completed bool  `json:"completed"`
}

type lessonProgressDTO struct {
	LessonID  string `json:"lesson_id"`
	Seconds   int32  `json:"seconds"`
	Completed bool   `json:"completed"`
}

type courseProgressDTO struct {
	CourseID         string              `json:"course_id"`
	CompletedLessons int32               `json:"completed_lessons"`
	TotalLessons     int32               `json:"total_lessons"`
	LastLessonID     *string             `json:"last_lesson_id"`
	Lessons          []lessonProgressDTO `json:"lessons"`
}

type continueDTO struct {
	LessonID       string `json:"lesson_id"`
	LessonTitle    string `json:"lesson_title"`
	ModuleTitle    string `json:"module_title"`
	ModulePosition int32  `json:"module_position"`
	Seconds        int32  `json:"seconds"`
	DurationS      int32  `json:"duration_s"`
	CourseSlug     string `json:"course_slug"`
	CourseTitle    string `json:"course_title"`
}

type courseCardDTO struct {
	Slug             string  `json:"slug"`
	Title            string  `json:"title"`
	Subtitle         string  `json:"subtitle"`
	Level            string  `json:"level"`
	Position         int32   `json:"position"`
	CompletedLessons int32   `json:"completed_lessons"`
	TotalLessons     int32   `json:"total_lessons"`
	LastLessonID     *string `json:"last_lesson_id"`
	Status           string  `json:"status"`
}

type careerCardDTO struct {
	Slug             string          `json:"slug"`
	Title            string          `json:"title"`
	Level            string          `json:"level"`
	CompletedLessons int32           `json:"completed_lessons"`
	TotalLessons     int32           `json:"total_lessons"`
	Courses          []courseCardDTO `json:"courses"`
}

type dashboardDTO struct {
	Continue    *continueDTO    `json:"continue"`
	StreakDays  int             `json:"streak_days"`
	WeekSeconds int32           `json:"week_seconds"`
	Careers     []careerCardDTO `json:"careers"`
	Courses     []courseCardDTO `json:"courses"`
}

func toCourseCardDTO(c CourseCard) courseCardDTO {
	dto := courseCardDTO{
		Slug: c.Course.Slug, Title: c.Course.Title, Subtitle: c.Course.Subtitle, Level: c.Course.Level,
		Position: c.Course.Position, CompletedLessons: c.CompletedLessons, TotalLessons: c.TotalLessons,
		Status: string(c.Status),
	}
	if c.LastLessonID != nil {
		s := c.LastLessonID.String()
		dto.LastLessonID = &s
	}
	return dto
}

func toDashboardDTO(d Dashboard) dashboardDTO {
	out := dashboardDTO{StreakDays: d.StreakDays, WeekSeconds: d.WeekSeconds, Careers: []careerCardDTO{}, Courses: []courseCardDTO{}}
	if d.Continue != nil {
		c := d.Continue
		out.Continue = &continueDTO{
			LessonID: c.LessonID.String(), LessonTitle: c.LessonTitle, ModuleTitle: c.ModuleTitle,
			ModulePosition: c.ModulePosition, Seconds: c.Seconds, DurationS: c.DurationS,
			CourseSlug: c.CourseSlug, CourseTitle: c.CourseTitle,
		}
	}
	for _, career := range d.Careers {
		cd := careerCardDTO{
			Slug: career.Career.Slug, Title: career.Career.Title, Level: career.Career.Level,
			CompletedLessons: career.CompletedLessons, TotalLessons: career.TotalLessons, Courses: []courseCardDTO{},
		}
		for _, c := range career.Courses {
			cd.Courses = append(cd.Courses, toCourseCardDTO(c))
		}
		out.Careers = append(out.Careers, cd)
	}
	for _, c := range d.Courses {
		out.Courses = append(out.Courses, toCourseCardDTO(c))
	}
	return out
}

func toCourseProgressDTO(v CourseProgressView) courseProgressDTO {
	dto := courseProgressDTO{
		CourseID: v.Course.ID.String(), CompletedLessons: v.Summary.CompletedLessons,
		TotalLessons: v.Summary.TotalLessons, Lessons: []lessonProgressDTO{},
	}
	if v.Summary.LastLessonID.Valid {
		s := uuid.UUID(v.Summary.LastLessonID.Bytes).String()
		dto.LastLessonID = &s
	}
	for _, l := range v.Lessons {
		dto.Lessons = append(dto.Lessons, lessonProgressDTO{LessonID: l.LessonID.String(), Seconds: l.Seconds, Completed: l.Completed})
	}
	return dto
}

// --- handlers ---

func (h *Handler) heartbeat(w http.ResponseWriter, r *http.Request) {
	id, lessonID, ok := h.identityAndLesson(w, r)
	if !ok {
		return
	}
	var req heartbeatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	res, err := h.svc.Heartbeat(r.Context(), id.UserID, lessonID, req.Seconds, req.TZ)
	if h.handleErr(w, "heartbeat", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, heartbeatDTO{Seconds: res.Seconds, Completed: res.Completed})
}

func (h *Handler) complete(w http.ResponseWriter, r *http.Request) {
	id, lessonID, ok := h.identityAndLesson(w, r)
	if !ok {
		return
	}
	lp, err := h.svc.Complete(r.Context(), id.UserID, lessonID)
	if h.handleErr(w, "complete", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, lessonProgressDTO{LessonID: lp.LessonID.String(), Seconds: lp.Seconds, Completed: lp.Completed})
}

func (h *Handler) courseProgress(w http.ResponseWriter, r *http.Request) {
	id, _ := auth.IdentityFrom(r.Context())
	view, err := h.svc.CourseProgress(r.Context(), id.UserID, chi.URLParam(r, "slug"))
	if h.handleErr(w, "course progress", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, toCourseProgressDTO(view))
}

func (h *Handler) dashboard(w http.ResponseWriter, r *http.Request) {
	id, _ := auth.IdentityFrom(r.Context())
	d, err := h.svc.Dashboard(r.Context(), id.UserID, r.URL.Query().Get("tz"))
	if h.handleErr(w, "dashboard", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, toDashboardDTO(d))
}

func (h *Handler) identityAndLesson(w http.ResponseWriter, r *http.Request) (auth.Identity, uuid.UUID, bool) {
	id, _ := auth.IdentityFrom(r.Context())
	lessonID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrLessonNotFound.Error())
		return id, uuid.Nil, false
	}
	return id, lessonID, true
}

// handleErr responde el error si lo hay y devuelve true.
func (h *Handler) handleErr(w http.ResponseWriter, op string, err error) bool {
	switch {
	case err == nil:
		return false
	case errors.Is(err, ErrLessonNotFound), errors.Is(err, ErrCourseNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrNoAccess):
		httpx.Error(w, http.StatusForbidden, err.Error())
	default:
		h.logger.Error("progress: "+op, "err", err)
		httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
	}
	return true
}
