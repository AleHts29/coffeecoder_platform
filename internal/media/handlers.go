package media

import (
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

const maxWebhookBody = 64 << 10

type Handler struct {
	svc           *Service
	images        ImageStore
	webhookSecret string
	logger        *slog.Logger
}

func NewHandler(svc *Service, images ImageStore, webhookSecret string, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, images: images, webhookSecret: webhookSecret, logger: logger}
}

// MountPlayback va bajo auth opcional: los visitantes pueden ver las
// muestras gratis, el resto requiere identidad con enrollment.
func (h *Handler) MountPlayback(r chi.Router) {
	r.Get("/lessons/{id}/playback", h.playback)
}

// MountWebhooks va fuera de la auth de usuario: firma propia.
func (h *Handler) MountWebhooks(r chi.Router) {
	r.Post("/webhooks/bunny", h.webhook)
}

// MountAdmin va detrás de RequireRole("admin").
func (h *Handler) MountAdmin(r chi.Router) {
	r.Post("/lessons/{id}/video", h.startUpload)
	r.Post("/lessons/{id}/video/sync", h.syncVideo)
	r.Post("/images", h.uploadImage)
}

// --- DTOs ---

type playbackDTO struct {
	URL       string    `json:"url"`
	ExpiresAt time.Time `json:"expires_at"`
}

type uploadDTO struct {
	Upload UploadTicket `json:"upload"`
}

type lessonVideoDTO struct {
	ID          string `json:"id"`
	VideoStatus string `json:"video_status"`
	DurationS   int32  `json:"duration_s"`
}

func toLessonVideoDTO(l store.Lesson) lessonVideoDTO {
	return lessonVideoDTO{ID: l.ID.String(), VideoStatus: l.VideoStatus, DurationS: l.DurationS}
}

// --- handlers ---

func (h *Handler) playback(w http.ResponseWriter, r *http.Request) {
	lessonID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrLessonNotFound.Error())
		return
	}
	userID := uuid.Nil
	if id, ok := auth.IdentityFrom(r.Context()); ok {
		userID = id.UserID
	}

	pb, err := h.svc.Playback(r.Context(), userID, lessonID)
	switch {
	case errors.Is(err, ErrLessonNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrNoAccess) && userID == uuid.Nil:
		httpx.Error(w, http.StatusUnauthorized, "iniciá sesión para ver esta lección")
	case errors.Is(err, ErrNoAccess):
		httpx.Error(w, http.StatusForbidden, err.Error())
	case errors.Is(err, ErrNotReady):
		httpx.Error(w, http.StatusConflict, err.Error())
	case err != nil:
		h.fail(w, "playback", err)
	default:
		w.Header().Set("Cache-Control", "no-store")
		httpx.JSON(w, http.StatusOK, playbackDTO{URL: pb.URL, ExpiresAt: pb.ExpiresAt})
	}
}

func (h *Handler) webhook(w http.ResponseWriter, r *http.Request) {
	if h.webhookSecret == "" {
		h.logger.Error("media: webhook recibido sin BUNNY_WEBHOOK_SECRET configurado")
		httpx.Error(w, http.StatusServiceUnavailable, "webhook no configurado")
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxWebhookBody))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if !VerifyWebhookSignature(h.webhookSecret, body, r.Header.Get("X-BunnyStream-Signature")) {
		httpx.Error(w, http.StatusUnauthorized, "firma inválida")
		return
	}
	ev, err := ParseWebhook(body)
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "evento inválido")
		return
	}
	if err := h.svc.ApplyWebhook(r.Context(), ev); err != nil {
		h.fail(w, "webhook", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) startUpload(w http.ResponseWriter, r *http.Request) {
	lessonID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrLessonNotFound.Error())
		return
	}
	ticket, err := h.svc.StartUpload(r.Context(), lessonID)
	if errors.Is(err, ErrLessonNotFound) {
		httpx.Error(w, http.StatusNotFound, err.Error())
		return
	} else if err != nil {
		h.fail(w, "start upload", err)
		return
	}
	httpx.JSON(w, http.StatusCreated, uploadDTO{Upload: ticket})
}

func (h *Handler) syncVideo(w http.ResponseWriter, r *http.Request) {
	lessonID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrLessonNotFound.Error())
		return
	}
	lesson, err := h.svc.SyncVideo(r.Context(), lessonID)
	switch {
	case errors.Is(err, ErrLessonNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrNotReady):
		httpx.Error(w, http.StatusConflict, "la lección no tiene un video asociado todavía")
	case err != nil:
		h.fail(w, "sync video", err)
	default:
		httpx.JSON(w, http.StatusOK, toLessonVideoDTO(lesson))
	}
}

// uploadImage recibe el archivo crudo en el body (Content-Type de la
// imagen) y devuelve la URL pública para pegar en el Markdown.
func (h *Handler) uploadImage(w http.ResponseWriter, r *http.Request) {
	contentType := r.Header.Get("Content-Type")
	data, err := io.ReadAll(io.LimitReader(r.Body, MaxImageBytes+1))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "no pudimos leer el archivo")
		return
	}
	if len(data) == 0 {
		httpx.Error(w, http.StatusBadRequest, "el archivo está vacío")
		return
	}
	if len(data) > MaxImageBytes {
		httpx.Error(w, http.StatusRequestEntityTooLarge, "la imagen supera los 5 MB")
		return
	}
	url, err := h.images.Put(r.Context(), data, contentType)
	if err != nil {
		if strings.Contains(err.Error(), "no soportado") {
			httpx.Error(w, http.StatusBadRequest, "formato no soportado: usá JPG, PNG, WebP, GIF, AVIF o SVG")
			return
		}
		h.fail(w, "upload image", err)
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]string{"url": url})
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("media: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}
