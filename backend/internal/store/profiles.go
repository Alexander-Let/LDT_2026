package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type Profile struct {
	ID           string
	DisplayName  string
	LinkCode     string
	State        []byte
	StateVersion int
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

const profileColumns = "id::text, display_name, COALESCE(link_code, ''), state, state_version, created_at, updated_at"

func scanProfile(row pgx.Row) (Profile, error) {
	var p Profile
	err := row.Scan(&p.ID, &p.DisplayName, &p.LinkCode, &p.State, &p.StateVersion, &p.CreatedAt, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, err
	}
	return p, nil
}

func (s *Store) GetProfileByID(ctx context.Context, id string) (Profile, error) {
	return scanProfile(s.pool.QueryRow(ctx,
		`SELECT `+profileColumns+` FROM profiles WHERE id = $1`, id))
}

// GetProfileByDeviceTokenHash находит профиль по хэшу токена устройства.
// Токен валиден, если он основной (profiles.device_token_hash) или привязан
// к профилю через profile_devices (восстановление на другом устройстве).
func (s *Store) GetProfileByDeviceTokenHash(ctx context.Context, hash string) (Profile, error) {
	return scanProfile(s.pool.QueryRow(ctx,
		`SELECT `+profileColumns+` FROM profiles p
		 WHERE p.device_token_hash = $1
		    OR EXISTS (SELECT 1 FROM profile_devices d
		               WHERE d.profile_id = p.id AND d.device_token_hash = $1)`, hash))
}

func (s *Store) GetProfileByLinkCode(ctx context.Context, code string) (Profile, error) {
	return scanProfile(s.pool.QueryRow(ctx,
		`SELECT `+profileColumns+` FROM profiles WHERE upper(link_code) = upper($1)`, code))
}

// AttachDevice привязывает device_token_hash к профилю с кодом linkCode
// (восстановление прогресса на другом устройстве). Код сравнивается без
// учёта регистра. Повторная привязка того же токена идемпотентна
// (ON CONFLICT DO NOTHING). Если профиль с таким кодом не найден — ErrNotFound.
func (s *Store) AttachDevice(ctx context.Context, linkCode, deviceTokenHash string) (Profile, error) {
	p, err := s.GetProfileByLinkCode(ctx, linkCode)
	if err != nil {
		return Profile{}, err
	}
	if _, err := s.pool.Exec(ctx,
		`INSERT INTO profile_devices (profile_id, device_token_hash)
		 VALUES ($1, $2)
		 ON CONFLICT (device_token_hash) DO NOTHING`, p.ID, deviceTokenHash); err != nil {
		return Profile{}, err
	}
	return p, nil
}

// CreateProfile вставляет новый профиль. При конфликте уникальности
// (device_token_hash или link_code) возвращает *UniqueViolationError.
func (s *Store) CreateProfile(ctx context.Context, deviceTokenHash, displayName, linkCode string) (Profile, error) {
	p, err := scanProfile(s.pool.QueryRow(ctx,
		`INSERT INTO profiles (device_token_hash, display_name, link_code)
		 VALUES ($1, $2, $3)
		 RETURNING `+profileColumns, deviceTokenHash, displayName, linkCode))
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return Profile{}, &UniqueViolationError{Constraint: pgErr.ConstraintName}
		}
		return Profile{}, err
	}
	return p, nil
}

// UpdateProfileState сохраняет state с оптимистичной блокировкой: обновление
// происходит, только если state_version в базе равен baseVersion. При
// расхождении версий возвращает актуальный профиль и ErrVersionConflict.
func (s *Store) UpdateProfileState(ctx context.Context, id string, baseVersion int, state []byte) (Profile, error) {
	var version int
	var updatedAt time.Time
	err := s.pool.QueryRow(ctx,
		`UPDATE profiles
		 SET state = $2, state_version = state_version + 1, updated_at = now()
		 WHERE id = $1 AND state_version = $3
		 RETURNING state_version, updated_at`, id, state, baseVersion).Scan(&version, &updatedAt)
	if err == nil {
		return Profile{ID: id, State: state, StateVersion: version, UpdatedAt: updatedAt}, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, err
	}
	current, getErr := s.GetProfileByID(ctx, id)
	if getErr != nil {
		return Profile{}, getErr
	}
	return current, ErrVersionConflict
}
