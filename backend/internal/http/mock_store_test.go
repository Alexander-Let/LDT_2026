package httpapi

import (
	"context"
	"fmt"
	"time"

	"finni/internal/store"
)

// mockStore реализует Store через функции-поля; ненастроенные методы паникуют,
// чтобы тест сразу показал, какого вызова не хватает.
type mockStore struct {
	pingFn                        func(ctx context.Context) error
	getProfileByIDFn              func(ctx context.Context, id string) (store.Profile, error)
	getProfileByDeviceTokenHashFn func(ctx context.Context, hash string) (store.Profile, error)
	getProfileByLinkCodeFn        func(ctx context.Context, code string) (store.Profile, error)
	createProfileFn               func(ctx context.Context, hash, name, linkCode string) (store.Profile, error)
	updateProfileStateFn          func(ctx context.Context, id string, baseVersion int, state []byte) (store.Profile, error)
	latestContentBundleFn         func(ctx context.Context) (store.ContentBundle, error)
	getParentByEmailFn            func(ctx context.Context, email string) (store.Parent, error)
	getOrCreateParentFn           func(ctx context.Context, email string) (store.Parent, error)
	upsertParentOTPFn             func(ctx context.Context, email, codeHash string, expiresAt time.Time) error
	getParentOTPFn                func(ctx context.Context, email string) (store.ParentOTP, error)
	deleteParentOTPFn             func(ctx context.Context, email string) error
	createParentSessionFn         func(ctx context.Context, parentID, tokenHash string, expiresAt time.Time) error
	getParentBySessionTokenHashFn func(ctx context.Context, tokenHash string) (store.Parent, error)
	linkParentProfileFn           func(ctx context.Context, parentID, profileID string) error
	isParentLinkedFn              func(ctx context.Context, parentID, profileID string) (bool, error)
	listLinkedChildrenFn          func(ctx context.Context, parentID string) ([]store.LinkedChild, error)
	createBonusFn                 func(ctx context.Context, profileID string, amount int, reason string) (store.Bonus, error)
	listPendingBonusesFn          func(ctx context.Context, profileID string) ([]store.Bonus, error)
	markBonusAppliedFn            func(ctx context.Context, profileID string, bonusID int64) (store.Bonus, error)
}

var _ Store = (*mockStore)(nil)

func unimplemented(name string) error {
	return fmt.Errorf("mockStore: метод %s не настроен", name)
}

func (m *mockStore) Ping(ctx context.Context) error {
	if m.pingFn != nil {
		return m.pingFn(ctx)
	}
	return unimplemented("Ping")
}

func (m *mockStore) GetProfileByID(ctx context.Context, id string) (store.Profile, error) {
	if m.getProfileByIDFn != nil {
		return m.getProfileByIDFn(ctx, id)
	}
	return store.Profile{}, unimplemented("GetProfileByID")
}

func (m *mockStore) GetProfileByDeviceTokenHash(ctx context.Context, hash string) (store.Profile, error) {
	if m.getProfileByDeviceTokenHashFn != nil {
		return m.getProfileByDeviceTokenHashFn(ctx, hash)
	}
	return store.Profile{}, unimplemented("GetProfileByDeviceTokenHash")
}

func (m *mockStore) GetProfileByLinkCode(ctx context.Context, code string) (store.Profile, error) {
	if m.getProfileByLinkCodeFn != nil {
		return m.getProfileByLinkCodeFn(ctx, code)
	}
	return store.Profile{}, unimplemented("GetProfileByLinkCode")
}

func (m *mockStore) CreateProfile(ctx context.Context, hash, name, linkCode string) (store.Profile, error) {
	if m.createProfileFn != nil {
		return m.createProfileFn(ctx, hash, name, linkCode)
	}
	return store.Profile{}, unimplemented("CreateProfile")
}

func (m *mockStore) UpdateProfileState(ctx context.Context, id string, baseVersion int, state []byte) (store.Profile, error) {
	if m.updateProfileStateFn != nil {
		return m.updateProfileStateFn(ctx, id, baseVersion, state)
	}
	return store.Profile{}, unimplemented("UpdateProfileState")
}

func (m *mockStore) LatestContentBundle(ctx context.Context) (store.ContentBundle, error) {
	if m.latestContentBundleFn != nil {
		return m.latestContentBundleFn(ctx)
	}
	return store.ContentBundle{}, unimplemented("LatestContentBundle")
}

func (m *mockStore) GetParentByEmail(ctx context.Context, email string) (store.Parent, error) {
	if m.getParentByEmailFn != nil {
		return m.getParentByEmailFn(ctx, email)
	}
	return store.Parent{}, unimplemented("GetParentByEmail")
}

func (m *mockStore) GetOrCreateParent(ctx context.Context, email string) (store.Parent, error) {
	if m.getOrCreateParentFn != nil {
		return m.getOrCreateParentFn(ctx, email)
	}
	return store.Parent{}, unimplemented("GetOrCreateParent")
}

func (m *mockStore) UpsertParentOTP(ctx context.Context, email, codeHash string, expiresAt time.Time) error {
	if m.upsertParentOTPFn != nil {
		return m.upsertParentOTPFn(ctx, email, codeHash, expiresAt)
	}
	return unimplemented("UpsertParentOTP")
}

func (m *mockStore) GetParentOTP(ctx context.Context, email string) (store.ParentOTP, error) {
	if m.getParentOTPFn != nil {
		return m.getParentOTPFn(ctx, email)
	}
	return store.ParentOTP{}, unimplemented("GetParentOTP")
}

func (m *mockStore) DeleteParentOTP(ctx context.Context, email string) error {
	if m.deleteParentOTPFn != nil {
		return m.deleteParentOTPFn(ctx, email)
	}
	return unimplemented("DeleteParentOTP")
}

func (m *mockStore) CreateParentSession(ctx context.Context, parentID, tokenHash string, expiresAt time.Time) error {
	if m.createParentSessionFn != nil {
		return m.createParentSessionFn(ctx, parentID, tokenHash, expiresAt)
	}
	return unimplemented("CreateParentSession")
}

func (m *mockStore) GetParentBySessionTokenHash(ctx context.Context, tokenHash string) (store.Parent, error) {
	if m.getParentBySessionTokenHashFn != nil {
		return m.getParentBySessionTokenHashFn(ctx, tokenHash)
	}
	return store.Parent{}, unimplemented("GetParentBySessionTokenHash")
}

func (m *mockStore) LinkParentProfile(ctx context.Context, parentID, profileID string) error {
	if m.linkParentProfileFn != nil {
		return m.linkParentProfileFn(ctx, parentID, profileID)
	}
	return unimplemented("LinkParentProfile")
}

func (m *mockStore) IsParentLinked(ctx context.Context, parentID, profileID string) (bool, error) {
	if m.isParentLinkedFn != nil {
		return m.isParentLinkedFn(ctx, parentID, profileID)
	}
	return false, unimplemented("IsParentLinked")
}

func (m *mockStore) ListLinkedChildren(ctx context.Context, parentID string) ([]store.LinkedChild, error) {
	if m.listLinkedChildrenFn != nil {
		return m.listLinkedChildrenFn(ctx, parentID)
	}
	return nil, unimplemented("ListLinkedChildren")
}

func (m *mockStore) CreateBonus(ctx context.Context, profileID string, amount int, reason string) (store.Bonus, error) {
	if m.createBonusFn != nil {
		return m.createBonusFn(ctx, profileID, amount, reason)
	}
	return store.Bonus{}, unimplemented("CreateBonus")
}

func (m *mockStore) ListPendingBonuses(ctx context.Context, profileID string) ([]store.Bonus, error) {
	if m.listPendingBonusesFn != nil {
		return m.listPendingBonusesFn(ctx, profileID)
	}
	return nil, unimplemented("ListPendingBonuses")
}

func (m *mockStore) MarkBonusApplied(ctx context.Context, profileID string, bonusID int64) (store.Bonus, error) {
	if m.markBonusAppliedFn != nil {
		return m.markBonusAppliedFn(ctx, profileID, bonusID)
	}
	return store.Bonus{}, unimplemented("MarkBonusApplied")
}
