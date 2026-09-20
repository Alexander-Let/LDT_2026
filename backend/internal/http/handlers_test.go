package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"finni/internal/store"
)

func TestCreateProfileValidation(t *testing.T) {
	r := childRouter(&mockStore{})

	cases := []struct {
		name string
		body string
	}{
		{"не JSON", `not-json`},
		{"короткий device_token", `{"device_token":"short","display_name":"Финни"}`},
		{"пустой display_name", `{"device_token":"0123456789abcdef","display_name":"  "}`},
		{"слишком длинный display_name", `{"device_token":"0123456789abcdef","display_name":"` + strings.Repeat("а", 51) + `"}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			w := doRequest(r, http.MethodPost, "/v1/profiles", "", strings.NewReader(tc.body))
			if w.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400, body = %s", w.Code, w.Body.String())
			}
			if !strings.Contains(w.Body.String(), `"code":"invalid_request"`) {
				t.Errorf("body = %q, want error.code invalid_request", w.Body.String())
			}
		})
	}
}

func TestCreateProfileIdempotent(t *testing.T) {
	existing := testProfile()
	st := &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			return existing, nil
		},
		createProfileFn: func(ctx context.Context, hash, name, linkCode string) (store.Profile, error) {
			t.Fatal("CreateProfile не должен вызываться для существующего токена")
			return store.Profile{}, nil
		},
	}
	r := childRouter(st)

	body := `{"device_token":"0123456789abcdef","display_name":"Финни"}`
	w := doRequest(r, http.MethodPost, "/v1/profiles", "", strings.NewReader(body))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (идемпотентность)", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"link_code":"ABCD23"`) {
		t.Errorf("body = %q, want существующий профиль", w.Body.String())
	}
}

func TestCreateProfileCreated(t *testing.T) {
	var gotLinkCode string
	st := &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			return store.Profile{}, store.ErrNotFound
		},
		createProfileFn: func(ctx context.Context, hash, name, linkCode string) (store.Profile, error) {
			gotLinkCode = linkCode
			p := testProfile()
			p.LinkCode = linkCode
			return p, nil
		},
	}
	r := childRouter(st)

	body := `{"device_token":"0123456789abcdef","display_name":"Финни"}`
	w := doRequest(r, http.MethodPost, "/v1/profiles", "", strings.NewReader(body))

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201, body = %s", w.Code, w.Body.String())
	}
	if len(gotLinkCode) != linkCodeLength {
		t.Errorf("link_code = %q, ожидается %d символов", gotLinkCode, linkCodeLength)
	}
}

func TestCreateProfileRetriesOnLinkCodeCollision(t *testing.T) {
	attempts := 0
	st := &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			return store.Profile{}, store.ErrNotFound
		},
		createProfileFn: func(ctx context.Context, hash, name, linkCode string) (store.Profile, error) {
			attempts++
			if attempts < 3 {
				return store.Profile{}, &store.UniqueViolationError{Constraint: "profiles_link_code_key"}
			}
			return testProfile(), nil
		},
	}
	r := childRouter(st)

	body := `{"device_token":"0123456789abcdef","display_name":"Финни"}`
	w := doRequest(r, http.MethodPost, "/v1/profiles", "", strings.NewReader(body))

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201, body = %s", w.Code, w.Body.String())
	}
	if attempts != 3 {
		t.Errorf("attempts = %d, want 3 (две коллизии + успех)", attempts)
	}
}

func authedChildStore() *mockStore {
	return &mockStore{
		getProfileByDeviceTokenHashFn: func(ctx context.Context, hash string) (store.Profile, error) {
			return testProfile(), nil
		},
	}
}

const childAuthHeader = "Bearer valid-device-token"

func TestPutStateValidation(t *testing.T) {
	r := childRouter(authedChildStore())

	cases := []struct {
		name string
		body string
	}{
		{"state не объект", `{"state":[1,2,3],"base_version":3}`},
		{"state скаляр", `{"state":42,"base_version":3}`},
		{"нет base_version", `{"state":{"a":1}}`},
		{"отрицательный base_version", `{"state":{"a":1},"base_version":-1}`},
		{"пустой state", `{"base_version":3}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			w := doRequest(r, http.MethodPut, "/v1/profiles/me/state", childAuthHeader, strings.NewReader(tc.body))
			if w.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400, body = %s", w.Code, w.Body.String())
			}
		})
	}
}

func TestPutStateOK(t *testing.T) {
	st := authedChildStore()
	var gotState []byte
	var gotBase int
	st.updateProfileStateFn = func(ctx context.Context, id string, baseVersion int, state []byte) (store.Profile, error) {
		gotState, gotBase = state, baseVersion
		p := testProfile()
		p.State = state
		p.StateVersion = baseVersion + 1
		return p, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPut, "/v1/profiles/me/state", childAuthHeader,
		strings.NewReader(`{"state":{"balance":150},"base_version":3}`))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if gotBase != 3 {
		t.Errorf("baseVersion = %d, want 3", gotBase)
	}
	if !strings.Contains(string(gotState), `"balance":150`) {
		t.Errorf("state = %s, want переданное состояние", gotState)
	}
	if !strings.Contains(w.Body.String(), `"state_version":4`) {
		t.Errorf("body = %q, want state_version 4", w.Body.String())
	}
}

func TestPutStateVersionConflict(t *testing.T) {
	st := authedChildStore()
	st.updateProfileStateFn = func(ctx context.Context, id string, baseVersion int, state []byte) (store.Profile, error) {
		return testProfile(), store.ErrVersionConflict
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPut, "/v1/profiles/me/state", childAuthHeader,
		strings.NewReader(`{"state":{"balance":150},"base_version":1}`))

	if w.Code != http.StatusConflict {
		t.Fatalf("status = %d, want 409, body = %s", w.Code, w.Body.String())
	}
	var resp struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
		CurrentVersion int             `json:"current_version"`
		CurrentState   json.RawMessage `json:"current_state"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal: %v, body = %s", err, w.Body.String())
	}
	if resp.Error.Code != "version_conflict" {
		t.Errorf("error.code = %q, want version_conflict", resp.Error.Code)
	}
	if resp.CurrentVersion != testProfile().StateVersion {
		t.Errorf("current_version = %d, want %d", resp.CurrentVersion, testProfile().StateVersion)
	}
	if !strings.Contains(string(resp.CurrentState), `"balance":100`) {
		t.Errorf("current_state = %s, want актуальное состояние из store", resp.CurrentState)
	}
}

func TestGetMyState(t *testing.T) {
	r := childRouter(authedChildStore())
	w := doRequest(r, http.MethodGet, "/v1/profiles/me/state", childAuthHeader, nil)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}
	for _, field := range []string{`"state"`, `"state_version":3`, `"updated_at"`} {
		if !strings.Contains(w.Body.String(), field) {
			t.Errorf("body = %q, want поле %s", w.Body.String(), field)
		}
	}
}

func TestGetContentBundleNotFound(t *testing.T) {
	st := authedChildStore()
	st.latestContentBundleFn = func(ctx context.Context) (store.ContentBundle, error) {
		return store.ContentBundle{}, store.ErrNotFound
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet, "/v1/content/bundle", childAuthHeader, nil)
	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}

func TestGetContentBundle(t *testing.T) {
	st := authedChildStore()
	st.latestContentBundleFn = func(ctx context.Context) (store.ContentBundle, error) {
		return store.ContentBundle{
			Version:     1,
			Payload:     []byte(`{"schema":1,"tasks":[]}`),
			PublishedAt: time.Date(2026, 9, 20, 0, 0, 0, 0, time.UTC),
		}, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet, "/v1/content/bundle", childAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"version":1`) || !strings.Contains(w.Body.String(), `"schema":1`) {
		t.Errorf("body = %q, want version и payload", w.Body.String())
	}
}

func TestListMyBonuses(t *testing.T) {
	st := authedChildStore()
	st.listPendingBonusesFn = func(ctx context.Context, profileID string) ([]store.Bonus, error) {
		return []store.Bonus{
			{ID: 7, ProfileID: profileID, Amount: 50, Reason: "Молодец!", CreatedAt: time.Now()},
		}, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet, "/v1/profiles/me/bonuses", childAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"id":7`) || !strings.Contains(w.Body.String(), `"amount":50`) {
		t.Errorf("body = %q, want список бонусов", w.Body.String())
	}
}

func TestApplyMyBonusBadID(t *testing.T) {
	r := childRouter(authedChildStore())
	w := doRequest(r, http.MethodPost, "/v1/profiles/me/bonuses/abc/applied", childAuthHeader, nil)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
}

func TestApplyMyBonus(t *testing.T) {
	now := time.Now()
	st := authedChildStore()
	st.markBonusAppliedFn = func(ctx context.Context, profileID string, bonusID int64) (store.Bonus, error) {
		if bonusID != 7 {
			return store.Bonus{}, store.ErrNotFound
		}
		return store.Bonus{ID: 7, ProfileID: profileID, Amount: 50, AppliedAt: &now}, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/profiles/me/bonuses/7/applied", childAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"applied_at"`) {
		t.Errorf("body = %q, want applied_at", w.Body.String())
	}

	// Идемпотентный повтор — тоже 200 (мок возвращает уже применённый бонус).
	w = doRequest(r, http.MethodPost, "/v1/profiles/me/bonuses/7/applied", childAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("повтор: status = %d, want 200", w.Code)
	}

	w = doRequest(r, http.MethodPost, "/v1/profiles/me/bonuses/999/applied", childAuthHeader, nil)
	if w.Code != http.StatusNotFound {
		t.Fatalf("чужой/несуществующий бонус: status = %d, want 404", w.Code)
	}
}

func TestRequestParentOTPConsentRequired(t *testing.T) {
	r := childRouter(&mockStore{})
	w := doRequest(r, http.MethodPost, "/v1/parents/otp", "",
		strings.NewReader(`{"email":"parent@example.com","consent":false}`))
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
}

func TestRequestParentOTPDevCode(t *testing.T) {
	newMock := func(capturedHash *string) *mockStore {
		return &mockStore{
			getOrCreateParentFn: func(ctx context.Context, email string) (store.Parent, error) {
				return store.Parent{ID: "parent-id", Email: email}, nil
			},
			upsertParentOTPFn: func(ctx context.Context, email, codeHash string, expiresAt time.Time) error {
				*capturedHash = codeHash
				if time.Until(expiresAt) < 9*time.Minute {
					return fmt.Errorf("expires_at должен быть примерно через 10 минут")
				}
				return nil
			},
		}
	}
	body := `{"email":"parent@example.com","consent":true}`

	// dev: код возвращается в ответе, в store уходит его sha256-хэш.
	var devHash string
	r := NewRouter(newMock(&devHash), testLogger(), "dev")
	w := doRequest(r, http.MethodPost, "/v1/parents/otp", "", strings.NewReader(body))
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	var resp struct {
		DevCode string `json:"dev_code"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(resp.DevCode) != 6 {
		t.Fatalf("dev_code = %q, want 6 цифр", resp.DevCode)
	}
	if devHash != sha256Hex(resp.DevCode) {
		t.Error("в store должен сохраняться sha256-хэш кода, а не сам код")
	}

	// prod: dev_code отсутствует.
	var prodHash string
	r = NewRouter(newMock(&prodHash), testLogger(), "prod")
	w = doRequest(r, http.MethodPost, "/v1/parents/otp", "", strings.NewReader(body))
	if w.Code != http.StatusOK {
		t.Fatalf("prod: status = %d, want 200", w.Code)
	}
	if strings.Contains(w.Body.String(), "dev_code") {
		t.Errorf("prod: body = %q, dev_code не должен возвращаться", w.Body.String())
	}
}

func sessionMocks(otp store.ParentOTP) (*mockStore, *string) {
	sessionTokenHash := new(string)
	return &mockStore{
		getParentOTPFn: func(ctx context.Context, email string) (store.ParentOTP, error) {
			return otp, nil
		},
		getParentByEmailFn: func(ctx context.Context, email string) (store.Parent, error) {
			return store.Parent{ID: "parent-id", Email: email}, nil
		},
		createParentSessionFn: func(ctx context.Context, parentID, tokenHash string, expiresAt time.Time) error {
			*sessionTokenHash = tokenHash
			if time.Until(expiresAt) < 29*24*time.Hour {
				return fmt.Errorf("expires_at должен быть примерно через 30 дней")
			}
			return nil
		},
		deleteParentOTPFn: func(ctx context.Context, email string) error { return nil },
	}, sessionTokenHash
}

func TestCreateParentSessionWrongCode(t *testing.T) {
	st, _ := sessionMocks(store.ParentOTP{
		Email:     "parent@example.com",
		CodeHash:  sha256Hex("123456"),
		ExpiresAt: time.Now().Add(5 * time.Minute),
	})
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/parents/session", "",
		strings.NewReader(`{"email":"parent@example.com","code":"000000"}`))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestCreateParentSessionExpiredCode(t *testing.T) {
	st, _ := sessionMocks(store.ParentOTP{
		Email:     "parent@example.com",
		CodeHash:  sha256Hex("123456"),
		ExpiresAt: time.Now().Add(-time.Minute),
	})
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/parents/session", "",
		strings.NewReader(`{"email":"parent@example.com","code":"123456"}`))
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestCreateParentSessionOK(t *testing.T) {
	otpDeleted := false
	st, sessionTokenHash := sessionMocks(store.ParentOTP{
		Email:     "parent@example.com",
		CodeHash:  sha256Hex("123456"),
		ExpiresAt: time.Now().Add(5 * time.Minute),
	})
	st.deleteParentOTPFn = func(ctx context.Context, email string) error {
		otpDeleted = true
		return nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/parents/session", "",
		strings.NewReader(`{"email":"parent@example.com","code":"123456"}`))

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201, body = %s", w.Code, w.Body.String())
	}
	var resp struct {
		ParentToken string `json:"parent_token"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if len(resp.ParentToken) != 43 {
		t.Errorf("parent_token: len = %d, want 43", len(resp.ParentToken))
	}
	if *sessionTokenHash != sha256Hex(resp.ParentToken) {
		t.Error("в store должен сохраняться sha256-хэш токена сессии")
	}
	if !otpDeleted {
		t.Error("использованный OTP должен быть удалён")
	}
}

func parentTestStore() *mockStore {
	return &mockStore{
		getParentBySessionTokenHashFn: func(ctx context.Context, hash string) (store.Parent, error) {
			return store.Parent{ID: "parent-id", Email: "parent@example.com"}, nil
		},
	}
}

const parentAuthHeader = "Bearer valid-parent-token"

func TestCreateParentLink(t *testing.T) {
	st := parentTestStore()
	linked := false
	st.getProfileByLinkCodeFn = func(ctx context.Context, code string) (store.Profile, error) {
		if !strings.EqualFold(code, "ABCD23") {
			return store.Profile{}, store.ErrNotFound
		}
		return testProfile(), nil
	}
	st.linkParentProfileFn = func(ctx context.Context, parentID, profileID string) error {
		linked = true
		return nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/parents/links", parentAuthHeader,
		strings.NewReader(`{"link_code":"abcd23"}`))
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if !linked {
		t.Error("LinkParentProfile должен быть вызван")
	}
	if !strings.Contains(w.Body.String(), `"profile_id"`) {
		t.Errorf("body = %q, want profile_id", w.Body.String())
	}
}

func TestCreateParentLinkNotFound(t *testing.T) {
	st := parentTestStore()
	st.getProfileByLinkCodeFn = func(ctx context.Context, code string) (store.Profile, error) {
		return store.Profile{}, store.ErrNotFound
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost, "/v1/parents/links", parentAuthHeader,
		strings.NewReader(`{"link_code":"ZZZZ99"}`))
	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}

func TestCreateParentLinkValidation(t *testing.T) {
	r := childRouter(parentTestStore())
	w := doRequest(r, http.MethodPost, "/v1/parents/links", parentAuthHeader,
		strings.NewReader(`{"link_code":"x"}`))
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
}

func TestListChildren(t *testing.T) {
	st := parentTestStore()
	st.listLinkedChildrenFn = func(ctx context.Context, parentID string) ([]store.LinkedChild, error) {
		return []store.LinkedChild{{
			ProfileID:    "11111111-2222-3333-4444-555555555555",
			DisplayName:  "Финни",
			LinkedAt:     time.Now(),
			StateVersion: 3,
			UpdatedAt:    time.Now(),
		}}, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet, "/v1/parents/children", parentAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"linked_at"`) {
		t.Errorf("body = %q, want linked_at", w.Body.String())
	}
}

func TestChildSummaryNotLinked(t *testing.T) {
	st := parentTestStore()
	st.isParentLinkedFn = func(ctx context.Context, parentID, profileID string) (bool, error) {
		return false, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet,
		"/v1/parents/children/11111111-2222-3333-4444-555555555555/summary", parentAuthHeader, nil)
	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}

func TestChildSummaryBadUUID(t *testing.T) {
	r := childRouter(parentTestStore())
	w := doRequest(r, http.MethodGet, "/v1/parents/children/not-a-uuid/summary", parentAuthHeader, nil)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
}

func TestChildSummaryOK(t *testing.T) {
	st := parentTestStore()
	st.isParentLinkedFn = func(ctx context.Context, parentID, profileID string) (bool, error) {
		return true, nil
	}
	st.getProfileByIDFn = func(ctx context.Context, id string) (store.Profile, error) {
		return testProfile(), nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodGet,
		"/v1/parents/children/11111111-2222-3333-4444-555555555555/summary", parentAuthHeader, nil)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"balance":100`) {
		t.Errorf("body = %q, want state профиля", w.Body.String())
	}
}

func TestCreateChildBonusValidation(t *testing.T) {
	r := childRouter(parentTestStore())
	path := "/v1/parents/children/11111111-2222-3333-4444-555555555555/bonuses"

	for _, body := range []string{
		`{"amount":0,"reason":"x"}`,
		`{"amount":10001,"reason":"x"}`,
		`{"amount":-5,"reason":"x"}`,
		`{"amount":10,"reason":"` + strings.Repeat("о", 201) + `"}`,
	} {
		w := doRequest(r, http.MethodPost, path, parentAuthHeader, strings.NewReader(body))
		if w.Code != http.StatusBadRequest {
			t.Fatalf("body %s: status = %d, want 400", body, w.Code)
		}
	}
}

func TestCreateChildBonusOK(t *testing.T) {
	st := parentTestStore()
	st.isParentLinkedFn = func(ctx context.Context, parentID, profileID string) (bool, error) {
		return true, nil
	}
	st.getProfileByIDFn = func(ctx context.Context, id string) (store.Profile, error) {
		return testProfile(), nil
	}
	st.createBonusFn = func(ctx context.Context, profileID string, amount int, reason string) (store.Bonus, error) {
		return store.Bonus{ID: 42, ProfileID: profileID, Amount: amount, Reason: reason, CreatedAt: time.Now()}, nil
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost,
		"/v1/parents/children/11111111-2222-3333-4444-555555555555/bonuses", parentAuthHeader,
		strings.NewReader(`{"amount":100,"reason":"За отличную неделю"}`))

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201, body = %s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), `"bonus_id":42`) {
		t.Errorf("body = %q, want bonus_id", w.Body.String())
	}
}

func TestCreateChildBonusNotLinked(t *testing.T) {
	st := parentTestStore()
	st.isParentLinkedFn = func(ctx context.Context, parentID, profileID string) (bool, error) {
		return false, nil
	}
	st.createBonusFn = func(ctx context.Context, profileID string, amount int, reason string) (store.Bonus, error) {
		t.Fatal("CreateBonus не должен вызываться без привязки")
		return store.Bonus{}, errors.New("unreachable")
	}
	r := childRouter(st)

	w := doRequest(r, http.MethodPost,
		"/v1/parents/children/11111111-2222-3333-4444-555555555555/bonuses", parentAuthHeader,
		strings.NewReader(`{"amount":100,"reason":"x"}`))
	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}
