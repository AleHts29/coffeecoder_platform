package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/alejandro/coffeecoder/internal/config"
	"github.com/alejandro/coffeecoder/internal/testutil"
)

func newTestService(t *testing.T) *Service {
	t.Helper()
	q, _ := testutil.Queries(t)
	return NewService(config.Config{
		JWTSecret:       "test-secret",
		AccessTokenTTL:  15 * time.Minute,
		RefreshTokenTTL: 24 * time.Hour,
	}, q)
}

func TestRegister_DuplicateEmail(t *testing.T) {
	svc := newTestService(t)
	ctx := context.Background()
	email := "dup-" + uuid.NewString()[:8] + "@test.dev"

	if _, _, err := svc.Register(ctx, email, "Cafecito-2026!", "Uno"); err != nil {
		t.Fatal(err)
	}
	// Mismo email con otra capitalización: citext lo trata igual.
	_, _, err := svc.Register(ctx, "  "+email+" ", "Cafecito-2026!", "Dos")
	if !errors.Is(err, ErrEmailTaken) {
		t.Fatalf("err = %v, want ErrEmailTaken", err)
	}
	if _, _, err := svc.Register(ctx, "corta@test.dev", "1234567", "X"); err == nil {
		t.Fatal("contraseña corta aceptada")
	}
}

func TestLogin_InvalidCredentials(t *testing.T) {
	svc := newTestService(t)
	ctx := context.Background()
	email := "login-" + uuid.NewString()[:8] + "@test.dev"
	if _, _, err := svc.Register(ctx, email, "Cafecito-2026!", "Uno"); err != nil {
		t.Fatal(err)
	}

	if _, _, err := svc.Login(ctx, email, "otra"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("contraseña mala: err = %v", err)
	}
	if _, _, err := svc.Login(ctx, "nadie@test.dev", "Cafecito-2026!"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("usuario inexistente: err = %v", err)
	}
	user, pair, err := svc.Login(ctx, email, "Cafecito-2026!")
	if err != nil || pair.AccessToken == "" || pair.RefreshToken == "" {
		t.Fatalf("login ok: %v", err)
	}
	if user.PasswordHash == nil {
		t.Fatal("el service debe traer el hash internamente")
	}
	claims, err := ParseAccessToken("test-secret", pair.AccessToken)
	if err != nil || claims.Subject != user.ID.String() || claims.Role != "student" {
		t.Fatalf("claims = %+v, %v", claims, err)
	}
}

func TestRefresh_RotationAndReuseDetection(t *testing.T) {
	svc := newTestService(t)
	ctx := context.Background()
	email := "rot-" + uuid.NewString()[:8] + "@test.dev"
	_, first, err := svc.Register(ctx, email, "Cafecito-2026!", "Uno")
	if err != nil {
		t.Fatal(err)
	}

	second, err := svc.Refresh(ctx, first.RefreshToken)
	if err != nil {
		t.Fatalf("primera rotación: %v", err)
	}
	if second.RefreshToken == first.RefreshToken {
		t.Fatal("el refresh no rotó")
	}

	// Reuso del token viejo: señal de robo → toda la familia cae.
	if _, err := svc.Refresh(ctx, first.RefreshToken); !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("reuso: err = %v", err)
	}
	if _, err := svc.Refresh(ctx, second.RefreshToken); !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("el token vigente debería haber sido revocado tras el reuso: err = %v", err)
	}

	// Sesión nueva tras el incidente funciona normal, y logout la cierra.
	_, third, err := svc.Login(ctx, email, "Cafecito-2026!")
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Logout(ctx, third.RefreshToken); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Refresh(ctx, third.RefreshToken); !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("tras logout: err = %v", err)
	}
	if _, err := svc.Refresh(ctx, "token-inventado"); !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("token desconocido: err = %v", err)
	}
}

func TestLoginOAuth_LinksExistingEmail(t *testing.T) {
	svc := newTestService(t)
	ctx := context.Background()
	email := "oauth-" + uuid.NewString()[:8] + "@test.dev"
	local, _, err := svc.Register(ctx, email, "Cafecito-2026!", "Local")
	if err != nil {
		t.Fatal(err)
	}

	p := Profile{Provider: "github", ProviderID: "gh-" + uuid.NewString()[:8], Email: email, Name: "GH"}
	linked, _, err := svc.LoginOAuth(ctx, p)
	if err != nil {
		t.Fatal(err)
	}
	if linked.ID != local.ID {
		t.Fatal("la identidad OAuth debería vincularse a la cuenta existente por email")
	}
	again, _, err := svc.LoginOAuth(ctx, p)
	if err != nil || again.ID != local.ID {
		t.Fatalf("segundo login OAuth: %v", err)
	}

	fresh, _, err := svc.LoginOAuth(ctx, Profile{Provider: "google", ProviderID: "g-1", Email: "nuevo-" + uuid.NewString()[:8] + "@test.dev", Name: "Nuevo"})
	if err != nil || fresh.PasswordHash != nil {
		t.Fatalf("usuario nuevo por OAuth: %+v, %v", fresh, err)
	}
	if _, _, err := svc.Login(ctx, fresh.Email, "cualquiera"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("cuenta solo-OAuth no debería loguear con contraseña: %v", err)
	}
}
