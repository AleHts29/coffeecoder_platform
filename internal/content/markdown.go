// Package content sirve las lecciones de lectura (artículos en Markdown)
// y la biblioteca de demos interactivas de cada curso. El texto y el
// HTML de las demos siguen la misma regla que video_asset_id: solo
// salen por endpoints que verifican acceso (ver docs/DEMOS.md).
package content

import (
	"math"
	"regexp"
	"strings"
)

// demoDirective reconoce `::demo[slug]` sola en su línea.
var demoDirective = regexp.MustCompile(`(?m)^[ \t]*::demo\[([a-z0-9]+(?:-[a-z0-9]+)*)\][ \t]*$`)

// DemoSlugs devuelve los slugs referenciados por un cuerpo Markdown, en
// orden de aparición y sin repetir. Una directiva dentro de un bloque de
// código es texto, no una demo (igual que en el render del frontend: el
// Markdown la trata como código).
func DemoSlugs(body string) []string {
	var (
		out  []string
		seen = map[string]bool{}
	)
	body = fencedCode.ReplaceAllString(body, "\n")
	for _, m := range demoDirective.FindAllStringSubmatch(body, -1) {
		if !seen[m[1]] {
			seen[m[1]] = true
			out = append(out, m[1])
		}
	}
	return out
}

const (
	wordsPerMinute  = 200
	secondsPerDemo  = 60
	minReadingTimeS = 30
)

var fencedCode = regexp.MustCompile("(?s)```.*?(```|$)")

// ReadingTime estima el tiempo de lectura de un artículo: ~200
// palabras/min sobre la prosa, los bloques de código a la mitad de peso
// (se leen más lento pero se saltean), y 60 s por cada demo, que el
// alumno manipula. Devuelve segundos.
func ReadingTime(body string) int32 {
	demos := len(DemoSlugs(body))

	var codeWords int
	prose := fencedCode.ReplaceAllStringFunc(body, func(block string) string {
		codeWords += len(strings.Fields(block))
		return " "
	})
	proseWords := len(strings.Fields(demoDirective.ReplaceAllString(prose, " ")))

	weight := float64(proseWords) + float64(codeWords)/2
	seconds := int(math.Ceil(weight/wordsPerMinute*60)) + demos*secondsPerDemo
	if seconds < minReadingTimeS {
		seconds = minReadingTimeS
	}
	return int32(seconds)
}
