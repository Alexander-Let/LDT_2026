package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

type ContentBundle struct {
	Version     int
	Payload     []byte
	PublishedAt time.Time
}

// LatestContentBundle возвращает бандл с максимальной версией.
// Если бандлов нет — ErrNotFound.
func (s *Store) LatestContentBundle(ctx context.Context) (ContentBundle, error) {
	var b ContentBundle
	err := s.pool.QueryRow(ctx,
		`SELECT version, payload, published_at
		 FROM content_bundles
		 ORDER BY version DESC
		 LIMIT 1`).Scan(&b.Version, &b.Payload, &b.PublishedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ContentBundle{}, ErrNotFound
	}
	if err != nil {
		return ContentBundle{}, err
	}
	return b, nil
}
