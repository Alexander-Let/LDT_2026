package store

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	pool *pgxpool.Pool
}

func Connect(ctx context.Context, dsn string, logger *slog.Logger) (*Store, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	const attempts = 10
	for i := 1; i <= attempts; i++ {
		pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		err = pool.Ping(pingCtx)
		cancel()
		if err == nil {
			return &Store{pool: pool}, nil
		}
		logger.Warn("database ping failed, retrying", "attempt", i, "of", attempts, "error", err)
		select {
		case <-ctx.Done():
			pool.Close()
			return nil, fmt.Errorf("connect cancelled: %w", ctx.Err())
		case <-time.After(500 * time.Millisecond):
		}
	}
	pool.Close()
	return nil, fmt.Errorf("ping database after %d attempts: %w", attempts, err)
}

func (s *Store) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}

func (s *Store) Close() {
	s.pool.Close()
}
