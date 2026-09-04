package media

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/alejandro/coffeecoder/internal/store"
)

var (
	ErrLessonNotFound = errors.New("esa lección no existe")
	ErrNoAccess       = errors.New("necesitás comprar el curso para ver esta lección")
	ErrNotReady       = errors.New("el video de esta lección todavía no está disponible")
)

const uploadTicketTTL = 2 * time.Hour

type Service struct {
	q        *store.Queries
	provider VideoProvider
	ttl      time.Duration
	logger   *slog.Logger
}

func NewService(q *store.Queries, provider VideoProvider, playbackTTL time.Duration, logger *slog.Logger) *Service {
	return &Service{q: q, provider: provider, ttl: playbackTTL, logger: logger}
}

// Playback es lo que recibe el player: URL firmada y su vencimiento.
type Playback struct {
	URL       string
	ExpiresAt time.Time
	Lesson    store.GetLessonRow
}

// Playback verifica acceso y firma la URL. userID puede ser uuid.Nil
// (visitante): solo pasan las lecciones de muestra gratis.
// video_asset_id nunca sale de acá: se firma y se descarta.
func (s *Service) Playback(ctx context.Context, userID, lessonID uuid.UUID) (Playback, error) {
	lesson, err := s.q.GetLesson(ctx, lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Playback{}, ErrLessonNotFound
	} else if err != nil {
		return Playback{}, err
	}

	ok, err := s.q.HasLessonAccess(ctx, store.HasLessonAccessParams{UserID: userID, ID: lessonID})
	if err != nil {
		return Playback{}, err
	}
	if ok == nil || !*ok {
		return Playback{}, ErrNoAccess
	}

	if lesson.VideoStatus != string(StatusReady) || lesson.VideoAssetID == nil {
		return Playback{}, ErrNotReady
	}

	expires := time.Now().Add(s.ttl)
	url, err := s.provider.SignedPlaybackURL(*lesson.VideoAssetID, s.ttl)
	if err != nil {
		return Playback{}, fmt.Errorf("media: firmando URL: %w", err)
	}
	return Playback{URL: url, ExpiresAt: expires, Lesson: lesson}, nil
}

// StartUpload crea el asset en el provider, lo asocia a la lección en
// estado 'uploading' y devuelve el ticket TUS para el browser del admin.
func (s *Service) StartUpload(ctx context.Context, lessonID uuid.UUID) (UploadTicket, error) {
	lesson, err := s.q.GetLesson(ctx, lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return UploadTicket{}, ErrLessonNotFound
	} else if err != nil {
		return UploadTicket{}, err
	}

	assetID, err := s.provider.CreateVideo(ctx, lesson.Title)
	if err != nil {
		return UploadTicket{}, err
	}

	if _, err := s.q.SetLessonVideoUploading(ctx, store.SetLessonVideoUploadingParams{
		ID:            lessonID,
		VideoProvider: s.provider.Name(),
		VideoAssetID:  &assetID,
	}); err != nil {
		return UploadTicket{}, err
	}

	return s.provider.UploadTicket(assetID, uploadTicketTTL)
}

// SyncVideo consulta al provider y actualiza estado/duración. Es el
// plan B del webhook (desarrollo local, webhook perdido).
func (s *Service) SyncVideo(ctx context.Context, lessonID uuid.UUID) (store.Lesson, error) {
	lesson, err := s.q.GetLesson(ctx, lessonID)
	if errors.Is(err, pgx.ErrNoRows) {
		return store.Lesson{}, ErrLessonNotFound
	} else if err != nil {
		return store.Lesson{}, err
	}
	if lesson.VideoAssetID == nil {
		return store.Lesson{}, ErrNotReady
	}

	info, err := s.provider.GetAsset(ctx, *lesson.VideoAssetID)
	if err != nil {
		return store.Lesson{}, err
	}
	return s.applyStatus(ctx, lesson.VideoProvider, *lesson.VideoAssetID, info)
}

// ApplyWebhook aplica un evento de transcodificación. Un evento para
// un asset desconocido no es error: Bunny puede notificar videos que
// no son nuestros (otra app en la misma librería) o ya borrados.
func (s *Service) ApplyWebhook(ctx context.Context, ev WebhookEvent) error {
	status, ok := WebhookStatus(ev.Status)
	if !ok {
		return nil
	}
	info := AssetInfo{Status: status}
	if status == StatusReady {
		// El webhook no trae duración: la pedimos al provider.
		if fetched, err := s.provider.GetAsset(ctx, ev.VideoGUID); err == nil {
			info.DurationS = fetched.DurationS
		} else {
			s.logger.Warn("media: webhook ready sin duración", "asset", ev.VideoGUID, "err", err)
		}
	}
	_, err := s.applyStatus(ctx, s.provider.Name(), ev.VideoGUID, info)
	if errors.Is(err, pgx.ErrNoRows) {
		s.logger.Info("media: webhook para asset desconocido", "asset", ev.VideoGUID, "status", ev.Status)
		return nil
	}
	return err
}

func (s *Service) applyStatus(ctx context.Context, provider, assetID string, info AssetInfo) (store.Lesson, error) {
	return s.q.UpdateLessonVideoByAsset(ctx, store.UpdateLessonVideoByAssetParams{
		VideoProvider: provider,
		VideoAssetID:  &assetID,
		VideoStatus:   string(info.Status),
		Column4:       info.DurationS,
	})
}
