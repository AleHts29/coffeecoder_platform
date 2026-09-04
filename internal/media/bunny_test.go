package media

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alejandro/coffeecoder/internal/config"
)

func bunnyTestConfig() config.BunnyConfig {
	return config.BunnyConfig{
		LibraryID:    "133",
		APIKey:       "api-key",
		TokenAuthKey: "token-key",
		CDNHostname:  "vz-test.b-cdn.net",
		APIBaseURL:   "https://video.bunnycdn.com",
	}
}

func TestBunny_CreateVideoAndGetAsset(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("AccessKey") != "api-key" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		switch r.Method + " " + r.URL.Path {
		case "POST /library/133/videos":
			var body map[string]string
			_ = json.NewDecoder(r.Body).Decode(&body)
			if body["title"] != "Lección 1" {
				t.Errorf("title = %q", body["title"])
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"guid": "guid-1"})
		case "GET /library/133/videos/guid-1":
			_ = json.NewEncoder(w).Encode(map[string]any{"status": 4, "length": 615})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()

	cfg := bunnyTestConfig()
	cfg.APIBaseURL = srv.URL
	b := NewBunny(cfg)

	id, err := b.CreateVideo(context.Background(), "Lección 1")
	if err != nil || id != "guid-1" {
		t.Fatalf("CreateVideo = %q, %v", id, err)
	}
	info, err := b.GetAsset(context.Background(), "guid-1")
	if err != nil {
		t.Fatal(err)
	}
	if info.Status != StatusReady || info.DurationS != 615 {
		t.Fatalf("GetAsset = %+v", info)
	}
}

func TestBunny_UploadTicketSignature(t *testing.T) {
	b := NewBunny(bunnyTestConfig())
	ticket, err := b.UploadTicket("guid-1", 3600)
	if err != nil {
		t.Fatal(err)
	}
	if ticket.Endpoint != "https://video.bunnycdn.com/tusupload" {
		t.Errorf("endpoint = %q", ticket.Endpoint)
	}
	h := ticket.Headers
	if h["LibraryId"] != "133" || h["VideoId"] != "guid-1" || h["AuthorizationExpire"] == "" {
		t.Errorf("headers = %v", h)
	}
	// sha256 hex de library + apiKey + expire + videoId: 64 chars hex.
	if len(h["AuthorizationSignature"]) != 64 {
		t.Errorf("firma = %q", h["AuthorizationSignature"])
	}
}
