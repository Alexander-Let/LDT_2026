package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"finni/internal/store"
)

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func TestSha256Hex(t *testing.T) {
	got := sha256Hex("device-token-123")
	if len(got) != 64 {
		t.Errorf("len(sha256Hex) = %d, want 64", len(got))
	}
	if got != sha256Hex("device-token-123") {
		t.Error("sha256Hex недетерминирован")
	}
	if got == sha256Hex("device-token-124") {
		t.Error("sha256Hex нечувствителен к входу")
	}
}

func TestNewLinkCode(t *testing.T) {
	seen := map[rune]bool{}
	for i := 0; i < 1000; i++ {
		code, err := newLinkCode()
		if err != nil {
			t.Fatalf("newLinkCode: %v", err)
		}
		if len(code) != linkCodeLength {
			t.Fatalf("len(code) = %d, want %d", len(code), linkCodeLength)
		}
		for _, r := range code {
			if !strings.ContainsRune(linkCodeAlphabet, r) {
				t.Errorf("code %q содержит символ %q вне алфавита", code, r)
			}
			if strings.ContainsRune("0O1I", r) {
				t.Errorf("code %q содержит неоднозначный символ %q", code, r)
			}
			seen[r] = true
		}
	}
	if len(seen) < 20 {
		t.Errorf("слишком мало различных символов за 1000 генераций: %d", len(seen))
	}
}

func TestNewOTPCode(t *testing.T) {
	for i := 0; i < 100; i++ {
		code, err := newOTPCode()
		if err != nil {
			t.Fatalf("newOTPCode: %v", err)
		}
		if len(code) != 6 {
			t.Fatalf("len(code) = %d, want 6", len(code))
		}
		for _, r := range code {
			if r < '0' || r > '9' {
				t.Errorf("code %q содержит не цифру %q", code, r)
			}
		}
	}
}

func TestNewSessionToken(t *testing.T) {
	token, err := newSessionToken()
	if err != nil {
		t.Fatalf("newSessionToken: %v", err)
	}
	if len(token) != 43 { // 32 байта в base64url без padding
		t.Errorf("len(token) = %d, want 43", len(token))
	}
	other, _ := newSessionToken()
	if token == other {
		t.Error("два токена совпали")
	}
}

func TestIsUUID(t *testing.T) {
	valid := "11111111-2222-3333-4444-555555555555"
	if !isUUID(valid) {
		t.Errorf("%q должен быть валидным uuid", valid)
	}
	if !isUUID(strings.ToUpper(valid)) {
		t.Error("uuid в верхнем регистре тоже валиден")
	}
	for _, s := range []string{"", "not-a-uuid", "11111111-2222-3333-4444-55555555555", "11111111x2222-3333-4444-555555555555"} {
		if isUUID(s) {
			t.Errorf("%q не должен быть uuid", s)
		}
	}
}

func TestValidEmail(t *testing.T) {
	if !validEmail("parent@example.com") {
		t.Error("parent@example.com должен быть валидным")
	}
	for _, s := range []string{"", "not-an-email", "a@b", "Name <a@b.c>", "a b@c.d"} {
		if validEmail(s) {
			t.Errorf("%q не должен быть валидным email", s)
		}
	}
}

func doRequest(r http.Handler, method, path, authHeader string, body io.Reader) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, body)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}
	r.ServeHTTP(w, req)
	return w
}

func testProfile() store.Profile {
	return store.Profile{
		ID:           "11111111-2222-3333-4444-555555555555",
		DisplayName:  "Финни",
		LinkCode:     "ABCD23",
		State:        []byte(`{"balance":100}`),
		StateVersion: 3,
		CreatedAt:    time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC),
		UpdatedAt:    time.Date(2026, 9, 10, 12, 0, 0, 0, time.UTC),
	}
}

func childRouter(st Store) http.Handler {
	return NewRouter(st, testLogger(), "test")
}

func TestChildAuthNoToken(t *testing.T) {
	r := childRouter(&mockStore{})
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "", nil)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"code":"unauthorized"`) {
		t.Errorf("body = %q, want error.code unauthorized", w.Body.String())
	}
}

func TestChildAuthMalformedHeader(t *testing.T) {
	r := childRouter(&mockStore{})
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "Token abc", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestChildAuthUnknownToken(t *testing.T) {
	st := &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			return store.Profile{}, store.ErrNotFound
		},
	}
	r := childRouter(st)
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "Bearer unknown-token", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestChildAuthHashesToken(t *testing.T) {
	var gotHash string
	st := &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			gotHash = hash
			return testProfile(), nil
		},
	}
	r := childRouter(st)
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "Bearer my-device-token", nil)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if gotHash != sha256Hex("my-device-token") {
		t.Error("middleware должен передавать в store sha256-хэш токена, а не сам токен")
	}
	if !strings.Contains(w.Body.String(), `"profile_id"`) {
		t.Errorf("body = %q, want profile_id", w.Body.String())
	}
}

func TestParentAuthNoToken(t *testing.T) {
	r := childRouter(&mockStore{})
	w := doRequest(r, http.MethodGet, "/v1/parents/children", "", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestParentAuthExpiredSession(t *testing.T) {
	st := &mockStore{
		getParentBySessionTokenHashFn: func(ctx context.Context, hash string) (store.Parent, error) {
			return store.Parent{}, store.ErrNotFound
		},
	}
	r := childRouter(st)
	w := doRequest(r, http.MethodGet, "/v1/parents/children", "Bearer stale-token", nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestErrorFormat(t *testing.T) {
	r := childRouter(&mockStore{})
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "", nil)

	body := w.Body.String()
	if !strings.Contains(body, `"error":{"code":"unauthorized","message":`) {
		t.Errorf("body = %q, want формат {\"error\": {\"code\", \"message\"}}", body)
	}
}
