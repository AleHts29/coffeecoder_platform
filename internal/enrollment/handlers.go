package enrollment

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

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

// Mount va detrás de RequireRole("admin") bajo /admin.
func (h *Handler) Mount(r chi.Router) {
	r.Get("/students", h.list)
	r.Get("/students/{id}", h.get)
	r.Post("/students/{id}/enrollments", h.enroll)
	r.Delete("/enrollments/{id}", h.revoke)
}

type studentDTO struct {
	ID                string    `json:"id"`
	Email             string    `json:"email"`
	Name              string    `json:"name"`
	Role              string    `json:"role"`
	CreatedAt         time.Time `json:"created_at"`
	ActiveEnrollments int32     `json:"active_enrollments"`
}

type enrollmentDTO struct {
	ID           string     `json:"id"`
	Scope        string     `json:"scope"`
	ScopeID      string     `json:"scope_id"`
	ProductTitle string     `json:"product_title"`
	ProductSlug  string     `json:"product_slug"`
	OrderID      *string    `json:"order_id"`
	ActivatedAt  time.Time  `json:"activated_at"`
	RevokedAt    *time.Time `json:"revoked_at"`
}

type studentDetailDTO struct {
	studentDTO
	Enrollments []enrollmentDTO `json:"enrollments"`
}

type enrollRequest struct {
	Scope   string `json:"scope"`
	ScopeID string `json:"scope_id"`
}

func enrollmentDTOf(e store.Enrollment, title, slug string) enrollmentDTO {
	d := enrollmentDTO{ID: e.ID.String(), Scope: e.Scope, ScopeID: e.ScopeID.String(), ProductTitle: title, ProductSlug: slug, ActivatedAt: e.ActivatedAt.Time}
	if e.OrderID.Valid {
		s := uuid.UUID(e.OrderID.Bytes).String()
		d.OrderID = &s
	}
	if e.RevokedAt.Valid {
		t := e.RevokedAt.Time
		d.RevokedAt = &t
	}
	return d
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := h.svc.ListStudents(r.Context(), strings.TrimSpace(r.URL.Query().Get("q")), int32(limit), int32(max(offset, 0)))
	if err != nil {
		h.fail(w, "list", err)
		return
	}
	out := make([]studentDTO, 0, len(rows))
	for _, u := range rows {
		out = append(out, studentDTO{ID: u.ID.String(), Email: u.Email, Name: u.Name, Role: u.Role, CreatedAt: u.CreatedAt.Time, ActiveEnrollments: u.ActiveEnrollments})
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrUserNotFound.Error())
		return
	}
	u, rows, err := h.svc.GetStudent(r.Context(), id)
	if errors.Is(err, ErrUserNotFound) {
		httpx.Error(w, http.StatusNotFound, err.Error())
		return
	} else if err != nil {
		h.fail(w, "get", err)
		return
	}
	out := studentDetailDTO{studentDTO: studentDTO{ID: u.ID.String(), Email: u.Email, Name: u.Name, Role: u.Role, CreatedAt: u.CreatedAt.Time}, Enrollments: []enrollmentDTO{}}
	for _, e := range rows {
		if !e.RevokedAt.Valid {
			out.ActiveEnrollments++
		}
		out.Enrollments = append(out.Enrollments, enrollmentDTOf(store.Enrollment{ID: e.ID, UserID: e.UserID, Scope: e.Scope, ScopeID: e.ScopeID, OrderID: e.OrderID, ActivatedAt: e.ActivatedAt, RevokedAt: e.RevokedAt}, e.ProductTitle, e.ProductSlug))
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) enroll(w http.ResponseWriter, r *http.Request) {
	userID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrUserNotFound.Error())
		return
	}
	var req enrollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	scopeID, err := uuid.Parse(req.ScopeID)
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "scope_id inválido")
		return
	}
	e, err := h.svc.Enroll(r.Context(), userID, req.Scope, scopeID)
	switch {
	case errors.Is(err, ErrUserNotFound), errors.Is(err, ErrProductNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrInvalidScope):
		httpx.Error(w, http.StatusBadRequest, err.Error())
	case err != nil:
		h.fail(w, "enroll", err)
	default:
		httpx.JSON(w, http.StatusCreated, enrollmentDTOf(e, "", ""))
	}
}

func (h *Handler) revoke(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrEnrollmentNotFound.Error())
		return
	}
	e, err := h.svc.Revoke(r.Context(), id)
	if errors.Is(err, ErrEnrollmentNotFound) {
		httpx.Error(w, http.StatusNotFound, err.Error())
		return
	} else if err != nil {
		h.fail(w, "revoke", err)
		return
	}
	httpx.JSON(w, http.StatusOK, enrollmentDTOf(e, "", ""))
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("enrollment: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}
