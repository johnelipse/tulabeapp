// Tulabe push relay: a tiny standalone service owned by the mobile app.
// Registered devices subscribe with an FCM token; a broadcast (manual POST or
// the optional new-content poller) delivers notifications through Firebase
// Cloud Messaging. It lives entirely outside the web repo.
//
//   POST /api/push/subscribe   {"token": "...", "platform": "android"}   -> 200
//   POST /api/push/unsubscribe {"token": "..."}                          -> 200
//   POST /api/push/send        {"title": "...", "body": "...", "url": "..."} -> 200
//   GET  /POST /api/push/poll  (run one poll cycle now)                  -> 200
//   GET  /api/push/health                                                    -> 200
//
// If RELAY_KEY is set, mutation endpoints require one of: X-Relay-Key (the
// mobile app), X-API-Key, or Authorization: Bearer (cron-job.org headers).
// If POLL_INTERVAL_MIN > 0 and TULABE_API_URL is set, the relay polls the
// public Tulabe lists and broadcasts "new on Tulabe" notifications itself.
// The poller also runs synchronously on `GET /api/push/poll`, which lets an
// external cron (e.g. cron-job.org) trigger checks even when the platform
// freezes the in-process timer while the service is asleep.
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

func server(cfg config, store *tokenStore, f *fcm, p *poller) *http.ServeMux {
	mux := http.NewServeMux()

	// Accept the app's header (X-Relay-Key) plus the cron-job.org standard
	// headers (X-API-Key / Authorization: Bearer) so one shared secret works
	// for the mobile client and the external scheduler.
	keyOK := func(r *http.Request) bool {
		if cfg.relayKey == "" {
			return true
		}
		if r.Header.Get("X-Relay-Key") == cfg.relayKey {
			return true
		}
		if r.Header.Get("X-API-Key") == cfg.relayKey {
			return true
		}
		if strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ") == cfg.relayKey {
			return true
		}
		return false
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
		writeJSON(w, http.StatusOK, map[string]any{
			"ok":       true,
			"devices":  store.count(),
			"fcmReady": f.ready(),
			"poller": map[string]any{
				"enabled":      cfg.pollMins > 0 && cfg.tulabeAPI != "",
				"intervalMin":  cfg.pollMins,
				"tulabeAPI":    cfg.tulabeAPI,
				"lastCursor":   p.loadCursor(),
				"pollEndpoint": "/api/push/poll",
			},
		})
	})

	// One synchronous poll cycle on demand so external crons can drive checks
	// even when the platform has no always-on process. GET and POST both work
	// (cron-job.org typically sends POST); protected by RELAY_KEY when set.
	mux.HandleFunc("GET /api/push/poll", func(w http.ResponseWriter, r *http.Request) {
		handlePoll(w, r, cfg, p, keyOK, writeJSON)
	})
	mux.HandleFunc("POST /api/push/poll", func(w http.ResponseWriter, r *http.Request) {
		handlePoll(w, r, cfg, p, keyOK, writeJSON)
	})

	return mux
}

func handlePoll(w http.ResponseWriter, r *http.Request, cfg config, p *poller, keyOK func(*http.Request) bool, writeJSON func(http.ResponseWriter, int, any)) {
	if !keyOK(r) {
		writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "bad or missing X-Relay-Key"})
		return
	}
	if cfg.pollMins <= 0 || cfg.tulabeAPI == "" {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "poller not configured (set POLL_INTERVAL_MIN and TULABE_API_URL)"})
		return
	}
	sent, pruned, name, link, err := p.check()
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":       true,
		"notified": sent,
		"pruned":   pruned,
		"title":    name,
		"url":      link,
	})
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
			Data map[string]json.RawMessage `json:"data"`
		}
		err = json.NewDecoder(resp.Body).Decode(&envelope)
		resp.Body.Close()
		if err != nil {
			continue
		}
		raw, ok := envelope.Data[l.key]
		if !ok {
			continue
		}
		var items []map[string]any
		if err := json.Unmarshal(raw, &items); err != nil {
			continue
		}
		for _, raw := range items {
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

// poller runs the new-content check both on a timer and synchronously when an
// external cron pings /api/push/poll. A mutex keeps the two from double-firing.
type poller struct {
	cfg   config
	store *tokenStore
	f     *fcm
	mu    sync.Mutex
}

func newPoller(cfg config, store *tokenStore, f *fcm) *poller {
	return &poller{cfg: cfg, store: store, f: f}
}

func (p *poller) loadCursor() string {
	data, err := os.ReadFile(p.cfg.lastCursorFile)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func (p *poller) saveCursor(c string) {
	_ = os.WriteFile(p.cfg.lastCursorFile, []byte(c), 0o600)
}

// check performs one poll cycle and returns a concise result payload for the
// HTTP handler. Safe to call concurrently with the timer goroutine.
func (p *poller) check() (sent, pruned int, title, link string, err error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	cursor := p.loadCursor()
	newCursor, name, id, kind, err := listNewest(p.cfg)
	if err != nil {
		return 0, 0, "", "", err
	}

	if cursor == "" {
		// First run (fresh deploy or wiped volume): adopt the current newest
		// as the baseline so we never spam the backlog.
		p.saveCursor(newCursor)
		return 0, 0, name, "", nil
	}

	if newCursor <= cursor {
		return 0, 0, "", "", nil
	}

	subject := name
	if subject == "" {
		subject = "New on Tulabe"
	}
	link = fmt.Sprintf("%s/%s/%s", p.cfg.tulabeWebURL, kind, id)
	sent, pruned, err = p.f.sendAll(context.Background(), p.store, subject,
		"Now streaming on Tulabe.", link)
	if err != nil {
		return 0, 0, name, link, err
	}
	p.saveCursor(newCursor)
	return sent, pruned, name, link, nil
}

// loop is the in-process timer. It is best-effort: on platforms that freeze
// the process while idle, external crons trigger check() via the HTTP handler.
func (p *poller) loop(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(p.cfg.pollMins) * time.Minute)
	defer ticker.Stop()
	log.Printf("poller: every %dm against %s (cursor %q)", p.cfg.pollMins, p.cfg.tulabeAPI, p.loadCursor())
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if sent, pruned, name, _, err := p.check(); err != nil {
				log.Printf("poller: %v", err)
			} else if sent > 0 {
				log.Printf("poller: notified %d device(s) about %q (pruned %d)", sent, name, pruned)
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
	p := newPoller(cfg, store, f)
	mux := server(cfg, store, f, p)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if cfg.pollMins > 0 && cfg.tulabeAPI != "" {
		go p.loop(ctx)
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