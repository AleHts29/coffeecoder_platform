package mail

import (
	"fmt"
	"html"
)

// Plantillas mínimas con la voz de marca: directas, sin exclamaciones
// gratuitas, un guiño de café por mail como máximo.

func Welcome(name string) (subject, htmlBody, text string) {
	n := firstName(name)
	subject = "Bienvenido a CoffeeCoder"
	text = fmt.Sprintf("Hola %s.\n\nTu cuenta ya está lista. Cuando quieras, servite un café y empezá por el catálogo.\n\nCoffeeCoder", n)
	htmlBody = layout(fmt.Sprintf(`<p>Hola %s.</p><p>Tu cuenta ya está lista. Cuando quieras, servite un café y empezá por el catálogo.</p>`, html.EscapeString(n)))
	return
}

func PurchaseConfirmed(name, productTitle, kind, url string) (subject, htmlBody, text string) {
	n := firstName(name)
	subject = fmt.Sprintf("Compra confirmada: %s", productTitle)
	text = fmt.Sprintf("Hola %s.\n\nTu pago de %s \"%s\" se acreditó. Ya tenés acceso de por vida, con todas las actualizaciones.\n\nEmpezá acá: %s\n\nCoffeeCoder", n, kind, productTitle, url)
	htmlBody = layout(fmt.Sprintf(`<p>Hola %s.</p><p>Tu pago de %s <strong>%s</strong> se acreditó. Ya tenés acceso de por vida, con todas las actualizaciones.</p><p><a href="%s" style="display:inline-block;background:#E08E33;color:#141414;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:500">Empezar</a></p>`,
		html.EscapeString(n), kind, html.EscapeString(productTitle), html.EscapeString(url)))
	return
}

func layout(body string) string {
	return `<!doctype html><html lang="es"><body style="margin:0;background:#141414;color:#EDEDEB;font-family:ui-sans-serif,system-ui,sans-serif;padding:32px">` +
		`<div style="max-width:520px;margin:0 auto">` +
		`<p style="font-family:ui-monospace,monospace;font-weight:500;margin:0 0 24px">coffeecoder<span style="color:#E08E33">_</span></p>` +
		body +
		`<p style="color:#7A7A78;font-size:12px;margin-top:32px">CoffeeCoder · backend en profundidad</p>` +
		`</div></body></html>`
}

func firstName(name string) string {
	if name == "" {
		return "hola"
	}
	for i, r := range name {
		if r == ' ' {
			return name[:i]
		}
	}
	return name
}
