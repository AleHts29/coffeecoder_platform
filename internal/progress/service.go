// Package progress registra el avance del alumno: heartbeats del player
// sobre la tabla caliente lesson_progress, completado (automático al
// 90 % o manual), el agregado materializado course_progress y la
// actividad diaria para racha y horas. Las lecturas del dashboard nunca
// agregan sobre lesson_progress.
package progress

import (
	"context"
	"errors"
	"log/slog"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrLessonNotFound = errors.New("esa lección no existe")
	ErrCourseNotFound = errors.New("ese curso no existe")
	ErrNoAccess       = errors.New("necesitás comprar el curso para registrar progreso")
)

const (
	// CompletionThreshold: fracción de la duración a partir de la cual
	// una lección se da por vista.
	CompletionThreshold = 0.9
	// maxDeltaPerHeartbeat acota lo que un heartbeat suma a las horas de
	// estudio: un seek hacia adelante no regala tiempo.
	maxDeltaPerHeartbeat = 30
	defaultTZ            = "America/Argentina/Buenos_Aires"
	activityWindowDays   = 60
)

type Service struct {
	q      *store.Queries
	logger *slog.Logger
}

func NewService(q *store.Queries, logger *slog.Logger) *Service {
	return &Service{q: q, logger: logger}
}

type HeartbeatResult struct {
	Seconds   int32
	Completed bool
}

// Heartbeat persiste la posición (GREATEST en la query: un seek atrás
// no pisa el máximo), suma actividad del día y completa la lección si
// cruzó el umbral. Es el camino caliente: una lectura por PK + upserts.
func (s *Service) Heartbeat(ctx context.Context, userID, lessonID uuid.UUID, seconds int32, tz string) (HeartbeatResult, error) {
	lesson, err := s.accessibleLesson(ctx, userID, lessonID)
	if err != nil {
		return HeartbeatResult{}, err
	}
	if seconds < 0 {
		seconds = 0
	}
	if lesson.DurationS > 0 && seconds > lesson.DurationS {
		seconds = lesson.DurationS
	}

	prev, err := s.q.GetLessonProgress(ctx, store.GetLessonProgressParams{UserID: userID, LessonID: lessonID})
	started := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !started {
		return HeartbeatResult{}, err
	}

	if err := s.q.UpsertHeartbeat(ctx, store.UpsertHeartbeatParams{UserID: userID, LessonID: lessonID, Seconds: seconds}); err != nil {
		return HeartbeatResult{}, err
	}
	if started {
		// Primera vez en esta lección: el agregado del curso pasa a
		// "en curso" (last_lesson_id). Una escritura por lección, no por heartbeat.
		if err := s.q.RefreshCourseProgress(ctx, store.RefreshCourseProgressParams{UserID: userID, CourseID: lesson.CourseID}); err != nil {
			return HeartbeatResult{}, err
		}
	}

	if delta := seconds - prev.Seconds; delta > 0 {
		if err := s.q.UpsertDailyActivity(ctx, store.UpsertDailyActivityParams{
			UserID: userID, Seconds: min(delta, maxDeltaPerHeartbeat), Tz: location(tz).String(),
		}); err != nil {
			return HeartbeatResult{}, err
		}
	}

	result := HeartbeatResult{Seconds: max(seconds, prev.Seconds), Completed: prev.Completed}
	if !prev.Completed && lesson.DurationS > 0 && seconds >= threshold(lesson.DurationS) {
		if _, err := s.complete(ctx, userID, lesson, seconds); err != nil {
			return HeartbeatResult{}, err
		}
		result.Completed = true
	}
	return result, nil
}

// Complete marca la lección como vista por acción del alumno.
func (s *Service) Complete(ctx context.Context, userID, lessonID uuid.UUID) (store.LessonProgress, error) {
	lesson, err := s.accessibleLesson(ctx, userID, lessonID)
	if err != nil {
		return store.LessonProgress{}, err
	}
	return s.complete(ctx, userID, lesson, lesson.DurationS)
}

func (s *Service) complete(ctx context.Context, userID uuid.UUID, lesson store.GetLessonRow, seconds int32) (store.LessonProgress, error) {
	lp, err := s.q.MarkLessonCompleted(ctx, store.MarkLessonCompletedParams{UserID: userID, LessonID: lesson.ID, Seconds: seconds})
	if err != nil {
		return store.LessonProgress{}, err
	}
	if err := s.q.RefreshCourseProgress(ctx, store.RefreshCourseProgressParams{UserID: userID, CourseID: lesson.CourseID}); err != nil {
		return store.LessonProgress{}, err
	}
	return lp, nil
}

// CourseProgressView es lo que lee el player: agregado + posición por lección.
type CourseProgressView struct {
	Course  store.Course
	Summary store.CourseProgress
	Lessons []store.ListLessonProgressByCourseRow
}

// CourseProgress devuelve el progreso del usuario en un curso al que
// tiene acceso. Si nunca se materializó el agregado, lo crea (una vez).
func (s *Service) CourseProgress(ctx context.Context, userID uuid.UUID, slug string) (CourseProgressView, error) {
	course, err := s.q.GetCourseBySlug(ctx, slug)
	if errors.Is(err, pgx.ErrNoRows) {
		return CourseProgressView{}, ErrCourseNotFound
	} else if err != nil {
		return CourseProgressView{}, err
	}
	ok, err := s.q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: userID, ScopeID: course.ID})
	if err != nil {
		return CourseProgressView{}, err
	}
	if !ok {
		return CourseProgressView{}, ErrNoAccess
	}

	summary, err := s.q.GetCourseProgress(ctx, store.GetCourseProgressParams{UserID: userID, CourseID: course.ID})
	if errors.Is(err, pgx.ErrNoRows) {
		if err := s.q.RefreshCourseProgress(ctx, store.RefreshCourseProgressParams{UserID: userID, CourseID: course.ID}); err != nil {
			return CourseProgressView{}, err
		}
		summary, err = s.q.GetCourseProgress(ctx, store.GetCourseProgressParams{UserID: userID, CourseID: course.ID})
	}
	if err != nil {
		return CourseProgressView{}, err
	}

	lessons, err := s.q.ListLessonProgressByCourse(ctx, store.ListLessonProgressByCourseParams{UserID: userID, CourseID: course.ID})
	if err != nil {
		return CourseProgressView{}, err
	}
	return CourseProgressView{Course: course, Summary: summary, Lessons: lessons}, nil
}

// --- Dashboard ---

type CourseStatus string

const (
	StatusPending    CourseStatus = "pending"
	StatusInProgress CourseStatus = "in_progress"
	StatusCompleted  CourseStatus = "completed"
)

type CourseCard struct {
	Course           store.Course
	CompletedLessons int32
	TotalLessons     int32
	LastLessonID     *uuid.UUID
	Status           CourseStatus
}

type CareerCard struct {
	Career           store.Career
	Courses          []CourseCard
	CompletedLessons int32
	TotalLessons     int32
}

type Dashboard struct {
	Continue    *store.GetContinueWatchingRow
	StreakDays  int
	WeekSeconds int32
	Careers     []CareerCard
	Courses     []CourseCard
}

// Dashboard arma el panel del alumno leyendo solo agregados:
// course_progress (materializado) y daily_activity (una fila por día).
func (s *Service) Dashboard(ctx context.Context, userID uuid.UUID, tz string) (Dashboard, error) {
	var d Dashboard

	cw, err := s.q.GetContinueWatching(ctx, userID)
	if err == nil {
		d.Continue = &cw
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return d, err
	}

	progress, err := s.q.ListCourseProgressByUser(ctx, userID)
	if err != nil {
		return d, err
	}
	byCourse := make(map[uuid.UUID]store.CourseProgress, len(progress))
	for _, p := range progress {
		byCourse[p.CourseID] = p
	}
	totals, err := s.q.ListCourseStats(ctx)
	if err != nil {
		return d, err
	}
	lessonTotals := make(map[uuid.UUID]int32, len(totals))
	for _, t := range totals {
		lessonTotals[t.CourseID] = t.LessonCount
	}

	careers, err := s.q.ListEnrolledCareers(ctx, userID)
	if err != nil {
		return d, err
	}
	for _, c := range careers {
		rows, err := s.q.ListCareerCourses(ctx, c.ID)
		if err != nil {
			return d, err
		}
		card := CareerCard{Career: c}
		for _, r := range rows {
			if r.Status != "published" {
				continue
			}
			course := store.Course{ID: r.ID, Slug: r.Slug, Title: r.Title, Subtitle: r.Subtitle, Level: r.Level, Position: r.CareerPosition}
			cc := courseCard(course, byCourse[r.ID], lessonTotals[r.ID])
			card.Courses = append(card.Courses, cc)
			card.CompletedLessons += cc.CompletedLessons
			card.TotalLessons += cc.TotalLessons
		}
		d.Careers = append(d.Careers, card)
	}

	courses, err := s.q.ListEnrolledCourses(ctx, userID)
	if err != nil {
		return d, err
	}
	for _, c := range courses {
		d.Courses = append(d.Courses, courseCard(c, byCourse[c.ID], lessonTotals[c.ID]))
	}

	d.StreakDays, d.WeekSeconds, err = s.activity(ctx, userID, location(tz))
	return d, err
}

func courseCard(course store.Course, p store.CourseProgress, total int32) CourseCard {
	cc := CourseCard{Course: course, CompletedLessons: p.CompletedLessons, TotalLessons: max(p.TotalLessons, total), Status: StatusPending}
	if p.LastLessonID.Valid {
		id := uuid.UUID(p.LastLessonID.Bytes)
		cc.LastLessonID = &id
	}
	switch {
	case cc.TotalLessons > 0 && cc.CompletedLessons >= cc.TotalLessons:
		cc.Status = StatusCompleted
	case cc.CompletedLessons > 0 || cc.LastLessonID != nil:
		cc.Status = StatusInProgress
	}
	return cc
}

// activity calcula racha (días consecutivos con estudio, contando hoy
// o ayer como inicio) y segundos desde el lunes de esta semana.
func (s *Service) activity(ctx context.Context, userID uuid.UUID, loc *time.Location) (int, int32, error) {
	today := dateIn(time.Now(), loc)
	since := today.AddDate(0, 0, -activityWindowDays)
	rows, err := s.q.ListDailyActivitySince(ctx, store.ListDailyActivitySinceParams{
		UserID: userID, Day: pgtype.Date{Time: since, Valid: true},
	})
	if err != nil {
		return 0, 0, err
	}

	days := make(map[time.Time]int32, len(rows))
	for _, r := range rows {
		days[dateOnly(r.Day.Time)] = r.Seconds
	}

	// Semana: lunes a hoy.
	weekday := int(today.Weekday()+6) % 7 // lunes = 0
	monday := today.AddDate(0, 0, -weekday)
	var week int32
	for d, sec := range days {
		if !d.Before(monday) {
			week += sec
		}
	}

	// Racha: si hoy no hubo actividad todavía, la racha vigente termina ayer.
	cursor := today
	if days[cursor] == 0 {
		cursor = cursor.AddDate(0, 0, -1)
	}
	streak := 0
	for days[cursor] > 0 {
		streak++
		cursor = cursor.AddDate(0, 0, -1)
	}
	return streak, week, nil
}

// --- helpers ---

func (s *Service) accessibleLesson(ctx context.Context, userID, lessonID uuid.UUID) (store.GetLessonRow, error) {
	lesson, err := s.q.GetLesson(ctx, lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.GetLessonRow{}, ErrLessonNotFound
	} else if err != nil {
		return store.GetLessonRow{}, err
	}
	// El progreso siempre es de un curso al que se tiene acceso: las
	// muestras gratis no cuentan para un visitante sin enrollment.
	ok, err := s.q.HasCourseAccess(ctx, store.HasCourseAccessParams{UserID: userID, ScopeID: lesson.CourseID})
	if err != nil {
		return store.GetLessonRow{}, err
	}
	if !ok {
		return store.GetLessonRow{}, ErrNoAccess
	}
	return lesson, nil
}

func threshold(duration int32) int32 {
	return int32(math.Ceil(float64(duration) * CompletionThreshold))
}

func location(tz string) *time.Location {
	if loc, err := time.LoadLocation(tz); err == nil && tz != "" {
		return loc
	}
	loc, err := time.LoadLocation(defaultTZ)
	if err != nil {
		return time.UTC
	}
	return loc
}

func dateIn(t time.Time, loc *time.Location) time.Time {
	return dateOnly(t.In(loc))
}

func dateOnly(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}
