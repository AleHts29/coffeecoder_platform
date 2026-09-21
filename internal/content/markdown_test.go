package content

import (
	"reflect"
	"testing"
)

func TestDemoSlugs(t *testing.T) {
	body := `Texto.

::demo[channels-buffer]

Más texto con ::demo[inline] que NO cuenta porque no está sola en su línea.

   ::demo[lfo-amplitud]   

::demo[channels-buffer]

` + "```go\n::demo[dentro-de-codigo]\n```"

	got := DemoSlugs(body)
	want := []string{"channels-buffer", "lfo-amplitud"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("DemoSlugs = %v, want %v", got, want)
	}
	if len(DemoSlugs("sin demos")) != 0 {
		t.Fatal("no debería encontrar demos")
	}
	if s := DemoSlugs("::demo[Mayúsculas]"); len(s) != 0 {
		t.Fatalf("slug inválido aceptado: %v", s)
	}
}

func TestReadingTime(t *testing.T) {
	// 200 palabras de prosa = 1 minuto exacto.
	prose := ""
	for i := 0; i < 200; i++ {
		prose += "palabra "
	}
	if got := ReadingTime(prose); got != 60 {
		t.Errorf("200 palabras = %d s, want 60", got)
	}
	// El código pesa la mitad: 200 "palabras" de código = 30 s.
	code := "```go\n" + prose + "\n```"
	if got := ReadingTime(code); got < 28 || got > 34 {
		t.Errorf("200 palabras de código = %d s, want ~30", got)
	}
	// Cada demo suma 60 s.
	withDemo := prose + "\n\n::demo[una]\n"
	if got := ReadingTime(withDemo); got != 120 {
		t.Errorf("prosa + 1 demo = %d s, want 120", got)
	}
	// Piso para textos muy cortos.
	if got := ReadingTime("Hola."); got != minReadingTimeS {
		t.Errorf("texto corto = %d s, want %d", got, minReadingTimeS)
	}
}
