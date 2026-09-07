package server

import (
	"bytes"
	"context"
	"fmt"
	"html"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/alejandro/coffeecoder/internal/catalog"
)

// mountWeb sirve la PWA compilada (web/dist) desde el mismo binario:
// assets con cache larga (tienen hash) y, para cualquier otra ruta,
// index.html con metadatos Open Graph inyectados por curso/carrera.
// Así los crawlers ven título y descripción reales sin SSR.
func mountWeb(r chi.Router, dist, publicURL string, cat *catalog.Service) error {
	index, err := os.ReadFile(filepath.Join(dist, "index.html"))
	if err != nil {
		return fmt.Errorf("web: leyendo index.html en %s: %w", dist, err)
	}
	assets := http.FileServer(http.Dir(dist))
	og := &ogInjector{index: index, publicURL: strings.TrimRight(publicURL, "/"), cat: cat}

	serve := func(w http.ResponseWriter, req *http.Request) {
		p := path.Clean(req.URL.Path)
		if p != "/" && path.Ext(p) != "" {
			if strings.HasPrefix(p, "/assets/") {
				w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
			}
			assets.ServeHTTP(w, req)
			return
		}
		ctx, cancel := context.WithTimeout(req.Context(), 2*time.Second)
		defer cancel()
		body := og.render(ctx, p)
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		_, _ = w.Write(body)
	}
	// GET y HEAD (crawlers y health checks de CDN hacen HEAD).
	r.Get("/*", serve)
	r.Head("/*", serve)
	return nil
}

type ogInjector struct {
	index     []byte
	publicURL string
	cat       *catalog.Service
}

type ogMeta struct {
	Title, Description, URL, Type string
}

func (o *ogInjector) render(ctx context.Context, p string) []byte {
	meta := ogMeta{
		Title:       "CoffeeCoder",
		Description: "Carreras y cursos de backend en profundidad. Catálogo chico, aprendizaje serio.",
		URL:         o.publicURL + p,
		Type:        "website",
	}
	switch {
	case strings.HasPrefix(p, "/cursos/"):
		if slug := segment(p, 2); slug != "" {
			if c, err := o.cat.GetCourse(ctx, slug); err == nil {
				meta.Title = c.Title + " · CoffeeCoder"
				meta.Description = firstNonEmpty(c.Subtitle, c.Description, meta.Description)
				meta.Type = "product"
			}
		}
	case strings.HasPrefix(p, "/carreras/"):
		if slug := segment(p, 2); slug != "" {
			if c, err := o.cat.GetCareer(ctx, slug); err == nil {
				meta.Title = c.Title + " · CoffeeCoder"
				meta.Description = firstNonEmpty(c.Subtitle, c.Description, meta.Description)
				meta.Type = "product"
			}
		}
	}

	var tags bytes.Buffer
	fmt.Fprintf(&tags, `<meta property="og:title" content="%s" />`, html.EscapeString(meta.Title))
	fmt.Fprintf(&tags, `<meta property="og:description" content="%s" />`, html.EscapeString(meta.Description))
	fmt.Fprintf(&tags, `<meta property="og:url" content="%s" />`, html.EscapeString(meta.URL))
	fmt.Fprintf(&tags, `<meta property="og:type" content="%s" />`, meta.Type)
	fmt.Fprintf(&tags, `<meta property="og:site_name" content="CoffeeCoder" />`)
	fmt.Fprintf(&tags, `<meta property="og:locale" content="es_AR" />`)
	fmt.Fprintf(&tags, `<meta name="twitter:card" content="summary" />`)
	fmt.Fprintf(&tags, `<link rel="canonical" href="%s" />`, html.EscapeString(meta.URL))

	out := bytes.Replace(o.index, []byte("<title>CoffeeCoder</title>"), []byte("<title>"+html.EscapeString(meta.Title)+"</title>"), 1)
	out = bytes.Replace(out, []byte(`content="Carreras y cursos de backend en profundidad. Catálogo chico, aprendizaje serio."`), []byte(`content="`+html.EscapeString(meta.Description)+`"`), 1)
	return bytes.Replace(out, []byte("</head>"), append(tags.Bytes(), []byte("</head>")...), 1)
}

func segment(p string, i int) string {
	parts := strings.Split(strings.Trim(p, "/"), "/")
	if len(parts) <= i-1 {
		return ""
	}
	return parts[i-1]
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
