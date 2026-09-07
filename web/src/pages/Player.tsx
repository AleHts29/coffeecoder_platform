import { useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient, useSuspenseQuery } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { courseProgressQuery, courseQuery, playbackQuery } from '@/lib/queries'
import { useAuth } from '@/lib/auth'
import { api, ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { useHeartbeat } from '@/lib/useHeartbeat'
import { prefs } from '@/lib/prefs'
import { pad2 } from '@/lib/format'
import { Button, ButtonLink } from '@/components/Button'
import { VideoPlayer } from '@/components/VideoPlayer'
import { PlayerSidebar } from '@/components/PlayerSidebar'
import { ErrorState, Loading, NotFoundState } from '@/components/PageState'
import { CheckIcon, ListIcon, XIcon } from '@/components/icons'

type Props = { slug: string; lessonId: string; autoplay?: boolean }

// Layout teatro: video protagonista, acciones debajo, sidebar derecha
// colapsable (modo cine). En mobile la sidebar va debajo (bottom sheet
// en P8).
export function Player({ slug, lessonId, autoplay }: Props) {
  const { data: course } = useSuspenseQuery(courseQuery(slug))
  const { status, user } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const [cinema, setCinema] = useState(false)
  const [sheet, setSheet] = useState(false)

  const flat = useMemo(
    () => course.modules.flatMap((m) => m.lessons.map((l) => ({ ...l, module: m }))),
    [course],
  )
  const index = flat.findIndex((l) => l.id === lessonId)
  const lesson = index >= 0 ? flat[index] : undefined
  const next = index >= 0 ? flat[index + 1] : undefined

  useTitle(lesson ? `${lesson.title} · ${course.title}` : course.title)

  const userId = user?.id ?? null
  const playback = useQuery({
    ...playbackQuery(lessonId, userId),
    enabled: status !== 'loading' && !!lesson,
  })
  // 403 acá significa "no compró": el player sigue (muestras gratis) sin progreso.
  const progress = useQuery(courseProgressQuery(slug, userId))
  const hasProgress = progress.isSuccess
  const lessonProgress = progress.data?.lessons.find((l) => l.lesson_id === lessonId)

  const invalidateProgress = () => {
    void queryClient.invalidateQueries({ queryKey: ['progress', 'course', slug] })
    void queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }

  useHeartbeat(videoRef, {
    lessonId,
    enabled: hasProgress && playback.isSuccess,
    onResult: (r) => {
      if (r.completed && !lessonProgress?.completed) invalidateProgress()
    },
  })

  const complete = useMutation({
    mutationFn: () => api(`/lessons/${lessonId}/complete`, { method: 'POST' }),
    onSuccess: invalidateProgress,
  })

  if (!lesson) {
    return <NotFoundState title="Esa lección no existe" message="Puede que se haya movido. La currícula completa está en la página del curso." />
  }

  const goNext = () => {
    if (next) void navigate({ to: '/cursos/$slug/lecciones/$lessonId', params: { slug, lessonId: next.id }, search: { autoplay: true } })
  }
  const completed = !!lessonProgress?.completed

  return (
    <div className={'grid gap-6 ' + (cinema ? '' : 'lg:grid-cols-[minmax(0,1fr)_320px]')}>
      <div className="flex min-w-0 flex-col gap-6">
        <section aria-label="Video">
          {playback.isPending || status === 'loading' ? (
            <div className="aspect-video rounded-card bg-surface-1">
              <Loading label="Preparando el video" />
            </div>
          ) : playback.isError ? (
            <PlaybackError error={playback.error} slug={slug} lessonId={lessonId} onRetry={() => void playback.refetch()} />
          ) : (
            <VideoPlayer
              ref={videoRef}
              src={playback.data.url}
              title={lesson.title}
              autoplay={!!autoplay && prefs.autoplay()}
              startAt={lessonProgress && !lessonProgress.completed ? lessonProgress.seconds : undefined}
              onEnded={() => prefs.autoplay() && goNext()}
            />
          )}
        </section>

        <header className="flex flex-col gap-3">
          <p className="font-mono text-xs text-ink-faint">
            módulo {pad2(lesson.module.position)} · lección {pad2(lesson.position)}
          </p>
          <h1 className="text-2xl text-ink sm:text-3xl">{lesson.title}</h1>
          <div className="flex flex-wrap items-center gap-3">
            {completed ? (
              <span className="inline-flex h-11 items-center gap-2 font-mono text-sm text-accent">
                <CheckIcon size={16} /> completada
              </span>
            ) : (
              <Button
                variant="secondary"
                disabled={!hasProgress || complete.isPending}
                title={hasProgress ? undefined : 'Disponible al comprar el curso'}
                onClick={() => complete.mutate()}
              >
                Marcar completada
              </Button>
            )}
            <span className="flex-1" />
            <AutoplayToggle />
            <Button variant="ghost" onClick={() => setCinema((c) => !c)} className="hidden lg:inline-flex" aria-pressed={cinema}>
              {cinema ? 'Mostrar contenido' : 'Modo cine'}
            </Button>
            {next ? (
              <ButtonLink
                variant="primary"
                to="/cursos/$slug/lecciones/$lessonId"
                params={{ slug, lessonId: next.id }}
                search={{ autoplay: true }}
              >
                Siguiente lección
              </ButtonLink>
            ) : (
              <ButtonLink variant="secondary" to="/cursos/$slug" params={{ slug }}>
                Volver al curso
              </ButtonLink>
            )}
          </div>
          {complete.isError && (
            <p role="alert" className="text-sm text-danger">
              {complete.error instanceof ApiError ? complete.error.message : 'algo salió mal, reintentá'}
            </p>
          )}
        </header>

        <section aria-labelledby="tab-resumen" className="flex flex-col gap-4">
          <div role="tablist" className="flex gap-1 border-b-[0.5px] border-border">
            <button id="tab-resumen" role="tab" aria-selected="true" type="button" className="-mb-px border-b-2 border-accent px-3 py-2 text-sm text-ink">
              Resumen
            </button>
          </div>
          <div role="tabpanel" aria-labelledby="tab-resumen" className="max-w-prose text-ink-soft">
            {lesson.description || 'Esta lección no tiene resumen todavía.'}
          </div>
        </section>
      </div>

      {/* Desktop: sidebar a la derecha. Mobile: bottom sheet. */}
      {!cinema && (
        <div className="hidden lg:block">
          <PlayerSidebar course={course} activeLessonId={lessonId} progress={progress.data} />
        </div>
      )}
      <div className="lg:hidden">
        <button
          type="button"
          onClick={() => setSheet(true)}
          aria-expanded={sheet}
          aria-controls="contenido-curso"
          className="hairline-strong fixed inset-x-4 bottom-4 z-30 flex h-12 items-center justify-between rounded-control bg-surface-1 px-4 text-sm text-ink"
        >
          <span className="flex items-center gap-2">
            <ListIcon size={18} className="text-accent" /> Contenido del curso
          </span>
          <span className="font-mono text-xs text-ink-faint">
            {index + 1}/{flat.length}
          </span>
        </button>
        {sheet && (
          <div className="fixed inset-0 z-40 flex flex-col justify-end" role="dialog" aria-modal="true" aria-label="Contenido del curso">
            <button type="button" aria-label="Cerrar" className="absolute inset-0 bg-surface-0/80" onClick={() => setSheet(false)} />
            <div id="contenido-curso" className="relative max-h-[85dvh] overflow-y-auto rounded-t-card bg-surface-1 pb-4">
              <div className="sticky top-0 flex items-center justify-between border-b-[0.5px] border-border bg-surface-1 px-4 py-2">
                <span className="font-mono text-xs text-ink-faint">contenido del curso</span>
                <Button variant="ghost" className="h-9 w-9 px-0" onClick={() => setSheet(false)} aria-label="Cerrar">
                  <XIcon size={18} />
                </Button>
              </div>
              <PlayerSidebar course={course} activeLessonId={lessonId} progress={progress.data} />
            </div>
          </div>
        )}
        <div className="h-16" aria-hidden="true" />
      </div>
    </div>
  )
}

function AutoplayToggle() {
  const [on, setOn] = useState(prefs.autoplay)
  return (
    <label className="flex items-center gap-2 text-sm text-ink-soft">
      <input
        type="checkbox"
        checked={on}
        onChange={(e) => {
          setOn(e.target.checked)
          prefs.setAutoplay(e.target.checked)
        }}
        className="size-4 accent-accent"
      />
      autoplay
    </label>
  )
}

function PlaybackError({ error, slug, lessonId, onRetry }: { error: unknown; slug: string; lessonId: string; onRetry: () => void }) {
  const status = error instanceof ApiError ? error.status : 0
  const message = error instanceof ApiError ? error.message : 'algo salió mal, reintentá'
  const redirect = `/cursos/${slug}/lecciones/${lessonId}`

  if (status === 401) {
    return (
      <Gate title="Iniciá sesión para ver esta lección" message="Si ya compraste el curso, entrá con tu cuenta y seguí desde acá.">
        <ButtonLink variant="secondary" to="/ingresar" search={{ redirect }}>
          Ingresar
        </ButtonLink>
      </Gate>
    )
  }
  if (status === 403) {
    return (
      <Gate title="Esta lección es parte del curso completo" message="Comprá el curso o la carrera que lo incluye y tenés acceso de por vida.">
        <ButtonLink variant="secondary" to="/cursos/$slug" params={{ slug }}>
          Ver el curso
        </ButtonLink>
      </Gate>
    )
  }
  if (status === 409) {
    return <Gate title="El video todavía no está listo" message="Se está procesando. Probá de nuevo en unos minutos." />
  }
  return <ErrorState message={message} onRetry={onRetry} />
}

function Gate({ title, message, children }: { title: string; message: string; children?: React.ReactNode }) {
  return (
    <div className="hairline flex aspect-video flex-col items-center justify-center gap-4 rounded-card bg-surface-1 p-6 text-center">
      <h2 className="text-xl text-ink">{title}</h2>
      <p className="max-w-md text-sm text-ink-soft">{message}</p>
      {children}
    </div>
  )
}
