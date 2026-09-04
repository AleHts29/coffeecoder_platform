package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/httpx"
)

type ctxKey int

const identityKey ctxKey = iota

// Identity es lo que el resto de los módulos leen del contexto.
type Identity struct {
	UserID uuid.UUID
	Role   string
}

// IdentityFrom devuelve la identidad del request, si la hay.
func IdentityFrom(ctx context.Context) (Identity, bool) {
	id, ok := ctx.Value(identityKey).(Identity)
	return id, ok
}

// Middleware exige un Bearer token válido y carga la identidad.
func Middleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearer(r)
			if !ok {
				httpx.Error(w, http.StatusUnauthorized, "token requerido")
				return
			}

			claims, err := ParseAccessToken(jwtSecret, raw)
			if err != nil {
				httpx.Error(w, http.StatusUnauthorized, "token inválido o vencido")
				return
			}

			userID, err := uuid.Parse(claims.Subject)
			if err != nil {
				httpx.Error(w, http.StatusUnauthorized, "token inválido")
				return
			}

			ctx := context.WithValue(r.Context(), identityKey, Identity{
				UserID: userID,
				Role:   claims.Role,
			})
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequireRole corta con 403 si la identidad no tiene el rol pedido.
// Se monta después de Middleware.
func RequireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id, ok := IdentityFrom(r.Context())
			if !ok || id.Role != role {
				httpx.Error(w, http.StatusForbidden, "permisos insuficientes")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func bearer(r *http.Request) (string, bool) {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(h, prefix) {
		return "", false
	}
	return strings.TrimPrefix(h, prefix), true
}
