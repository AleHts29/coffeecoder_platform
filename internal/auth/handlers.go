package auth

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/httpx"
	"github.com/alejandro/coffeecoder/internal/store"
)

const (
	refreshCookie = "cc_refresh"
	stateCookie   = "cc_oauth_state"
)

type Handler struct {
	cfg    config.Config
	svc    *Service
	logger *slog.Logger
}

func NewHandler(cfg config.Config, svc *Service, logger *slog.Logger) *Handler {
	return &Handler{cfg: cfg, svc: svc, logger: logger}
}

func (h *Handler) Mount(r chi.Router) {
	r.Post("/register", h.register)
	r.Post("/login", h.login)
	r.Post("/refresh", h.refresh)
	r.Post("/logout", h.logout)
	r.Get("/oauth/{provider}", h.oauthStart)
	r.Get("/oauth/{provider}/callback", h.oauthCallback)
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

type authResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int64  `json:"expires_in"`
	User        any    `json:"user"`
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return
	}

	user, pair, err := h.svc.Register(r.Context(), req.Email, req.Password, req.Name)
	if errors.Is(err, ErrEmailTaken) {
		httpx.Error(w, http.StatusConflict, err.Error())
		return
	} else if err != nil {
		h.fail(w, "register", err)
		return
	}

	h.setRefreshCookie(w, pair.RefreshToken)
	httpx.JSON(w, http.StatusCreated, authResponse{
		AccessToken: pair.AccessToken,
		ExpiresIn:   pair.ExpiresIn,
		User:        publicUser(user),
	})
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "JSON inválido")
		return
	}

	user, pair, err := h.svc.Login(r.Context(), req.Email, req.Password)
	if errors.Is(err, ErrInvalidCredentials) {
		httpx.Error(w, http.StatusUnauthorized, err.Error())
		return
	} else if err != nil {
		h.fail(w, "login", err)
		return
	}

	h.setRefreshCookie(w, pair.RefreshToken)
	httpx.JSON(w, http.StatusOK, authResponse{
		AccessToken: pair.AccessToken,
		ExpiresIn:   pair.ExpiresIn,
		User:        publicUser(user),
	})
}

// refresh lee el token de la cookie HttpOnly (web) o del body (mobile).
func (h *Handler) refresh(w http.ResponseWriter, r *http.Request) {
	raw := h.refreshFromRequest(r)
	if raw == "" {
		httpx.Error(w, http.StatusUnauthorized, "sesión no encontrada")
		return
	}

	pair, err := h.svc.Refresh(r.Context(), raw)
	if errors.Is(err, ErrInvalidRefresh) {
		h.clearRefreshCookie(w)
		httpx.Error(w, http.StatusUnauthorized, err.Error())
		return
	} else if err != nil {
		h.fail(w, "refresh", err)
		return
	}

	h.setRefreshCookie(w, pair.RefreshToken)
	httpx.JSON(w, http.StatusOK, authResponse{
		AccessToken: pair.AccessToken,
		ExpiresIn:   pair.ExpiresIn,
	})
}

func (h *Handler) logout(w http.ResponseWriter, r *http.Request) {
	if raw := h.refreshFromRequest(r); raw != "" {
		_ = h.svc.Logout(r.Context(), raw)
	}
	h.clearRefreshCookie(w)
	w.WriteHeader(http.StatusNoContent)
}

// Me devuelve el usuario autenticado. Se monta detrás de Middleware.
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	id, ok := IdentityFrom(r.Context())
	if !ok {
		httpx.Error(w, http.StatusUnauthorized, "token requerido")
		return
	}
	user, err := h.svc.q.GetUserByID(r.Context(), id.UserID)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "sesión inválida, iniciá sesión de nuevo")
		return
	}
	httpx.JSON(w, http.StatusOK, publicUser(user))
}

func (h *Handler) oauthStart(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")

	state, err := randomState()
	if err != nil {
		h.fail(w, "oauth state", err)
		return
	}

	target, err := AuthorizeURL(h.cfg, provider, state)
	if err != nil {
		httpx.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     stateCookie,
		Value:    state,
		Path:     "/api/v1/auth",
		MaxAge:   600,
		HttpOnly: true,
		Secure:   h.cfg.Env != "development",
		SameSite: http.SameSiteLaxMode,
	})
	http.Redirect(w, r, target, http.StatusFound)
}

func (h *Handler) oauthCallback(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")

	cookie, err := r.Cookie(stateCookie)
	if err != nil || cookie.Value == "" || cookie.Value != r.URL.Query().Get("state") {
		httpx.Error(w, http.StatusBadRequest, "state inválido, reintentá el login")
		return
	}

	code := r.URL.Query().Get("code")
	if code == "" {
		httpx.Error(w, http.StatusBadRequest, "el proveedor no devolvió un code")
		return
	}

	profile, err := Exchange(r.Context(), h.cfg, provider, code)
	if err != nil {
		h.fail(w, "oauth exchange", err)
		return
	}

	_, pair, err := h.svc.LoginOAuth(r.Context(), profile)
	if err != nil {
		h.fail(w, "oauth login", err)
		return
	}

	// El refresh queda en cookie HttpOnly; el frontend arranca pidiendo
	// /refresh para obtener su primer access token.
	h.setRefreshCookie(w, pair.RefreshToken)
	http.Redirect(w, r, h.cfg.FrontendURL+"/auth/callback", http.StatusFound)
}

// --- helpers ---

func (h *Handler) refreshFromRequest(r *http.Request) string {
	if c, err := r.Cookie(refreshCookie); err == nil && c.Value != "" {
		return c.Value
	}
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err == nil {
		return body.RefreshToken
	}
	return ""
}

func (h *Handler) setRefreshCookie(w http.ResponseWriter, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     refreshCookie,
		Value:    token,
		Path:     "/api/v1/auth",
		MaxAge:   int(h.cfg.RefreshTokenTTL / time.Second),
		HttpOnly: true,
		Secure:   h.cfg.Env != "development",
		SameSite: http.SameSiteLaxMode,
	})
}

func (h *Handler) clearRefreshCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     refreshCookie,
		Value:    "",
		Path:     "/api/v1/auth",
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   h.cfg.Env != "development",
		SameSite: http.SameSiteLaxMode,
	})
}

func (h *Handler) fail(w http.ResponseWriter, op string, err error) {
	h.logger.Error("auth: "+op, "err", err)
	httpx.Error(w, http.StatusInternalServerError, "algo salió mal, reintentá")
}

type userDTO struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
	Role  string `json:"role"`
}

// publicUser es el único shape de usuario que sale por la API:
// nunca serializamos store.User directo (expondría password_hash).
func publicUser(u store.User) userDTO {
	return userDTO{
		ID:    u.ID.String(),
		Email: u.Email,
		Name:  u.Name,
		Role:  u.Role,
	}
}

func randomState() (string, error) {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
