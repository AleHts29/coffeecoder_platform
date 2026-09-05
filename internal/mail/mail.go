// Package mail envía transaccionales (bienvenida, compra confirmada).
// Resend en producción; en desarrollo sin API key, un logger. Los envíos
// son best-effort y asíncronos: un mail caído nunca frena una compra.
package mail

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/alejandro/coffeecoder/internal/config"
)

type Message struct {
	To      string
	Subject string
	HTML    string
	Text    string
	// IdempotencyKey evita duplicados si se reintenta (máx. 256 chars).
	IdempotencyKey string
}

type Mailer interface {
	Send(ctx context.Context, m Message) error
}

// Resend implementa Mailer sobre https://api.resend.com/emails.
type Resend struct {
	cfg     config.MailConfig
	http    *http.Client
	baseURL string
}

func NewResend(cfg config.MailConfig) *Resend {
	return &Resend{cfg: cfg, http: &http.Client{Timeout: 10 * time.Second}, baseURL: "https://api.resend.com"}
}

func (r *Resend) Send(ctx context.Context, m Message) error {
	payload := map[string]any{
		"from": r.cfg.From, "to": []string{m.To}, "subject": m.Subject, "html": m.HTML, "text": m.Text,
	}
	if r.cfg.ReplyTo != "" {
		payload["reply_to"] = r.cfg.ReplyTo
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.baseURL+"/emails", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+r.cfg.ResendAPIKey)
	req.Header.Set("Content-Type", "application/json")
	if m.IdempotencyKey != "" {
		req.Header.Set("Idempotency-Key", m.IdempotencyKey)
	}
	res, err := r.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
		return fmt.Errorf("mail: resend HTTP %d: %s", res.StatusCode, strings.TrimSpace(string(b)))
	}
	return nil
}

// Log es el Mailer de desarrollo: escribe el mail al log.
type Log struct{ logger *slog.Logger }

func NewLog(logger *slog.Logger) *Log { return &Log{logger: logger} }

func (l *Log) Send(_ context.Context, m Message) error {
	l.logger.Info("mail (dev): no enviado", "to", m.To, "subject", m.Subject, "text", m.Text)
	return nil
}

// New elige la implementación según config.
func New(cfg config.MailConfig, logger *slog.Logger) Mailer {
	if cfg.ResendAPIKey == "" {
		return NewLog(logger)
	}
	return NewResend(cfg)
}

// SendAsync dispara el envío sin bloquear al llamador, con timeout
// propio y log del error. Para transaccionales best-effort.
func SendAsync(mailer Mailer, logger *slog.Logger, m Message) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := mailer.Send(ctx, m); err != nil {
			logger.Error("mail: envío fallido", "to", m.To, "subject", m.Subject, "err", err)
		}
	}()
}
