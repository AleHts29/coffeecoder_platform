package billing

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/auth"
	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

const maxWebhookBody = 64 << 10

type Handler struct {
	svc    *Service
	q      *store.Queries
	logger *slog.Logger
}

func NewHandler(svc *Service, q *store.Queries, logger *slog.Logger) *Handler {
	return &Handler{svc: svc, q: q, logger: logger}
}

// Mount va detrás de auth.Middleware.
func (h *Handler) Mount(r chi.Router) {
	r.Post("/orders", h.createOrder)
	r.Get("/orders/{id}", h.getOrder)
	r.Get("/me/orders", h.listMyOrders)
}

// MountWebhooks va fuera de la auth de usuario.
func (h *Handler) MountWebhooks(r chi.Router) {
	r.Post("/webhooks/mercadopago", h.webhook)
}

// MountAdmin va detrás de RequireRole("admin").
func (h *Handler) MountAdmin(r chi.Router) {
	r.Get("/orders", h.listOrders)
	r.Post("/orders/{id}/refund", h.refund)
}

// --- DTOs ---

type createOrderRequest struct {
	ProductType string `json:"product_type"`
	ProductID   string `json:"product_id"`
}

type orderDTO struct {
	ID           string    `json:"id"`
	Status       string    `json:"status"`
	ProductType  string    `json:"product_type"`
	ProductID    string    `json:"product_id"`
	ProductTitle string    `json:"product_title"`
	ProductSlug  string    `json:"product_slug"`
	AmountCents  int32     `json:"amount_cents"`
	Currency     string    `json:"currency"`
	Provider     string    `json:"provider"`
	CreatedAt    time.Time `json:"created_at"`
}

type createOrderDTO struct {
	Order       orderDTO `json:"order"`
	CheckoutURL string   `json:"checkout_url"`
}

type adminOrderDTO struct {
	orderDTO
	UserEmail string `json:"user_email"`
	UserName  string `json:"user_name"`
}

func toOrderDTO(o store.Order, p Product) orderDTO {
	return orderDTO{
		ID: o.ID.String(), Status: o.Status, ProductType: o.ProductType, ProductID: o.ProductID.String(),
		ProductTitle: p.Title, ProductSlug: p.Slug, AmountCents: o.AmountCents, Currency: o.Currency,
		Provider: o.Provider, CreatedAt: o.CreatedAt.Time,
	}
}

// --- handlers ---

func (h *Handler) createOrder(w http.ResponseWriter, r *http.Request) {
	id, _ := auth.IdentityFrom(r.Context())
	var req createOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	productID, err := uuid.Parse(req.ProductID)
	if err != nil || (req.ProductType != "course" && req.ProductType != "career") {
		httpx.Error(w, http.StatusBadRequest, "producto inválido")
		return
	}
	user, err := h.q.GetUserByID(r.Context(), id.UserID)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "sesión inválida, iniciá sesión de nuevo")
		return
	}

	res, err := h.svc.CreateOrder(r.Context(), user, req.ProductType, productID)
	switch {
	case errors.Is(err, ErrProductNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrAlreadyOwned):
		httpx.Error(w, http.StatusConflict, err.Error())
	case err != nil:
		h.logger.Error("billing: create order", "err", err)
		httpx.Error(w, http.StatusBadGateway, "no pudimos iniciar el pago, reintentá en un momento")
	default:
		p, _ := h.svc.product(r.Context(), req.ProductType, productID)
		httpx.JSON(w, http.StatusCreated, createOrderDTO{Order: toOrderDTO(res.Order, p), CheckoutURL: res.CheckoutURL})
	}
}

func (h *Handler) getOrder(w http.ResponseWriter, r *http.Request) {
	id, _ := auth.IdentityFrom(r.Context())
	orderID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrOrderNotFound.Error())
		return
	}
	order, p, err := h.svc.GetOrder(r.Context(), id.UserID, orderID, id.Role == "admin")
	if errors.Is(err, ErrOrderNotFound) {
		httpx.Error(w, http.StatusNotFound, err.Error())
		return
	} else if err != nil {
		h.fail(w, "get order", err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	httpx.JSON(w, http.StatusOK, toOrderDTO(order, p))
}

func (h *Handler) listMyOrders(w http.ResponseWriter, r *http.Request) {
	id, _ := auth.IdentityFrom(r.Context())
	rows, err := h.svc.ListUserOrders(r.Context(), id.UserID)
	if err != nil {
		h.fail(w, "list my orders", err)
		return
	}
	out := make([]orderDTO, 0, len(rows))
	for _, o := range rows {
		out = append(out, orderDTO{
			ID: o.ID.String(), Status: o.Status, ProductType: o.ProductType, ProductID: o.ProductID.String(),
			ProductTitle: o.ProductTitle, ProductSlug: o.ProductSlug, AmountCents: o.AmountCents, Currency: o.Currency,
			Provider: o.Provider, CreatedAt: o.CreatedAt.Time,
		})
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) listOrders(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := h.svc.ListOrders(r.Context(), int32(limit), int32(max(offset, 0)))
	if err != nil {
		h.fail(w, "list orders", err)
		return
	}
	out := make([]adminOrderDTO, 0, len(rows))
	for _, o := range rows {
		out = append(out, adminOrderDTO{
			orderDTO: orderDTO{
				ID: o.ID.String(), Status: o.Status, ProductType: o.ProductType, ProductID: o.ProductID.String(),
				ProductTitle: o.ProductTitle, AmountCents: o.AmountCents, Currency: o.Currency,
				Provider: o.Provider, CreatedAt: o.CreatedAt.Time,
			},
			UserEmail: o.UserEmail, UserName: o.UserName,
		})
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *Handler) refund(w http.ResponseWriter, r *http.Request) {
	orderID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, ErrOrderNotFound.Error())
		return
	}
	order, err := h.svc.Refund(r.Context(), orderID)
	switch {
	case errors.Is(err, ErrOrderNotFound):
		httpx.Error(w, http.StatusNotFound, err.Error())
	case errors.Is(err, ErrNotRefundable):
		httpx.Error(w, http.StatusConflict, err.Error())
	case err != nil:
		h.logger.Error("billing: refund", "order", orderID, "err", err)
		httpx.Error(w, http.StatusBadGateway, "no pudimos reembolsar en el proveedor de pagos, reintentá")
	default:
		httpx.JSON(w, http.StatusOK, toOrderDTO(order, Product{}))
	}
}

// webhook: valida la firma con el provider y aplica el pago. Responde
// 200 rápido; un error interno responde 500 para que el provider reintente.
func (h *Handler) webhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxWebhookBody))
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	paymentID, ok, err := h.svc.provider.ParseWebhook(r, body)
	if err != nil {
		h.logger.Warn("billing: webhook rechazado", "err", err)
		httpx.Error(w, http.StatusUnauthorized, "firma inválida")
		return
	}
	if !ok {
		w.WriteHeader(http.StatusOK)
		return
	}
	if err := h.svc.HandlePayment(r.Context(), paymentID); err != nil {
		h.logger.Error("billing: webhook", "payment", paymentID, "err", err)
		httpx.Error(w, http.StatusInternalServerError, "no se pudo procesar, reintentar")
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("billing: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}
