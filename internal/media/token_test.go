package media

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

// Vectores oficiales de BunnyWay/BunnyCDN.TokenAuthentication (e2e/).
// Solo se contrastan los casos sin IP, sin países ni límite de
// velocidad: los que este módulo firma.
func TestSignCDNURL_OfficialVectors(t *testing.T) {
	var inputs struct {
		Key     string `json:"key"`
		Expires int64  `json:"expires"`
		Host    string `json:"host"`
		Cases   []struct {
			Name             string `json:"name"`
			Path             string `json:"path"`
			UserIP           string `json:"userIp"`
			IsDirectory      bool   `json:"isDirectory"`
			PathAllowed      string `json:"pathAllowed"`
			CountriesAllowed string `json:"countriesAllowed"`
			CountriesBlocked string `json:"countriesBlocked"`
			IgnoreParams     bool   `json:"ignoreParams"`
			SpeedLimit       int64  `json:"speedLimit"`
		} `json:"cases"`
	}
	var vectors struct {
		Vectors []struct {
			Name      string `json:"name"`
			SignedURL string `json:"signedUrl"`
			Token     string `json:"token"`
		} `json:"vectors"`
	}
	mustLoad(t, "testdata/inputs.json", &inputs)
	mustLoad(t, "testdata/vectors.json", &vectors)

	expected := map[string]string{}
	for _, v := range vectors.Vectors {
		expected[v.Name] = v.SignedURL
	}

	checked := 0
	for _, c := range inputs.Cases {
		if c.UserIP != "" || c.IsDirectory || c.CountriesAllowed != "" || c.CountriesBlocked != "" || c.IgnoreParams || c.SpeedLimit > 0 {
			continue
		}
		got, err := SignCDNURL(inputs.Host+c.Path, inputs.Key, inputs.Expires, c.PathAllowed)
		if err != nil {
			t.Fatalf("%s: %v", c.Name, err)
		}
		if got != expected[c.Name] {
			t.Errorf("%s:\n got  %s\n want %s", c.Name, got, expected[c.Name])
		}
		checked++
	}
	if checked == 0 {
		t.Fatal("ningún vector aplicable: revisá testdata")
	}
	t.Logf("%d vectores oficiales verificados", checked)
}

func TestBunny_SignedPlaybackURL_UsesDirectoryToken(t *testing.T) {
	b := NewBunny(bunnyTestConfig())
	url, err := b.SignedPlaybackURL("abc-123", 3600)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"https://vz-test.b-cdn.net/abc-123/playlist.m3u8?token=HS256-",
		"&token_path=%2Fabc-123%2F",
		"&expires=",
	} {
		if !strings.Contains(url, want) {
			t.Errorf("URL %q no contiene %q", url, want)
		}
	}
}

func TestBunny_SignedPlaybackURL_RequiresConfig(t *testing.T) {
	cfg := bunnyTestConfig()
	cfg.TokenAuthKey = ""
	if _, err := NewBunny(cfg).SignedPlaybackURL("x", 1); err == nil {
		t.Fatal("esperaba error por configuración incompleta")
	}
}

func mustLoad(t *testing.T, path string, out any) {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, out); err != nil {
		t.Fatal(err)
	}
}
