package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Parent struct {
	ID        string
	Email     string
	ConsentAt time.Time
	CreatedAt time.Time
}

type ParentOTP struct {
	Email     string
	CodeHash  string
	ExpiresAt time.Time
}

type LinkedChild struct {
	ProfileID    string
	DisplayName  string
	LinkedAt     time.Time
	StateVersion int
	UpdatedAt    time.Time
}

func scanParent(row pgx.Row) (Parent, error) {
	var p Parent
	err := row.Scan(&p.ID, &p.Email, &p.ConsentAt, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Parent{}, ErrNotFound
	}
	if err != nil {
		return Parent{}, err
	}
	return p, nil
}

func (s *Store) GetParentByEmail(ctx context.Context, email string) (Parent, error) {
	return scanParent(s.pool.QueryRow(ctx,
		`SELECT id::text, email::text, consent_at, created_at FROM parents WHERE email = $1`, email))
}

// GetOrCreateParent создаёт родителя с фиксацией согласия (consent_at = now())
// при первом обращении либо возвращает существующего.
func (s *Store) GetOrCreateParent(ctx context.Context, email string) (Parent, error) {
	p, err := scanParent(s.pool.QueryRow(ctx,
		`INSERT INTO parents (email, consent_at)
		 VALUES ($1, now())
		 ON CONFLICT (email) DO NOTHING
		 RETURNING id::text, email::text, consent_at, created_at`, email))
	if errors.Is(err, ErrNotFound) {
		return s.GetParentByEmail(ctx, email)
	}
	return p, err
}

// UpsertParentOTP сохраняет хэш одноразового кода для email (один активный
// код на email, повторная отправка перезаписывает).
func (s *Store) UpsertParentOTP(ctx context.Context, email, codeHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO parent_otp (email, code_hash, expires_at)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (email) DO UPDATE
		 SET code_hash = EXCLUDED.code_hash, expires_at = EXCLUDED.expires_at`,
		email, codeHash, expiresAt)
	return err
}

func (s *Store) GetParentOTP(ctx context.Context, email string) (ParentOTP, error) {
	var o ParentOTP
	err := s.pool.QueryRow(ctx,
		`SELECT email::text, code_hash, expires_at FROM parent_otp WHERE email = $1`, email).
		Scan(&o.Email, &o.CodeHash, &o.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ParentOTP{}, ErrNotFound
	}
	if err != nil {
		return ParentOTP{}, err
	}
	return o, nil
}

func (s *Store) DeleteParentOTP(ctx context.Context, email string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM parent_otp WHERE email = $1`, email)
	return err
}

func (s *Store) CreateParentSession(ctx context.Context, parentID, tokenHash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO parent_sessions (token_hash, parent_id, expires_at) VALUES ($1, $2, $3)`,
		tokenHash, parentID, expiresAt)
	return err
}

// GetParentBySessionTokenHash возвращает родителя по неистёкшей сессии.
func (s *Store) GetParentBySessionTokenHash(ctx context.Context, tokenHash string) (Parent, error) {
	return scanParent(s.pool.QueryRow(ctx,
		`SELECT p.id::text, p.email::text, p.consent_at, p.created_at
		 FROM parent_sessions s
		 JOIN parents p ON p.id = s.parent_id
		 WHERE s.token_hash = $1 AND s.expires_at > now()`, tokenHash))
}

// LinkParentProfile привязывает профиль ребёнка к родителю (идемпотентно).
func (s *Store) LinkParentProfile(ctx context.Context, parentID, profileID string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO parent_profile_links (parent_id, profile_id)
		 VALUES ($1, $2)
		 ON CONFLICT DO NOTHING`, parentID, profileID)
	return err
}

func (s *Store) IsParentLinked(ctx context.Context, parentID, profileID string) (bool, error) {
	var linked bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS (
			SELECT 1 FROM parent_profile_links WHERE parent_id = $1 AND profile_id = $2
		)`, parentID, profileID).Scan(&linked)
	return linked, err
}

func (s *Store) ListLinkedChildren(ctx context.Context, parentID string) ([]LinkedChild, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT p.id::text, p.display_name, l.created_at, p.state_version, p.updated_at
		 FROM parent_profile_links l
		 JOIN profiles p ON p.id = l.profile_id
		 WHERE l.parent_id = $1
		 ORDER BY l.created_at, p.id`, parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	children := []LinkedChild{}
	for rows.Next() {
		var ch LinkedChild
		if err := rows.Scan(&ch.ProfileID, &ch.DisplayName, &ch.LinkedAt, &ch.StateVersion, &ch.UpdatedAt); err != nil {
			return nil, err
		}
		children = append(children, ch)
	}
	return children, rows.Err()
}
