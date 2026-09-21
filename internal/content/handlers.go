package content

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

// frameCSP aísla la demo: origen opaco (sin cookies, storage ni acceso a
// window.parent), sin red, y solo embebible desde la propia plataforma.
// No es opcional: es lo que hace segura la demo.
const frameCSP = "sandbox allow-scripts; default-src 'none'; " +
	"script-src 'unsafe-inline'; style-src 'unsafe-inline' https://fonts.googleapis.com; " +
	"font-src https://fonts.gstatic.com; img-src data: blob:; connect-src 'none'; frame-ancestors 'self'"

type Handler struct {
	svc    *Service
	logger *slog.Logger
}

func NewHandler(svc *Service, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, logger: logger}
}

// MountContent va bajo auth opcional, igual que el playback de video.
func (h *Handler) MountContent(r chi.Router) {
	r.Get("/lessons/{id}/content", h.content)
}

// MountFrame va fuera de la auth de usuario: la firma es la credencial.
func (h *Handler) MountFrame(r chi.Router) {
	r.Get("/demos/{id}/frame", h.frame)
}

// MountAdmin va detrás de RequireRole("admin").
func (h *Handler) MountAdmin(r chi.Router) {
	r.Get("/courses/{id}/demos", h.listDemos)
	r.Post("/courses/{id}/demos", h.createDemo)
	r.Get("/demos/{id}", h.getDemo)
	r.Put("/demos/{id}", h.updateDemo)
	r.Delete("/demos/{id}", h.deleteDemo)
}

// --- DTOs ---

type demoRefDTO struct {
	Slug     string `json:"slug"`
	Title    string `json:"title"`
	HeightPx int32  `json:"height_px"`
	FrameURL string `json:"frame_url"`
}

type contentDTO struct {
	Kind         string       `json:"kind"`
	BodyMD       string       `json:"body_md"`
	ReadingTimeS int32        `json:"reading_time_s"`
	Demos        []demoRefDTO `json:"demos"`
}

type lessonRefDTO struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	ModuleTitle string `json:"module_title"`
}

type demoSummaryDTO struct {
	ID        string `json:"id"`
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	HeightPx  int32  `json:"height_px"`
	SizeBytes int32  `json:"size_bytes"`
	// FrameURL firmada: el admin previsualiza cualquier demo del curso
	// mientras escribe, incluso antes de guardar el texto que la usa.
	FrameURL string         `json:"frame_url"`
	UsedBy   []lessonRefDTO `json:"used_by"`
}

// demoDTO incluye el HTML: solo se devuelve al admin que lo está editando.
type demoDTO struct {
	ID       string `json:"id"`
	Slug     string `json:"slug"`
	Title    string `json:"title"`
	HTML     string `json:"html"`
	HeightPx int32  `json:"height_px"`
	FrameURL string `json:"frame_url"`
}

type demoInputDTO struct {
	Slug     string `json:"slug"`
	Title    string `json:"title"`
	HTML     string `json:"html"`
	HeightPx int32  `json:"height_px"`
}

func (h *Handler) demoDTOf(d store.Demo) demoDTO {
	return demoDTO{
		ID: d.ID.String(), Slug: d.Slug, Title: d.Title, HTML: d.Html,
		HeightPx: d.HeightPx, FrameURL: h.svc.SignFrameURL(d.ID),
	}
}

// --- handlers ---

func (h *Handler) content(w http.ResponseWriter, r *http.Request) {
	lessonID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrLessonNotFound.Error())
		return
	}
	userID := uuid.Nil
	if id, ok := auth.IdentityFrom(r.Context()); ok {
		userID = id.UserID
	}

	c, err := h.svc.Get(r.Context(), userID, lessonID)
	switch {
	case errors.Is(err, ErrLessonNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrNoAccess) && userID == uuid.Nil:
		httpx.Error(w, http.StatusUnauthorized, "iniciá sesión para ver esta lección")
	case errors.Is(err, ErrNoAccess):
		httpx.Error(w, http.StatusForbidden, err.Error())
	case err != nil:
		h.fail(w, "content", err)
	default:
		out := contentDTO{Kind: c.Kind, BodyMD: c.BodyMD, ReadingTimeS: c.ReadingTimeS, Demos: []demoRefDTO{}}
		for _, d := range c.Demos {
			out.Demos = append(out.Demos, demoRefDTO{Slug: d.Slug, Title: d.Title, HeightPx: d.HeightPx, FrameURL: d.FrameURL})
		}
		w.Header().Set("Cache-Control", "no-store")
		httpx.JSON(w, http.StatusOK, out)
	}
}

func (h *Handler) frame(w http.ResponseWriter, r *http.Request) {
	demoID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrDemoNotFound.Error())
		return
	}
	html, err := h.svc.Frame(r.Context(), demoID, r.URL.Query().Get("exp"), r.URL.Query().Get("sig"))
	switch {
	case errors.Is(err, ErrNoAccess):
		// Firma inválida o vencida: no revelamos si la demo existe.
		httpx.Error(w, http.StatusForbidden, "este enlace venció, recargá la lección")
	case errors.Is(err, ErrDemoNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case err != nil:
		h.fail(w, "frame", err)
	default:
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Content-Security-Policy", frameCSP)
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "private, max-age=300")
		_, _ = w.Write([]byte(html))
	}
}

func (h *Handler) listDemos(w http.ResponseWriter, r *http.Request) {
	courseID, ok := h.param(w, r)
	if !ok {
		return
	}
	rows, err := h.svc.ListDemos(r.Context(), courseID)
	if h.handle(w, "list demos", err) {
		return
	}
	out := make([]demoSummaryDTO, 0, len(rows))
	for _, d := range rows {
		item := demoSummaryDTO{ID: d.ID.String(), Slug: d.Slug, Title: d.Title, HeightPx: d.HeightPx, SizeBytes: d.SizeBytes, FrameURL: h.svc.SignFrameURL(d.ID), UsedBy: []lessonRefDTO{}}
		for _, l := range d.UsedBy {
			item.UsedBy = append(item.UsedBy, lessonRefDTO{ID: l.ID.String(), Title: l.Title, ModuleTitle: l.ModuleTitle})
		}
		out = append(out, item)
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) createDemo(w http.ResponseWriter, r *http.Request) {
	courseID, ok := h.param(w, r)
	if !ok {
		return
	}
	var in demoInputDTO
	if !decode(w, r, &in) {
		return
	}
	d, err := h.svc.CreateDemo(r.Context(), courseID, DemoInput(in))
	if h.handle(w, "create demo", err) {
		return
	}
	httpx.JSON(w, http.StatusCreated, h.demoDTOf(d))
}

func (h *Handler) getDemo(w http.ResponseWriter, r *http.Request) {
	id, ok := h.param(w, r)
	if !ok {
		return
	}
	d, err := h.svc.GetDemo(r.Context(), id)
	if h.handle(w, "get demo", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, h.demoDTOf(d))
}

func (h *Handler) updateDemo(w http.ResponseWriter, r *http.Request) {
	id, ok := h.param(w, r)
	if !ok {
		return
	}
	var in demoInputDTO
	if !decode(w, r, &in) {
		return
	}
	d, err := h.svc.UpdateDemo(r.Context(), id, DemoInput(in))
	if h.handle(w, "update demo", err) {
		return
	}
	httpx.JSON(w, http.StatusOK, h.demoDTOf(d))
}

func (h *Handler) deleteDemo(w http.ResponseWriter, r *http.Request) {
	id, ok := h.param(w, r)
	if !ok {
		return
	}
	if h.handle(w, "delete demo", h.svc.DeleteDemo(r.Context(), id)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- helpers ---

func (h *Handler) param(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrDemoNotFound.Error())
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

func (h *Handler) handle(w http.ResponseWriter, op string, err error) bool {
	switch {
	case err == nil:
		return false
	case errors.Is(err, ErrDemoNotFound), errors.Is(err, ErrLessonNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrInvalidDemo):
		httpx.Error(w, http.StatusBadRequest, err.Error())
	case errors.Is(err, ErrSlugTaken):
		httpx.Error(w, http.StatusConflict, err.Error())
	default:
		h.fail(w, op, err)
	}
	return true
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("content: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}
