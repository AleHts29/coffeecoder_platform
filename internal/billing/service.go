package billing

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/mail"
	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrProductNotFound = errors.New("ese producto no existe o no está a la venta")
	ErrAlreadyOwned    = errors.New("ya tenés acceso a este producto")
	ErrOrderNotFound   = errors.New("esa orden no existe")
	ErrNotRefundable   = errors.New("solo se puede reembolsar una orden aprobada")
)

type Service struct {
	q        *store.Queries
	provider PaymentProvider
	mailer   mail.Mailer
	cfg      config.BillingConfig
	frontend string
	logger   *slog.Logger
}

func NewService(q *store.Queries, provider PaymentProvider, mailer mail.Mailer, cfg config.BillingConfig, frontendURL string, logger *slog.Logger) *Service {
	return &Service{q: q, provider: provider, mailer: mailer, cfg: cfg, frontend: frontendURL, logger: logger}
}

// Product es lo que se vende: curso o carrera publicados.
type Product struct {
	Type       string // course | career
	ID         uuid.UUID
	Slug       string
	Title      string
	Subtitle   string
	PriceCents int32 // USD, catálogo
}

func (s *Service) product(ctx context.Context, typ string, id uuid.UUID) (Product, error) {
	switch typ {
	case "course":
		c, err := s.q.GetCourse(ctx, id)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && c.Status != "published") {
			return Product{}, ErrProductNotFound
		} else if err != nil {
			return Product{}, err
		}
		return Product{Type: typ, ID: c.ID, Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, PriceCents: c.PriceCents}, nil
	case "career":
		c, err := s.q.GetCareer(ctx, id)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && c.Status != "published") {
			return Product{}, ErrProductNotFound
		} else if err != nil {
			return Product{}, err
		}
		return Product{Type: typ, ID: c.ID, Slug: c.Slug, Title: c.Title, Subtitle: c.Subtitle, PriceCents: c.PriceCents}, nil
	}
	return Product{}, ErrProductNotFound
}

func (s *Service) owns(ctx context.Context, userID uuid.UUID, p Product) (bool, error) {
	if p.Type == "career" {
		return s.q.HasCareerAccess(ctx, store.HasCareerAccessParams{UserID: userID, ScopeID: p.ID})
	}
	return s.q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: userID, ScopeID: p.ID})
}

// LocalAmount convierte el precio de catálogo (USD) a la moneda de cobro.
// Redondea a la unidad: nadie cobra ARS 66.150,37.
func (s *Service) LocalAmount(usdCents int32) (int32, string) {
	if s.cfg.USDRate <= 0 {
		return usdCents, "USD"
	}
	units := math.Round(float64(usdCents) / 100 * s.cfg.USDRate)
	return int32(units * 100), s.cfg.Currency
}

// CreateOrder crea la orden pending y el checkout del provider.
type OrderResult struct {
	Order       store.Order
	CheckoutURL string
}

func (s *Service) CreateOrder(ctx context.Context, user store.User, productType string, productID uuid.UUID) (OrderResult, error) {
	p, err := s.product(ctx, productType, productID)
	if err != nil {
		return OrderResult{}, err
	}
	if owned, err := s.owns(ctx, user.ID, p); err != nil {
		return OrderResult{}, err
	} else if owned {
		return OrderResult{}, ErrAlreadyOwned
	}

	amount, currency := s.LocalAmount(p.PriceCents)
	// Una pending reciente del mismo producto se reutiliza (nuevo checkout,
	// misma orden): sin órdenes huérfanas por cada intento.
	order, err := s.q.GetPendingOrder(ctx, store.GetPendingOrderParams{UserID: user.ID, ProductType: p.Type, ProductID: p.ID})
	if errors.Is(err, pgx.ErrNoRows) {
		order, err = s.q.CreateOrder(ctx, store.CreateOrderParams{
			UserID: user.ID, ProductType: p.Type, ProductID: p.ID,
			AmountCents: amount, Currency: currency, Provider: s.provider.Name(),
		})
	}
	if err != nil {
		return OrderResult{}, err
	}
	amount, currency = order.AmountCents, order.Currency

	checkout, err := s.provider.CreateCheckout(ctx, CheckoutRequest{
		OrderID: order.ID, Title: p.Title, Description: p.Subtitle,
		AmountCents: amount, Currency: currency, PayerEmail: user.Email,
	})
	if err != nil {
		// La orden queda pending sin pago: el alumno puede volver a intentar
		// y esta se limpia con el job de órdenes vencidas (post-MVP).
		return OrderResult{}, err
	}
	return OrderResult{Order: order, CheckoutURL: checkout.URL}, nil
}

// HandlePayment aplica el estado de un pago informado por el provider.
// Idempotente: ApproveOrder solo transiciona pending → approved; si no
// afecta filas, ya se procesó y cortamos sin tocar enrollments ni mails.
func (s *Service) HandlePayment(ctx context.Context, paymentID string) error {
	payment, err := s.provider.GetPayment(ctx, paymentID)
	if err != nil {
		return err
	}
	if payment.OrderID == uuid.Nil {
		s.logger.Info("billing: pago sin external_reference, se ignora", "payment", paymentID)
		return nil
	}

	switch payment.Status {
	case PaymentApproved:
		order, err := s.q.ApproveOrder(ctx, store.ApproveOrderParams{ID: payment.OrderID, Provider: s.provider.Name(), ProviderPaymentID: &payment.ID})
		if errors.Is(err, pgx.ErrNoRows) {
			return nil // ya aprobada (reintento del webhook) o no existe
		} else if err != nil {
			return err
		}
		return s.grant(ctx, order)
	case PaymentRejected:
		_, err := s.q.RejectOrder(ctx, store.RejectOrderParams{ID: payment.OrderID, Provider: s.provider.Name(), ProviderPaymentID: &payment.ID})
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		return err
	default:
		return nil // pending / unknown: esperamos el próximo evento
	}
}

// grant crea el enrollment (scope polimórfico: una carrera NO se explota
// en N cursos) y manda el mail de confirmación.
func (s *Service) grant(ctx context.Context, order store.Order) error {
	if _, err := s.q.CreateEnrollment(ctx, store.CreateEnrollmentParams{
		UserID: order.UserID, Scope: order.ProductType, ScopeID: order.ProductID,
		OrderID: pgtype.UUID{Bytes: order.ID, Valid: true},
	}); err != nil {
		return fmt.Errorf("billing: creando enrollment: %w", err)
	}

	user, err := s.q.GetUserByID(ctx, order.UserID)
	if err != nil {
		return err
	}
	p, err := s.product(ctx, order.ProductType, order.ProductID)
	if err != nil {
		s.logger.Warn("billing: producto no disponible para el mail", "order", order.ID, "err", err)
		return nil
	}
	kind, path := "curso", "/cursos/"
	if p.Type == "career" {
		kind, path = "carrera", "/carreras/"
	}
	subject, html, text := mail.PurchaseConfirmed(user.Name, p.Title, kind, s.frontend+path+p.Slug)
	mail.SendAsync(s.mailer, s.logger, mail.Message{
		To: user.Email, Subject: subject, HTML: html, Text: text, IdempotencyKey: "purchase-" + order.ID.String(),
	})
	return nil
}

// Refund: reembolso manual desde admin. Reembolsa en el provider,
// marca la orden y revoca el enrollment.
func (s *Service) Refund(ctx context.Context, orderID uuid.UUID) (store.Order, error) {
	order, err := s.q.GetOrder(ctx, orderID)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.Order{}, ErrOrderNotFound
	} else if err != nil {
		return store.Order{}, err
	}
	if order.Status != "approved" {
		return store.Order{}, ErrNotRefundable
	}
	if order.ProviderPaymentID != nil && order.Provider == s.provider.Name() {
		if err := s.provider.Refund(ctx, *order.ProviderPaymentID); err != nil {
			return store.Order{}, fmt.Errorf("billing: reembolso en el provider: %w", err)
		}
	}
	order, err = s.q.RefundOrder(ctx, orderID)
	if err != nil {
		return store.Order{}, err
	}
	if e, err := s.q.GetEnrollmentByOrder(ctx, pgtype.UUID{Bytes: orderID, Valid: true}); err == nil {
		if _, err := s.q.RevokeEnrollment(ctx, e.ID); err != nil {
			return store.Order{}, err
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return store.Order{}, err
	}
	return order, nil
}

// GetOrder devuelve la orden si pertenece al usuario (o admin=true).
func (s *Service) GetOrder(ctx context.Context, userID uuid.UUID, orderID uuid.UUID, admin bool) (store.Order, Product, error) {
	order, err := s.q.GetOrder(ctx, orderID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && !admin && order.UserID != userID) {
		return store.Order{}, Product{}, ErrOrderNotFound
	} else if err != nil {
		return store.Order{}, Product{}, err
	}
	p, err := s.product(ctx, order.ProductType, order.ProductID)
	if err != nil && !errors.Is(err, ErrProductNotFound) {
		return store.Order{}, Product{}, err
	}
	return order, p, nil
}

func (s *Service) ListUserOrders(ctx context.Context, userID uuid.UUID) ([]store.ListUserOrdersWithProductRow, error) {
	return s.q.ListUserOrdersWithProduct(ctx, userID)
}

func (s *Service) ListOrders(ctx context.Context, limit, offset int32) ([]store.ListOrdersRow, error) {
	return s.q.ListOrders(ctx, store.ListOrdersParams{Limit: limit, Offset: offset})
}
