package httpapi

import (
	"context"
	"net/http"
	"strings"
	"testing"

	"finni/internal/store"
)

const newDeviceToken = "new-device-token-0123456789"

// attachRequest — валидное тело POST /v1/profiles/attach.
func attachRequest() *strings.Reader {
	return strings.NewReader(`{"device_token":"` + newDeviceToken + `","link_code":"abcd23"}`)
}

func TestAttachDeviceOK(t *testing.T) {
	var gotCode, gotHash string
	st := &mockStore{
		attachDeviceFn: func(ctx context.Context, linkCode, deviceTokenHash string) (store.Profile, error) {
			gotCode, gotHash = linkCode, deviceTokenHash
			return testProfile(), nil
		},
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/profiles/attach", "", attachRequest())

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if gotCode != "abcd23" {
		t.Errorf("link_code в store = %q, want %q (trim, без upper — регистр нормализует SQL)", gotCode, "abcd23")
	}
	if gotHash != sha256Hex(newDeviceToken) {
		t.Error("в store должен уходить sha256-хэш токена, а не сам токен")
	}
	for _, field := range []string{`"profile_id"`, `"display_name":"Финни"`, `"link_code":"ABCD23"`, `"has_state":true`} {
		if !strings.Contains(w.Body.String(), field) {
			t.Errorf("body = %q, want поле %s", w.Body.String(), field)
		}
	}
}

func TestAttachDeviceHasStateFalse(t *testing.T) {
	st := &mockStore{
		attachDeviceFn: func(ctx context.Context, linkCode, deviceTokenHash string) (store.Profile, error) {
			p := testProfile()
			p.State = []byte(`{}`) // jsonb DEFAULT '{}' — состояние ещё не сохранялось
			p.StateVersion = 0
			return p, nil
		},
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/profiles/attach", "", attachRequest())

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"has_state":false`) {
		t.Errorf("body = %q, want has_state false", w.Body.String())
	}
}

func TestAttachDeviceNotFound(t *testing.T) {
	st := &mockStore{
		attachDeviceFn: func(ctx context.Context, linkCode, deviceTokenHash string) (store.Profile, error) {
			return store.Profile{}, store.ErrNotFound
		},
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/profiles/attach", "", attachRequest())

	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"code":"not_found"`) {
		t.Errorf("body = %q, want error.code not_found", w.Body.String())
	}
}

func TestAttachDeviceValidation(t *testing.T) {
	r := childRouter(&mockStore{})

	cases := []struct {
		name string
		body string
	}{
		{"не JSON", `not-json`},
		{"короткий device_token", `{"device_token":"short","link_code":"ABCD23"}`},
		{"нет device_token", `{"link_code":"ABCD23"}`},
		{"короткий link_code", `{"device_token":"0123456789abcdef","link_code":"ABC"}`},
		{"длинный link_code", `{"device_token":"0123456789abcdef","link_code":"ABCD234"}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			w := doRequest(r, http.MethodPost, "/v1/profiles/attach", "", strings.NewReader(tc.body))
			if w.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400, body = %s", w.Code, w.Body.String())
			}
			if !strings.Contains(w.Body.String(), `"code":"invalid_request"`) {
				t.Errorf("body = %q, want error.code invalid_request", w.Body.String())
			}
		})
	}
}

func TestAttachDeviceIdempotent(t *testing.T) {
	calls := 0
	st := &mockStore{
		attachDeviceFn: func(ctx context.Context, linkCode, deviceTokenHash string) (store.Profile, error) {
			calls++
			return testProfile(), nil
		},
	}
	r := childRouter(st)

	// Повторная привязка тем же токеном — тоже 200 (ON CONFLICT DO NOTHING в store).
	for i := 0; i < 2; i++ {
		w := doRequest(r, http.MethodPost, "/v1/profiles/attach", "", attachRequest())
		if w.Code != http.StatusOK {
			t.Fatalf("попытка %d: status = %d, want 200, body = %s", i+1, w.Code, w.Body.String())
		}
	}
	if calls != 2 {
		t.Errorf("AttachDevice вызван %d раз, want 2", calls)
	}
}

func TestAttachDeviceThenGetMyProfile(t *testing.T) {
	attached := false
	st := &mockStore{
		attachDeviceFn: func(ctx context.Context, linkCode, deviceTokenHash string) (store.Profile, error) {
			if deviceTokenHash == sha256Hex(newDeviceToken) {
				attached = true
			}
			return testProfile(), nil
		},
		// Auth: хэш привязанного токена находит профиль (в БД — через profile_devices).
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			if attached && hash == sha256Hex(newDeviceToken) {
				return testProfile(), nil
			}
			return store.Profile{}, store.ErrNotFound
		},
	}
	r := childRouter(st)

	// До привязки новый токен не аутентифицируется.
	w := doRequest(r, http.MethodGet, "/v1/profiles/me", "Bearer "+newDeviceToken, nil)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("до attach: status = %d, want 401", w.Code)
	}

	w = doRequest(r, http.MethodPost, "/v1/profiles/attach", "", attachRequest())
	if w.Code != http.StatusOK {
		t.Fatalf("attach: status = %d, want 200, body = %s", w.Code, w.Body.String())
	}

	// После привязки новый токен даёт доступ к профилю.
	w = doRequest(r, http.MethodGet, "/v1/profiles/me", "Bearer "+newDeviceToken, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("после attach: status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"profile_id":"11111111-2222-3333-4444-555555555555"`) {
		t.Errorf("body = %q, want профиль, к которому привязались", w.Body.String())
	}
}
