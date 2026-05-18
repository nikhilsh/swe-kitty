package ws

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCapabilitiesEndpoint(t *testing.T) {
	srv, tok := newTestServer(t)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/api/capabilities?token="+url.QueryEscape(tok), nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET capabilities: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["name"] != "swe-kitty-harness" {
		t.Fatalf("unexpected name: %v", body["name"])
	}
	assistants, _ := body["assistants"].([]any)
	if len(assistants) < 1 {
		t.Fatalf("expected assistants, got %v", body["assistants"])
	}
}

func TestSessionStartEndpoint(t *testing.T) {
	srv, tok := newTestServer(t)
	body := `{"assistant":"claude"}`
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/api/session/start?token="+url.QueryEscape(tok), strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST session start: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	var out struct {
		SessionID string `json:"session_id"`
		WSPath    string `json:"ws_path"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if out.SessionID == "" || !strings.HasPrefix(out.WSPath, "/ws/") {
		t.Fatalf("unexpected payload: %+v", out)
	}
}

func TestFSListMetadataAndPagination(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{"beta", "alpha", ".hidden"} {
		if err := os.Mkdir(filepath.Join(root, name), 0o755); err != nil {
			t.Fatalf("mkdir %s: %v", name, err)
		}
	}

	srv, tok := newTestServer(t)
	rawURL := srv.URL + "/api/fs/list?token=" + url.QueryEscape(tok) +
		"&path=" + url.QueryEscape(root) + "&limit=1&offset=0"
	resp, err := http.Get(rawURL)
	if err != nil {
		t.Fatalf("GET fs list: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	var out struct {
		Count   int  `json:"count"`
		Total   int  `json:"total"`
		HasMore bool `json:"has_more"`
		Entries []struct {
			Name    string `json:"name"`
			Hidden  bool   `json:"hidden"`
			ModTime string `json:"mod_time"`
		} `json:"entries"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if out.Count != 1 || out.Total != 2 || !out.HasMore {
		t.Fatalf("unexpected pagination %+v", out)
	}
	if len(out.Entries) != 1 || out.Entries[0].Hidden || out.Entries[0].ModTime == "" {
		t.Fatalf("unexpected entry %+v", out.Entries)
	}
}
