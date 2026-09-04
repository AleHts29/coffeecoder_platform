package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrInvalidCredentials = errors.New("email o contraseña incorrectos")
	ErrEmailTaken         = errors.New("el email ya está registrado")
	ErrInvalidRefresh     = errors.New("sesión inválida, iniciá sesión de nuevo")
)

type Service struct {
	cfg config.Config
	q   *store.Queries
}

func NewService(cfg config.Config, q *store.Queries) *Service {
	return &Service{cfg: cfg, q: q}
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"` // segundos del access token
}

func (s *Service) Register(ctx context.Context, email, password, name string) (store.User, TokenPair, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	if len(password) < 8 {
		return store.User{}, TokenPair{}, fmt.Errorf("la contraseña debe tener al menos 8 caracteres")
	}

	if _, err := s.q.GetUserByEmail(ctx, email); err == nil {
		return store.User{}, TokenPair{}, ErrEmailTaken
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return store.User{}, TokenPair{}, err
	}

	hash, err := HashPassword(password)
	if err != nil {
		return store.User{}, TokenPair{}, err
	}

	user, err := s.q.CreateUser(ctx, store.CreateUserParams{
		Email:        email,
		PasswordHash: &hash,
		Name:         strings.TrimSpace(name),
	})
	if err != nil {
		return store.User{}, TokenPair{}, err
	}

	pair, err := s.issuePair(ctx, user)
	return user, pair, err
}

func (s *Service) Login(ctx context.Context, email, password string) (store.User, TokenPair, error) {
	email = strings.TrimSpace(strings.ToLower(email))

	user, err := s.q.GetUserByEmail(ctx, email)
	if errors.Is(err, pgx.ErrNoRows) {
		// Igualamos el costo de la rama "no existe" con una verificación
		// dummy para no filtrar existencia de cuentas por timing.
		_, _ = VerifyPassword(password, dummyHash)
		return store.User{}, TokenPair{}, ErrInvalidCredentials
	} else if err != nil {
		return store.User{}, TokenPair{}, err
	}

	if user.PasswordHash == nil {
		// Cuenta creada por OAuth sin contraseña local.
		return store.User{}, TokenPair{}, ErrInvalidCredentials
	}

	ok, err := VerifyPassword(password, *user.PasswordHash)
	if err != nil || !ok {
		return store.User{}, TokenPair{}, ErrInvalidCredentials
	}

	pair, err := s.issuePair(ctx, user)
	return user, pair, err
}

// Refresh rota el refresh token: revoca el usado y emite uno nuevo.
// Si llega un token ya revocado es señal de robo (alguien reusó un
// token viejo): se revoca toda la familia del usuario.
func (s *Service) Refresh(ctx context.Context, rawToken string) (TokenPair, error) {
	rt, err := s.q.GetRefreshTokenByHash(ctx, HashRefreshToken(rawToken))
	if errors.Is(err, pgx.ErrNoRows) {
		return TokenPair{}, ErrInvalidRefresh
	} else if err != nil {
		return TokenPair{}, err
	}

	if rt.RevokedAt.Valid {
		_ = s.q.RevokeAllUserRefreshTokens(ctx, rt.UserID)
		return TokenPair{}, ErrInvalidRefresh
	}
	if rt.ExpiresAt.Time.Before(time.Now()) {
		return TokenPair{}, ErrInvalidRefresh
	}

	if err := s.q.RevokeRefreshToken(ctx, rt.ID); err != nil {
		return TokenPair{}, err
	}

	user, err := s.q.GetUserByID(ctx, rt.UserID)
	if err != nil {
		return TokenPair{}, err
	}
	return s.issuePair(ctx, user)
}

func (s *Service) Logout(ctx context.Context, rawToken string) error {
	rt, err := s.q.GetRefreshTokenByHash(ctx, HashRefreshToken(rawToken))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil // idempotente
	} else if err != nil {
		return err
	}
	return s.q.RevokeRefreshToken(ctx, rt.ID)
}

// LoginOAuth resuelve el perfil externo a un usuario local:
// 1. identidad ya vinculada → ese usuario;
// 2. email existente → vincula la identidad a esa cuenta;
// 3. si no → crea usuario sin contraseña local.
func (s *Service) LoginOAuth(ctx context.Context, p Profile) (store.User, TokenPair, error) {
	user, err := s.q.GetUserByOAuthIdentity(ctx, store.GetUserByOAuthIdentityParams{
		Provider:   p.Provider,
		ProviderID: p.ProviderID,
	})
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return store.User{}, TokenPair{}, err
	}

	if errors.Is(err, pgx.ErrNoRows) {
		email := strings.TrimSpace(strings.ToLower(p.Email))
		if email == "" {
			return store.User{}, TokenPair{}, fmt.Errorf("el proveedor no devolvió un email verificado")
		}

		user, err = s.q.GetUserByEmail(ctx, email)
		if errors.Is(err, pgx.ErrNoRows) {
			user, err = s.q.CreateUser(ctx, store.CreateUserParams{
				Email:        email,
				PasswordHash: nil,
				Name:         p.Name,
			})
		}
		if err != nil {
			return store.User{}, TokenPair{}, err
		}

		if err := s.q.LinkOAuthIdentity(ctx, store.LinkOAuthIdentityParams{
			Provider:   p.Provider,
			ProviderID: p.ProviderID,
			UserID:     user.ID,
		}); err != nil {
			return store.User{}, TokenPair{}, err
		}
	}

	pair, err := s.issuePair(ctx, user)
	return user, pair, err
}

func (s *Service) issuePair(ctx context.Context, user store.User) (TokenPair, error) {
	access, err := IssueAccessToken(s.cfg.JWTSecret, user.ID, user.Role, s.cfg.AccessTokenTTL)
	if err != nil {
		return TokenPair{}, err
	}

	raw, hash, err := NewRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}

	expires := pgtype.Timestamptz{Time: time.Now().Add(s.cfg.RefreshTokenTTL), Valid: true}
	if _, err := s.q.CreateRefreshToken(ctx, store.CreateRefreshTokenParams{
		UserID:    user.ID,
		TokenHash: hash,
		ExpiresAt: expires,
	}); err != nil {
		return TokenPair{}, err
	}

	return TokenPair{
		AccessToken:  access,
		RefreshToken: raw,
		ExpiresIn:    int64(s.cfg.AccessTokenTTL.Seconds()),
	}, nil
}

// Hash precomputado de una contraseña aleatoria, usado para igualar
// tiempos en la rama "usuario inexistente" del login.
var dummyHash = func() string {
	h, _ := HashPassword("coffeecoder-dummy-timing-equalizer")
	return h
}()
