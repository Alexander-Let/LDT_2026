package store

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"testing"
	"time"
)

// Интеграционный тест: запускается только при заданном DATABASE_URL
// (например, из docker compose). Без базы — пропускается.
func TestStoreIntegration(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if testing.Short() || dsn == "" {
		t.Skip("DATABASE_URL не задан — интеграционный тест пропущен")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	s, err := Connect(ctx, dsn, nil)
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	defer s.Close()

	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		t.Fatal(err)
	}
	tokenHash := hex.EncodeToString(buf)

	// Профиль: создание и чтение по хэшу токена.
	p, err := s.CreateProfile(ctx, tokenHash, "Тест", "TST"+hex.EncodeToString(buf[:2]))
	if err != nil {
		t.Fatalf("CreateProfile: %v", err)
	}
	defer func() {
		if _, err := s.pool.Exec(ctx, `DELETE FROM profiles WHERE id = $1`, p.ID); err != nil {
			t.Logf("cleanup: %v", err)
		}
	}()

	got, err := s.GetProfileByDeviceTokenHash(ctx, tokenHash)
	if err != nil {
		t.Fatalf("GetProfileByDeviceTokenHash: %v", err)
	}
	if got.ID != p.ID {
		t.Errorf("ID = %q, want %q", got.ID, p.ID)
	}

	// Оптимистичная блокировка: верная версия → ок, устаревшая → конфликт.
	updated, err := s.UpdateProfileState(ctx, p.ID, 0, []byte(`{"balance":10}`))
	if err != nil {
		t.Fatalf("UpdateProfileState: %v", err)
	}
	if updated.StateVersion != 1 {
		t.Errorf("StateVersion = %d, want 1", updated.StateVersion)
	}
	current, err := s.UpdateProfileState(ctx, p.ID, 0, []byte(`{"balance":20}`))
	if !errors.Is(err, ErrVersionConflict) {
		t.Fatalf("err = %v, want ErrVersionConflict", err)
	}
	if current.StateVersion != 1 {
		t.Errorf("current.StateVersion = %d, want 1", current.StateVersion)
	}

	// Контент: сид версии 1 накатывается миграцией 00003.
	bundle, err := s.LatestContentBundle(ctx)
	if err != nil {
		t.Fatalf("LatestContentBundle: %v", err)
	}
	if bundle.Version < 1 {
		t.Errorf("bundle.Version = %d, want >= 1", bundle.Version)
	}
}
