package content

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
)

// FrameTTL: vida de una URL de demo firmada. Corta a propósito; el
// frontend vuelve a pedir /content si la demo se monta más tarde.
const FrameTTL = 30 * time.Minute

// signFrame firma (demoID, expiración) con HMAC-SHA256. Mismo patrón que
// la URL de video: la firma viaja en la URL y el HTML nunca se expone
// sin verificarla.
func signFrame(secret string, demoID uuid.UUID, exp int64) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(demoID.String()))
	mac.Write([]byte(":"))
	mac.Write([]byte(strconv.FormatInt(exp, 10)))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

// FrameURL devuelve la URL relativa y firmada de una demo. Relativa para
// que funcione igual detrás del proxy de Vite en desarrollo y desde el
// binario en producción (y para que `frame-ancestors 'self'` aplique).
func FrameURL(secret string, demoID uuid.UUID, now time.Time) string {
	exp := now.Add(FrameTTL).Unix()
	return fmt.Sprintf("/api/v1/demos/%s/frame?exp=%d&sig=%s", demoID, exp, signFrame(secret, demoID, exp))
}

// VerifyFrame valida firma y expiración en tiempo constante.
func VerifyFrame(secret string, demoID uuid.UUID, expRaw, sig string, now time.Time) bool {
	exp, err := strconv.ParseInt(expRaw, 10, 64)
	if err != nil || now.Unix() > exp {
		return false
	}
	return hmac.Equal([]byte(signFrame(secret, demoID, exp)), []byte(sig))
}
