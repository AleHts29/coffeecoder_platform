// Package enrollment administra el acceso de los alumnos: alta manual y
// revocación desde admin. El acceso en sí se resuelve por las queries de
// access.sql (scope polimórfico), este módulo no las duplica.
package enrollment

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrUserNotFound       = errors.New("ese alumno no existe")
	ErrEnrollmentNotFound = errors.New("ese enrollment no existe")
	ErrInvalidScope       = errors.New("el scope debe ser course o career")
	ErrProductNotFound    = errors.New("ese producto no existe")
)

type Service struct {
	q *store.Queries
}

func NewService(q *store.Queries) *Service {
	return &Service{q: q}
}

func (s *Service) ListStudents(ctx context.Context, q string, limit, offset int32) ([]store.AdminListUsersRow, error) {
	return s.q.AdminListUsers(ctx, store.AdminListUsersParams{Q: q, Limit: limit, Offset: offset})
}

func (s *Service) GetStudent(ctx context.Context, id uuid.UUID) (store.User, []store.AdminListUserEnrollmentsRow, error) {
	u, err := s.q.GetUserByID(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.User{}, nil, ErrUserNotFound
	} else if err != nil {
		return store.User{}, nil, err
	}
	rows, err := s.q.AdminListUserEnrollments(ctx, id)
	return u, rows, err
}

// Enroll da acceso manual (sin orden). Si existía revocado, lo reactiva.
func (s *Service) Enroll(ctx context.Context, userID uuid.UUID, scope string, scopeID uuid.UUID) (store.Enrollment, error) {
	if _, err := s.q.GetUserByID(ctx, userID); errors.Is(err, pgx.ErrNoRows) {
		return store.Enrollment{}, ErrUserNotFound
	} else if err != nil {
		return store.Enrollment{}, err
	}
	switch scope {
	case "course":
		if _, err := s.q.GetCourse(ctx, scopeID); err != nil {
			return store.Enrollment{}, notFoundOr(err)
		}
	case "career":
		if _, err := s.q.GetCareer(ctx, scopeID); err != nil {
			return store.Enrollment{}, notFoundOr(err)
		}
	default:
		return store.Enrollment{}, ErrInvalidScope
	}
	return s.q.CreateEnrollment(ctx, store.CreateEnrollmentParams{UserID: userID, Scope: scope, ScopeID: scopeID})
}

func (s *Service) Revoke(ctx context.Context, id uuid.UUID) (store.Enrollment, error) {
	e, err := s.q.RevokeEnrollment(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.Enrollment{}, ErrEnrollmentNotFound
	}
	return e, err
}

func notFoundOr(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrProductNotFound
	}
	return err
}
