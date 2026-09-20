package store

import (
	"errors"
	"fmt"
)

var (
	// ErrNotFound — запрашиваемая запись отсутствует в базе.
	ErrNotFound = errors.New("store: not found")
	// ErrVersionConflict — state_version в базе не совпал с base_version клиента.
	ErrVersionConflict = errors.New("store: state version conflict")
)

// UniqueViolationError — нарушение уникального ограничения (SQLSTATE 23505).
type UniqueViolationError struct {
	Constraint string
}

func (e *UniqueViolationError) Error() string {
	return fmt.Sprintf("store: unique violation on constraint %q", e.Constraint)
}
