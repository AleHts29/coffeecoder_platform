package catalog

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

type AdminHandler struct {
	svc    *AdminService
	logger *slog.Logger
}

func NewAdminHandler(svc *AdminService, logger *slog.Logger) *AdminHandler {
	return &AdminHandler{svc: svc, logger: logger}
}

// Mount va detrás de RequireRole("admin") bajo /admin.
func (h *AdminHandler) Mount(r chi.Router) {
	r.Get("/categories", h.listCategories)
	r.Get("/careers", h.listCareers)
	r.Post("/careers", h.createCareer)
	r.Get("/careers/{id}", h.getCareer)
	r.Put("/careers/{id}", h.updateCareer)
	r.Delete("/careers/{id}", h.deleteCareer)
	r.Put("/careers/{id}/courses", h.setCareerCourses)

	r.Get("/courses", h.listCourses)
	r.Post("/courses", h.createCourse)
	r.Get("/courses/{id}", h.getCourse)
	r.Put("/courses/{id}", h.updateCourse)
	r.Delete("/courses/{id}", h.deleteCourse)
	r.Post("/courses/{id}/modules", h.createModule)
	r.Put("/courses/{id}/modules/order", h.reorderModules)

	r.Put("/modules/{id}", h.updateModule)
	r.Delete("/modules/{id}", h.deleteModule)
	r.Post("/modules/{id}/lessons", h.createLesson)
	r.Put("/modules/{id}/lessons/order", h.reorderLessons)

	r.Put("/lessons/{id}", h.updateLesson)
	r.Delete("/lessons/{id}", h.deleteLesson)
}

// --- DTOs ---

type productInputDTO struct {
	Category    string `json:"category"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	Subtitle    string `json:"subtitle"`
	Description string `json:"description"`
	Level       string `json:"level"`
	PriceCents  int32  `json:"price_cents"`
	Status      string `json:"status"`
}

func (d productInputDTO) input() ProductInput {
	return ProductInput{Slug: d.Slug, Title: d.Title, Subtitle: d.Subtitle, Description: d.Description, Level: d.Level, PriceCents: d.PriceCents, Status: d.Status, CategorySlug: d.Category}
}

type adminProductDTO struct {
	ID          string    `json:"id"`
	Slug        string    `json:"slug"`
	Title       string    `json:"title"`
	Subtitle    string    `json:"subtitle"`
	Description string    `json:"description"`
	Level       string    `json:"level"`
	PriceCents  int32     `json:"price_cents"`
	Status      string    `json:"status"`
	Position    int32     `json:"position"`
	Category    string    `json:"category"`
	UpdatedAt   time.Time `json:"updated_at"`
	CourseCount int32     `json:"course_count,omitempty"`
	LessonCount int32     `json:"lesson_count,omitempty"`
}

func careerDTOf(c store.Career, courseCount int32, cats map[uuid.UUID]string) adminProductDTO {
	return adminProductDTO{ID: c.ID.String(), Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, Description: c.Description, Level: c.Level, PriceCents: c.PriceCents, Status: c.Status, Position: c.Position, Category: categorySlug(c.CategoryID, cats), UpdatedAt: c.UpdatedAt.Time, CourseCount: courseCount}
}

func courseDTOf(c store.Course, lessonCount int32, cats map[uuid.UUID]string) adminProductDTO {
	return adminProductDTO{ID: c.ID.String(), Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, Description: c.Description, Level: c.Level, PriceCents: c.PriceCents, Status: c.Status, Position: c.Position, Category: categorySlug(c.CategoryID, cats), UpdatedAt: c.UpdatedAt.Time, LessonCount: lessonCount}
}

func categorySlug(id pgtype.UUID, cats map[uuid.UUID]string) string {
	if !id.Valid {
		return ""
	}
	return cats[uuid.UUID(id.Bytes)]
}

// categoryMap indexa slug por id para los DTOs del admin.
func (h *AdminHandler) categoryMap(r *http.Request) map[uuid.UUID]string {
	rows, err := h.svc.Categories(r.Context())
	if err != nil {
		h.logger.Error("catalog admin: categorías", "err", err)
		return map[uuid.UUID]string{}
	}
	m := make(map[uuid.UUID]string, len(rows))
	for _, c := range rows {
		m[c.ID] = c.Slug
	}
	return m
}

type adminLessonDTO struct {
	ID           string `json:"id"`
	Title        string `json:"title"`
	Description  string `json:"description"`
	DurationS    int32  `json:"duration_s"`
	IsFreeSample bool   `json:"is_free_sample"`
	Position     int32  `json:"position"`
	VideoStatus  string `json:"video_status"`
	Kind         string `json:"kind"`
	BodyMD       string `json:"body_md"`
}

type adminModuleDTO struct {
	ID       string           `json:"id"`
	Title    string           `json:"title"`
	Position int32            `json:"position"`
	Lessons  []adminLessonDTO `json:"lessons"`
}

type adminCourseDetailDTO struct {
	adminProductDTO
	Modules []adminModuleDTO `json:"modules"`
}

type adminCareerDetailDTO struct {
	adminProductDTO
	Courses []adminProductDTO `json:"courses"`
}

type lessonInputDTO struct {
	Title        string `json:"title"`
	Description  string `json:"description"`
	DurationS    int32  `json:"duration_s"`
	IsFreeSample bool   `json:"is_free_sample"`
	Kind         string `json:"kind"`
	BodyMD       string `json:"body_md"`
}

type titleDTO struct {
	Title string `json:"title"`
}

type orderDTO struct {
	IDs []string `json:"ids"`
}

func lessonDTOf(l store.Lesson) adminLessonDTO {
	return adminLessonDTO{ID: l.ID.String(), Title: l.Title, Description: l.Description, DurationS: l.DurationS, IsFreeSample: l.IsFreeSample, Position: l.Position, VideoStatus: l.VideoStatus, Kind: l.Kind, BodyMD: l.BodyMd}
}

// --- handlers: carreras ---

func (h *AdminHandler) listCategories(w http.ResponseWriter, r *http.Request) {
	cats, err := h.svc.Categories(r.Context())
	if h.handle(w, "list categories", err) {
		return
	}
	out := make([]map[string]string, 0, len(cats))
	for _, c := range cats {
		out = append(out, map[string]string{"slug": c.Slug, "name": c.Name})
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *AdminHandler) listCareers(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	rows, err := h.svc.ListCareers(r.Context())
	if h.handle(w, "list careers", err) {
		return
	}
	out := make([]adminProductDTO, 0, len(rows))
	for _, c := range rows {
		out = append(out, careerDTOf(store.Career{ID: c.ID, Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, Description: c.Description, Level: c.Level, PriceCents: c.PriceCents, Status: c.Status, Position: c.Position, UpdatedAt: c.UpdatedAt}, c.CourseCount, cats))
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *AdminHandler) createCareer(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	var in productInputDTO
	if !decode(w, r, &in) {
		return
	}
	c, err := h.svc.CreateCareer(r.Context(), in.input())
	if h.handle(w, "create career", err) {
		return
	}
	httpx.JSON(w, http.StatusCreated, careerDTOf(c, 0, cats))
}

func (h *AdminHandler) getCareer(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	id, ok := param(w, r)
	if !ok {
		return
	}
	c, courses, err := h.svc.GetCareer(r.Context(), id)
	if h.handle(w, "get career", err) {
		return
	}
	out := adminCareerDetailDTO{adminProductDTO: careerDTOf(c, int32(len(courses)), cats), Courses: []adminProductDTO{}}
	for _, r := range courses {
		out.Courses = append(out.Courses, courseDTOf(store.Course{ID: r.ID, Slug: r.Slug, Title: r.Title, Subtitle: r.Subtitle, Level: r.Level, PriceCents: r.PriceCents, Status: r.Status, Position: r.CareerPosition, UpdatedAt: r.UpdatedAt}, 0, cats))
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *AdminHandler) updateCareer(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in productInputDTO
	if !decode(w, r, &in) {
		return
	}
	c, err := h.svc.UpdateCareer(r.Context(), id, in.input())
	if h.handle(w, "update career", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, careerDTOf(c, 0, cats))
}

func (h *AdminHandler) deleteCareer(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	if h.handle(w, "delete career", h.svc.DeleteCareer(r.Context(), id)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminHandler) setCareerCourses(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	ids, ok := decodeIDs(w, r)
	if !ok {
		return
	}
	if h.handle(w, "set career courses", h.svc.SetCareerCourses(r.Context(), id, ids)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- handlers: cursos ---

func (h *AdminHandler) listCourses(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	rows, err := h.svc.ListCourses(r.Context())
	if h.handle(w, "list courses", err) {
		return
	}
	out := make([]adminProductDTO, 0, len(rows))
	for _, c := range rows {
		out = append(out, courseDTOf(store.Course{ID: c.ID, Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, Description: c.Description, Level: c.Level, PriceCents: c.PriceCents, Status: c.Status, Position: c.Position, UpdatedAt: c.UpdatedAt}, c.LessonCount, cats))
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *AdminHandler) createCourse(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	var in productInputDTO
	if !decode(w, r, &in) {
		return
	}
	c, err := h.svc.CreateCourse(r.Context(), in.input())
	if h.handle(w, "create course", err) {
		return
	}
	httpx.JSON(w, http.StatusCreated, courseDTOf(c, 0, cats))
}

func (h *AdminHandler) getCourse(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	id, ok := param(w, r)
	if !ok {
		return
	}
	c, modules, err := h.svc.GetCourse(r.Context(), id)
	if h.handle(w, "get course", err) {
		return
	}
	out := adminCourseDetailDTO{adminProductDTO: courseDTOf(c, 0, cats), Modules: []adminModuleDTO{}}
	for _, m := range modules {
		md := adminModuleDTO{ID: m.ID.String(), Title: m.Title, Position: m.Position, Lessons: []adminLessonDTO{}}
		for _, l := range m.Lessons {
			md.Lessons = append(md.Lessons, adminLessonDTO{ID: l.ID.String(), Title: l.Title, Description: l.Description, DurationS: l.DurationS, IsFreeSample: l.IsFreeSample, Position: l.Position, VideoStatus: l.VideoStatus, Kind: l.Kind, BodyMD: l.BodyMD})
			out.LessonCount++
		}
		out.Modules = append(out.Modules, md)
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *AdminHandler) updateCourse(w http.ResponseWriter, r *http.Request) {
	cats := h.categoryMap(r)
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in productInputDTO
	if !decode(w, r, &in) {
		return
	}
	c, err := h.svc.UpdateCourse(r.Context(), id, in.input())
	if h.handle(w, "update course", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, courseDTOf(c, 0, cats))
}

func (h *AdminHandler) deleteCourse(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	if h.handle(w, "delete course", h.svc.DeleteCourse(r.Context(), id)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminHandler) createModule(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in titleDTO
	if !decode(w, r, &in) {
		return
	}
	m, err := h.svc.CreateModule(r.Context(), id, in.Title)
	if h.handle(w, "create module", err) {
		return
	}
	httpx.JSON(w, http.StatusCreated, adminModuleDTO{ID: m.ID.String(), Title: m.Title, Position: m.Position, Lessons: []adminLessonDTO{}})
}

func (h *AdminHandler) reorderModules(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	ids, ok := decodeIDs(w, r)
	if !ok {
		return
	}
	if h.handle(w, "reorder modules", h.svc.ReorderModules(r.Context(), id, ids)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- handlers: módulos y lecciones ---

func (h *AdminHandler) updateModule(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in titleDTO
	if !decode(w, r, &in) {
		return
	}
	m, err := h.svc.UpdateModule(r.Context(), id, in.Title)
	if h.handle(w, "update module", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, adminModuleDTO{ID: m.ID.String(), Title: m.Title, Position: m.Position, Lessons: []adminLessonDTO{}})
}

func (h *AdminHandler) deleteModule(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	if h.handle(w, "delete module", h.svc.DeleteModule(r.Context(), id)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminHandler) createLesson(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in lessonInputDTO
	if !decode(w, r, &in) {
		return
	}
	l, err := h.svc.CreateLesson(r.Context(), id, LessonInput(in))
	if h.handle(w, "create lesson", err) {
		return
	}
	httpx.JSON(w, http.StatusCreated, lessonDTOf(l))
}

func (h *AdminHandler) reorderLessons(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	ids, ok := decodeIDs(w, r)
	if !ok {
		return
	}
	if h.handle(w, "reorder lessons", h.svc.ReorderLessons(r.Context(), id, ids)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminHandler) updateLesson(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	var in lessonInputDTO
	if !decode(w, r, &in) {
		return
	}
	l, err := h.svc.UpdateLesson(r.Context(), id, LessonInput(in))
	if h.handle(w, "update lesson", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, lessonDTOf(l))
}

func (h *AdminHandler) deleteLesson(w http.ResponseWriter, r *http.Request) {
	id, ok := param(w, r)
	if !ok {
		return
	}
	if h.handle(w, "delete lesson", h.svc.DeleteLesson(r.Context(), id)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- helpers ---

func param(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrNotFound.Error())
		return uuid.Nil, false
	}
	return id, true
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return false
	}
	return true
}

func decodeIDs(w http.ResponseWriter, r *http.Request) ([]uuid.UUID, bool) {
	var in orderDTO
	if !decode(w, r, &in) {
		return nil, false
	}
	ids := make([]uuid.UUID, 0, len(in.IDs))
	for _, s := range in.IDs {
		id, err := uuid.Parse(s)
		if err != nil {
			httpx.Error(w, http.StatusBadRequest, "id inválido en la lista")
			return nil, false
		}
		ids = append(ids, id)
	}
	return ids, true
}

func (h *AdminHandler) handle(w http.ResponseWriter, op string, err error) bool {
	switch {
	case err == nil:
		return false
	case errors.Is(err, ErrNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrInvalid), errors.Is(err, ErrBadReorder):
		httpx.Error(w, http.StatusBadRequest, err.Error())
	case errors.Is(err, ErrSlugTaken), errors.Is(err, ErrInUse):
		httpx.Error(w, http.StatusConflict, err.Error())
	default:
		h.logger.Error("catalog admin: "+op, "err", err)
		httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
	}
	return true
}
