// Tulabe push relay: a tiny standalone service owned by the mobile app.
// Registered devices subscribe with an FCM token; a broadcast (manual POST or
// the optional new-content poller) delivers notifications through Firebase
// Cloud Messaging. It lives entirely outside the web repo.
//
//   POST /api/push/subscribe   {"token": "...", "platform": "android"}   -> 200
//   POST /api/push/unsubscribe {"token": "..."}                          -> 200
//   POST /api/push/send        {"title": "...", "body": "...", "url": "..."} -> 200
//   GET  /api/push/health                                                    -> 200
//
// If RELAY_KEY is set, all mutation endpoints require header `X-Relay-Key`.
// If POLL_INTERVAL_MIN > 0 and TULABE_API_URL is set, the relay polls the
// public Tulabe lists and broadcasts "new on Tulabe" notifications itself.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

// ---- device token store (persisted JSON) ----

type tokenStore struct {
	mu     sync.Mutex
	file   string
	tokens map[string]string // token -> platform
}

func newTokenStore(file string) (*tokenStore, error) {
	s := &tokenStore{file: file, tokens: map[string]string{}}
	data, err := os.ReadFile(file)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			return nil, err
		}
		return s, nil
	}
	if err := json.Unmarshal(data, &s.tokens); err != nil {
		log.Printf("warn: %s unreadable (%v); starting empty", file, err)
	}
	return s, nil
}

func (s *tokenStore) add(token, platform string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if token == "" {
		return
	}
	s.tokens[token] = platform
	s.saveLocked()
}

func (s *tokenStore) remove(token string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.tokens[token]; ok {
		delete(s.tokens, token)
		s.saveLocked()
	}
}

func (s *tokenStore) snapshot() map[string]string {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make(map[string]string, len(s.tokens))
	for k, v := range s.tokens {
		out[k] = v
	}
	return out
}

func (s *tokenStore) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.tokens)
}

func (s *tokenStore) saveLocked() {
	data, err := json.MarshalIndent(s.tokens, "", "  ")
	if err != nil {
		return
	}
	tmp := s.file + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err == nil {
		_ = os.Rename(tmp, s.file)
	}
}

// ---- FCM sender ----

type fcm struct {
	cfg    config
	client *messaging.Client
	once   sync.Once
	err    error
}

func newFCM(cfg config) *fcm {
	return &fcm{cfg: cfg}
}

func (f *fcm) init() {
	opts := []option.ClientOption{}
	if f.cfg.fcmPath != "" {
		opts = append(opts, option.WithCredentialsFile(f.cfg.fcmPath))
	} else if f.cfg.fcmJSON != "" {
		opts = append(opts, option.WithCredentialsJSON([]byte(f.cfg.fcmJSON)))
	} else {
		f.err = errors.New("no Firebase credentials (FCM_SERVICE_ACCOUNT_PATH or FCM_SERVICE_ACCOUNT)")
		return
	}
	app, err := firebase.NewApp(context.Background(), nil, opts...)
	if err != nil {
		f.err = err
		return
	}
	f.client, f.err = app.Messaging(context.Background())
}

func (f *fcm) ready() bool {
	if f.client == nil {
		f.once.Do(f.init)
	}
	return f.err == nil && f.client != nil
}

// sendAll pushes to every stored token and prunes unregistered ones.
// Returns (sent, pruned, err). Missing credentials is an error; zero tokens is
// a no-op success.
func (f *fcm) sendAll(ctx context.Context, store *tokenStore, title, body, link string) (int, int, error) {
	if !f.ready() {
		return 0, 0, f.err
	}
	tokens := store.snapshot()
	if len(tokens) == 0 {
		return 0, 0, nil
	}

	msg := func(token string) *messaging.Message {
		m := &messaging.Message{
			Token: token,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
		}
		if link != "" {
			m.Data = map[string]string{"url": link}
		}
		return m
	}

	messages := make([]*messaging.Message, 0, len(tokens))
	order := make([]string, 0, len(tokens))
	for token := range tokens {
		order = append(order, token)
		messages = append(messages, msg(token))
	}

	// SendEach has a 500-message max per batch; chunk if ever needed.
	sent, pruned := 0, 0
	var badTokens []string
	for start := 0; start < len(messages); start += 500 {
		end := start + 500
		if end > len(messages) {
			end = len(messages)
		}
		br, err := f.client.SendEach(ctx, messages[start:end])
		if err != nil {
			return sent, pruned, err
		}
		for i, resp := range br.Responses {
			if resp.Error == nil {
				sent++
				continue
			}
			// Drop tokens FCM says are gone so we don't hammer them forever.
			if strings.Contains(resp.Error.Error(), "registration-token-not-registered") {
				badTokens = append(badTokens, order[start+i])
			}
		}
	}
	for _, t := range badTokens {
		pruned++
		store.remove(t)
	}
	return sent, pruned, nil
}

// ---- HTTP ----

func server(cfg config, store *tokenStore, f *fcm) *http.ServeMux {
	mux := http.NewServeMux()

	keyOK := func(r *http.Request) bool {
		return cfg.relayKey == "" || r.Header.Get("X-Relay-Key") == cfg.relayKey
	}

	readBody := func(r *http.Request, out any) error {
		defer r.Body.Close()
		data, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
		if err != nil {
			return err
		}
		return json.Unmarshal(data, out)
	}

	writeJSON := func(w http.ResponseWriter, code int, v any) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(code)
		_ = json.NewEncoder(w).Encode(v)
	}

	mux.HandleFunc("POST /api/push/subscribe", func(w http.ResponseWriter, r *http.Request) {
		if !keyOK(r) {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "bad or missing X-Relay-Key"})
			return
		}
		var payload struct {
			Token    string `json:"token"`
			Platform string `json:"platform"`
		}
		if err := readBody(r, &payload); err != nil || payload.Token == "" {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "token required"})
			return
		}
		if payload.Platform == "" {
			payload.Platform = "android"
		}
		store.add(payload.Token, payload.Platform)
		log.Printf("subscribe: %s device: %d total", payload.Platform, store.count())
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "total": store.count()})
	})

	mux.HandleFunc("POST /api/push/unsubscribe", func(w http.ResponseWriter, r *http.Request) {
		if !keyOK(r) {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "bad or missing X-Relay-Key"})
			return
		}
		var payload struct {
			Token string `json:"token"`
		}
		if err := readBody(r, &payload); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "bad request"})
			return
		}
		store.remove(payload.Token)
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "total": store.count()})
	})

	mux.HandleFunc("POST /api/push/send", func(w http.ResponseWriter, r *http.Request) {
		if !keyOK(r) {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "bad or missing X-Relay-Key"})
			return
		}
		var payload struct {
			Title string `json:"title"`
			Body  string `json:"body"`
			URL   string `json:"url"`
		}
		if err := readBody(r, &payload); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "bad request"})
			return
		}
		title := payload.Title
		if title == "" {
			title = "New on Tulabe"
		}
		sent, pruned, err := f.sendAll(r.Context(), store, title, payload.Body, payload.URL)
		if err != nil {
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "sent": sent, "pruned": pruned})
	})

	mux.HandleFunc("GET /api/push/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "devices": store.count(), "fcmReady": f.ready()})
	})

	return mux
}

// ---- new-content poller (optional) ----

// listNewest returns the newest created_at (RFC3339) across the movies and
// series "latest" lists, plus the title, id and kind of the newest item.
func listNewest(cfg config) (cursor, title, id, kind string, err error) {
	type item struct {
		createdAt string
		title     string
		id        string
		kind      string
	}
	var newest item
	lists := []struct {
		url  string
		key  string
		kind string
	}{
		{fmt.Sprintf("%s/movies?limit=1&latest=true", cfg.tulabeAPI), "movies", "movie"},
		{fmt.Sprintf("%s/series?limit=1&latest=true", cfg.tulabeAPI), "series", "series"},
	}
	for _, l := range lists {
		client := &http.Client{Timeout: 15 * time.Second}
		resp, err := client.Get(l.url)
		if err != nil {
			continue
		}
		var envelope struct {
			Data map[string][]map[string]any `json:"data"`
		}
		err = json.NewDecoder(resp.Body).Decode(&envelope)
		resp.Body.Close()
		if err != nil {
			continue
		}
		for _, raw := range envelope.Data[l.key] {
			createdAt, _ := raw["created_at"].(string)
			if createdAt == "" {
				continue
			}
			if newest.createdAt == "" || createdAt > newest.createdAt {
				newest = item{
					createdAt: createdAt,
					title:     str(raw, "title"),
					id:        str(raw, "id"),
					kind:      l.kind,
				}
			}
		}
	}
	if newest.createdAt == "" {
		return "", "", "", "", errors.New("no latest items found")
	}
	return newest.createdAt, newest.title, newest.id, newest.kind, nil
}

func str(m map[string]any, key string) string {
	if v, ok := m[key]; ok && v != nil {
		return fmt.Sprint(v)
	}
	return ""
}

func runPoller(ctx context.Context, cfg config, store *tokenStore, f *fcm) {
	loadCursor := func() string {
		data, err := os.ReadFile(cfg.lastCursorFile)
		if err != nil {
			return ""
		}
		return strings.TrimSpace(string(data))
	}
	saveCursor := func(c string) {
		_ = os.WriteFile(cfg.lastCursorFile, []byte(c), 0o600)
	}

	cursor := loadCursor()
	bootstrapped := cursor != ""
	ticker := time.NewTicker(time.Duration(cfg.pollMins) * time.Minute)
	defer ticker.Stop()

	log.Printf("poller: every %dm against %s (cursor %q)", cfg.pollMins, cfg.tulabeAPI, cursor)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			newCursor, name, id, kind, err := listNewest(cfg)
			if err != nil {
				log.Printf("poller: %v", err)
				continue
			}
			if !bootstrapped {
				// First run: remember where we are so we don't spam the backlog.
				bootstrapped = true
				cursor = newCursor
				saveCursor(cursor)
				log.Printf("poller: baseline set at %s", cursor)
				continue
			}
			if newCursor > cursor {
				log.Printf("poller: new content %q (%s)", name, newCursor)
				subject := name
				if subject == "" {
					subject = "New on Tulabe"
				}
				sent, pruned, err := f.sendAll(ctx, store, subject,
					"Now streaming on Tulabe.",
					fmt.Sprintf("%s/%s/%s", cfg.tulabeWebURL, kind, id))
				if err != nil {
					log.Printf("poller: send failed: %v", err)
					continue
				}
				cursor = newCursor
				saveCursor(cursor)
				log.Printf("poller: sent=%d pruned=%d", sent, pruned)
			}
		}
	}
}

func main() {
	cfg := loadConfig()

	store, err := newTokenStore(cfg.tokensFile)
	if err != nil {
		log.Fatalf("tokens store: %v", err)
	}
	f := newFCM(cfg)
	mux := server(cfg, store, f)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if cfg.pollMins > 0 && cfg.tulabeAPI != "" {
		go runPoller(ctx, cfg, store, f)
	} else {
		log.Printf("poller: disabled (set POLL_INTERVAL_MIN + TULABE_API_URL to enable)")
	}

	addr := ":" + cfg.port
	log.Printf("relay listening on %s (%d device(s))", addr, store.count())
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func loadConfig() config {
	return config{
		port:           getenv("RELAY_PORT", "8787"),
		relayKey:       os.Getenv("RELAY_KEY"),
		tokensFile:     getenv("TOKENS_FILE", "tokens.json"),
		fcmPath:        os.Getenv("FCM_SERVICE_ACCOUNT_PATH"),
		fcmJSON:        os.Getenv("FCM_SERVICE_ACCOUNT"),
		tulabeAPI:      strings.TrimRight(os.Getenv("TULABE_API_URL"), "/"),
		tulabeWebURL:   strings.TrimRight(os.Getenv("TULABE_WEB_URL"), "/"),
		pollMins:       getenvInt("POLL_INTERVAL_MIN", 0),
		lastCursorFile: getenv("LAST_CURSOR_FILE", "last_cursor.txt"),
	}
}

type config struct {
	port           string
	relayKey       string
	tokensFile     string
	fcmPath        string
	fcmJSON        string
	tulabeAPI      string
	tulabeWebURL   string
	pollMins       int
	lastCursorFile string
}