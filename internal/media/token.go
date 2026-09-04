package media

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"sort"
	"strings"
)

// SignCDNURL implementa el token authentication vigente de bunny.net
// (esquema HS256, portado de BunnyWay/BunnyCDN.TokenAuthentication
// v2.1.0, verificado contra sus vectores e2e en token_test.go):
//
//	token = "HS256-" + Base64URL(HMAC-SHA256(key, signaturePath + expires + signingData))
//
// donde signaturePath es tokenPath si se pasa (token de directorio: vale
// para todo lo que cuelga de ese prefijo, imprescindible para que el
// playlist HLS y sus segmentos compartan token) y signingData son los
// parámetros extra ordenados alfabéticamente como k=v&k=v.
// No se firma IP: el alumno puede cambiar de red durante una clase.
func SignCDNURL(rawURL, securityKey string, expires int64, tokenPath string) (string, error) {
	if securityKey == "" {
		return "", errors.New("media: securityKey vacía")
	}
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("media: URL inválida: %w", err)
	}

	params := map[string]string{}
	for k, vs := range parsed.Query() {
		if len(vs) > 0 {
			params[k] = vs[0]
		}
	}
	if tokenPath != "" {
		params["token_path"] = tokenPath
	}

	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	signingParts := make([]string, len(keys))
	urlParts := make([]string, len(keys))
	for i, k := range keys {
		signingParts[i] = k + "=" + params[k]
		urlParts[i] = k + "=" + strings.ReplaceAll(url.QueryEscape(params[k]), "+", "%20")
	}

	signaturePath := tokenPath
	if signaturePath == "" {
		signaturePath = parsed.Path
	}
	expiresStr := fmt.Sprintf("%d", expires)

	mac := hmac.New(sha256.New, []byte(securityKey))
	mac.Write([]byte(signaturePath))
	mac.Write([]byte(expiresStr))
	mac.Write([]byte(strings.Join(signingParts, "&")))
	token := "HS256-" + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))

	tail := ""
	if len(urlParts) > 0 {
		tail = "&" + strings.Join(urlParts, "&")
	}
	return parsed.Scheme + "://" + parsed.Host + parsed.Path + "?token=" + token + tail + "&expires=" + expiresStr, nil
}
