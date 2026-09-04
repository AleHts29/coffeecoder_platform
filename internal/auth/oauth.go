package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/alejandro/coffeecoder/internal/config"
)

// Profile es el resultado normalizado de cualquier proveedor OAuth.
type Profile struct {
	Provider   string // 'google' | 'github'
	ProviderID string
	Email      string
	Name       string
}

type oauthProvider struct {
	authURL  string
	tokenURL string
	scopes   string
}

var providers = map[string]oauthProvider{
	"google": {
		authURL:  "https://accounts.google.com/o/oauth2/v2/auth",
		tokenURL: "https://oauth2.googleapis.com/token",
		scopes:   "openid email profile",
	},
	"github": {
		authURL:  "https://github.com/login/oauth/authorize",
		tokenURL: "https://github.com/login/oauth/access_token",
		scopes:   "read:user user:email",
	},
}

var oauthHTTP = &http.Client{Timeout: 10 * time.Second}

// AuthorizeURL arma la URL de redirección al proveedor.
func AuthorizeURL(cfg config.Config, provider, state string) (string, error) {
	p, ok := providers[provider]
	if !ok {
		return "", fmt.Errorf("auth: proveedor desconocido %q", provider)
	}
	clientID, _, err := credentials(cfg, provider)
	if err != nil {
		return "", err
	}

	q := url.Values{
		"client_id":     {clientID},
		"redirect_uri":  {redirectURI(cfg, provider)},
		"response_type": {"code"},
		"scope":         {p.scopes},
		"state":         {state},
	}
	return p.authURL + "?" + q.Encode(), nil
}

// Exchange canjea el code por un access token del proveedor y trae el
// perfil normalizado.
func Exchange(ctx context.Context, cfg config.Config, provider, code string) (Profile, error) {
	p, ok := providers[provider]
	if !ok {
		return Profile{}, fmt.Errorf("auth: proveedor desconocido %q", provider)
	}
	clientID, secret, err := credentials(cfg, provider)
	if err != nil {
		return Profile{}, err
	}

	form := url.Values{
		"client_id":     {clientID},
		"client_secret": {secret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
		"redirect_uri":  {redirectURI(cfg, provider)},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.tokenURL,
		strings.NewReader(form.Encode()))
	if err != nil {
		return Profile{}, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	res, err := oauthHTTP.Do(req)
	if err != nil {
		return Profile{}, fmt.Errorf("auth: canjeando code: %w", err)
	}
	defer res.Body.Close()

	var tok struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(res.Body).Decode(&tok); err != nil || tok.AccessToken == "" {
		return Profile{}, fmt.Errorf("auth: el proveedor no devolvió access token")
	}

	switch provider {
	case "google":
		return googleProfile(ctx, tok.AccessToken)
	case "github":
		return githubProfile(ctx, tok.AccessToken)
	}
	return Profile{}, fmt.Errorf("auth: proveedor desconocido %q", provider)
}

func googleProfile(ctx context.Context, token string) (Profile, error) {
	var u struct {
		Sub           string `json:"sub"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		Name          string `json:"name"`
	}
	if err := getJSON(ctx, "https://openidconnect.googleapis.com/v1/userinfo", token, &u); err != nil {
		return Profile{}, err
	}
	if !u.EmailVerified {
		return Profile{}, fmt.Errorf("auth: el email de Google no está verificado")
	}
	return Profile{Provider: "google", ProviderID: u.Sub, Email: u.Email, Name: u.Name}, nil
}

func githubProfile(ctx context.Context, token string) (Profile, error) {
	var u struct {
		ID    int64  `json:"id"`
		Login string `json:"login"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	if err := getJSON(ctx, "https://api.github.com/user", token, &u); err != nil {
		return Profile{}, err
	}

	email := u.Email
	if email == "" {
		// El email público puede estar oculto: pedimos la lista y usamos
		// el primario verificado.
		var emails []struct {
			Email    string `json:"email"`
			Primary  bool   `json:"primary"`
			Verified bool   `json:"verified"`
		}
		if err := getJSON(ctx, "https://api.github.com/user/emails", token, &emails); err != nil {
			return Profile{}, err
		}
		for _, e := range emails {
			if e.Primary && e.Verified {
				email = e.Email
				break
			}
		}
	}

	name := u.Name
	if name == "" {
		name = u.Login
	}
	return Profile{
		Provider:   "github",
		ProviderID: fmt.Sprintf("%d", u.ID),
		Email:      email,
		Name:       name,
	}, nil
}

func getJSON(ctx context.Context, endpoint, token string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/json")

	res, err := oauthHTTP.Do(req)
	if err != nil {
		return fmt.Errorf("auth: consultando %s: %w", endpoint, err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		return fmt.Errorf("auth: %s devolvió %d: %s", endpoint, res.StatusCode, body)
	}
	return json.NewDecoder(res.Body).Decode(out)
}

func credentials(cfg config.Config, provider string) (id, secret string, err error) {
	switch provider {
	case "google":
		id, secret = cfg.OAuth.GoogleClientID, cfg.OAuth.GoogleClientSecret
	case "github":
		id, secret = cfg.OAuth.GitHubClientID, cfg.OAuth.GitHubClientSecret
	default:
		return "", "", fmt.Errorf("auth: proveedor desconocido %q", provider)
	}
	if id == "" || secret == "" {
		return "", "", fmt.Errorf("auth: OAuth de %s no está configurado", provider)
	}
	return id, secret, nil
}

func redirectURI(cfg config.Config, provider string) string {
	return strings.TrimRight(cfg.PublicBaseURL, "/") + "/api/v1/auth/oauth/" + provider + "/callback"
}
