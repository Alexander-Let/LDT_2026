package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type Bonus struct {
	ID        int64
	ProfileID string
	Amount    int
	Reason    string
	CreatedAt time.Time
	AppliedAt *time.Time
}

const bonusColumns = "id, profile_id::text, amount, reason, created_at, applied_at"

func scanBonus(row pgx.Row) (Bonus, error) {
	var b Bonus
	err := row.Scan(&b.ID, &b.ProfileID, &b.Amount, &b.Reason, &b.CreatedAt, &b.AppliedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Bonus{}, ErrNotFound
	}
	if err != nil {
		return Bonus{}, err
	}
	return b, nil
}

func (s *Store) CreateBonus(ctx context.Context, profileID string, amount int, reason string) (Bonus, error) {
	return scanBonus(s.pool.QueryRow(ctx,
		`INSERT INTO parent_bonuses (profile_id, amount, reason)
		 VALUES ($1, $2, $3)
		 RETURNING `+bonusColumns, profileID, amount, reason))
}

// ListPendingBonuses возвращает бонусы профиля, которые ещё не применены.
func (s *Store) ListPendingBonuses(ctx context.Context, profileID string) ([]Bonus, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT `+bonusColumns+`
		 FROM parent_bonuses
		 WHERE profile_id = $1 AND applied_at IS NULL
		 ORDER BY created_at, id`, profileID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	bonuses := []Bonus{}
	for rows.Next() {
		var b Bonus
		if err := rows.Scan(&b.ID, &b.ProfileID, &b.Amount, &b.Reason, &b.CreatedAt, &b.AppliedAt); err != nil {
			return nil, err
		}
		bonuses = append(bonuses, b)
	}
	return bonuses, rows.Err()
}

// MarkBonusApplied выставляет applied_at бонусу, принадлежащему профилю.
// Повторный вызов идемпотентен: уже применённый бонус возвращается без ошибки.
// Бонус другого профиля или несуществующий — ErrNotFound.
func (s *Store) MarkBonusApplied(ctx context.Context, profileID string, bonusID int64) (Bonus, error) {
	b, err := scanBonus(s.pool.QueryRow(ctx,
		`UPDATE parent_bonuses
		 SET applied_at = now()
		 WHERE id = $1 AND profile_id = $2 AND applied_at IS NULL
		 RETURNING `+bonusColumns, bonusID, profileID))
	if err == nil {
		return b, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return Bonus{}, err
	}
	// Либо бонус уже применён (идемпотентный повтор), либо не существует.
	return scanBonus(s.pool.QueryRow(ctx,
		`SELECT `+bonusColumns+` FROM parent_bonuses WHERE id = $1 AND profile_id = $2`,
		bonusID, profileID))
}
