import { useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient, useSuspenseQuery } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { courseProgressQuery, courseQuery, lessonContentQuery, playbackQuery, tz } from '@/lib/queries'
import { useAuth } from '@/lib/auth'
import { api, ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { useHeartbeat } from '@/lib/useHeartbeat'
import { prefs } from '@/lib/prefs'
import { pad2 } from '@/lib/format'
import { Button, ButtonLink } from '@/components/Button'
import { VideoPlayer } from '@/components/VideoPlayer'
import { PlayerSidebar } from '@/components/PlayerSidebar'
import { LessonContent } from '@/components/LessonContent'
import { ArticleReader } from '@/components/ArticleReader'
import { ErrorState, Loading, NotFoundState } from '@/components/PageState'
import { CheckIcon, ListIcon, XIcon } from '@/components/icons'

type Props = { slug: string; lessonId: string; autoplay?: boolean }

// Layout teatro: el video (o el lector, si la lección es de lectura)
// ocupa la columna principal y la currícula va a la derecha; en mobile
// la currícula es un bottom sheet.
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
  const isArticle = lesson?.kind === 'article'

  useTitle(lesson ? `${lesson.title} · ${course.title}` : course.title)

  const userId = user?.id ?? null
  const ready = status !== 'loading' && !!lesson
  const playback = useQuery({ ...playbackQuery(lessonId, userId), enabled: ready && !isArticle })
  const content = useQuery({ ...lessonContentQuery(lessonId, userId), enabled: ready })
  const progress = useQuery(courseProgressQuery(slug, userId))
  const hasProgress = progress.isSuccess
  const lessonProgress = progress.data?.lessons.find((l) => l.lesson_id === lessonId)
  const completed = !!lessonProgress?.completed

  const invalidateProgress = () => {
    void queryClient.invalidateQueries({ queryKey: ['progress', 'course', slug] })
    void queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }

  useHeartbeat(videoRef, {
    lessonId,
    enabled: !isArticle && hasProgress && playback.isSuccess,
    onResult: (r) => {
      if (r.completed && !completed) invalidateProgress()
    },
  })

  const complete = useMutation({
    mutationFn: () => api(`/lessons/${lessonId}/complete`, { method: 'POST', body: JSON.stringify({ tz: tz() }) }),
    onSuccess: invalidateProgress,
  })

  if (!lesson) {
    return <NotFoundState title="Esa lección no existe" message="Puede que se haya movido. La currícula completa está en la página del curso." />
  }

  const goNext = () => {
    if (next) void navigate({ to: '/cursos/$slug/lecciones/$lessonId', params: { slug, lessonId: next.id }, search: { autoplay: true } })
  }

  // El artículo se da por leído al llegar al final, una sola vez.
  const onReachedEnd = hasProgress && !completed && !complete.isPending ? () => complete.mutate() : undefined

  const header = (
    <header className="flex flex-col gap-3">
      <p className="font-mono text-xs text-ink-faint">
        módulo {pad2(lesson.module.position)} · lección {pad2(lesson.position)}
        {isArticle && content.isSuccess && ` · lectura ${Math.max(1, Math.round(content.data.reading_time_s / 60))} min`}
      </p>
      <h1 className="text-2xl text-ink sm:text-3xl">{lesson.title}</h1>
    </header>
  )

  const actions = (
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
      {!isArticle && <AutoplayToggle />}
      <Button variant="ghost" onClick={() => setCinema((c) => !c)} className="hidden lg:inline-flex" aria-pressed={cinema}>
        {cinema ? 'Mostrar contenido' : 'Modo cine'}
      </Button>
      {next ? (
        <ButtonLink variant="primary" to="/cursos/$slug/lecciones/$lessonId" params={{ slug, lessonId: next.id }} search={{ autoplay: true }}>
          Siguiente lección
        </ButtonLink>
      ) : (
        <ButtonLink variant="secondary" to="/cursos/$slug" params={{ slug }}>
          Volver al curso
        </ButtonLink>
      )}
    </div>
  )

  return (
    <div className={'grid gap-6 ' + (cinema ? '' : 'lg:grid-cols-[minmax(0,1fr)_320px]')}>
      <div className="flex min-w-0 flex-col gap-6">
        {isArticle ? (
          <>
            {header}
            <section aria-label="Artículo">
              {content.isPending || status === 'loading' ? (
                <Loading label="Cargando la lección" />
              ) : content.isError ? (
                <LessonGate error={content.error} slug={slug} lessonId={lessonId} onRetry={() => void content.refetch()} />
              ) : (
                <ArticleReader content={content.data} onReachedEnd={onReachedEnd} />
              )}
            </section>
            {actions}
          </>
        ) : (
          <>
            <section aria-label="Video">
              {playback.isPending || status === 'loading' ? (
                <div className="aspect-video rounded-card bg-surface-1">
                  <Loading label="Preparando el video" />
                </div>
              ) : playback.isError ? (
                <LessonGate error={playback.error} slug={slug} lessonId={lessonId} onRetry={() => void playback.refetch()} aspect />
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
            {header}
            {actions}
            <section aria-labelledby="tab-resumen" className="flex flex-col gap-4">
              <div role="tablist" className="flex gap-1 border-b-[0.5px] border-border">
                <button id="tab-resumen" role="tab" aria-selected="true" type="button" className="-mb-px border-b-2 border-accent px-3 py-2 text-sm text-ink">
                  Resumen
                </button>
              </div>
              <div role="tabpanel" aria-labelledby="tab-resumen">
                {content.isSuccess && content.data.body_md.trim() ? (
                  <LessonContent body={content.data.body_md} demos={content.data.demos} />
                ) : (
                  <p className="max-w-prose text-ink-soft">{lesson.description || 'Esta lección no tiene resumen todavía.'}</p>
                )}
              </div>
            </section>
          </>
        )}

        {complete.isError && (
          <p role="alert" className="text-sm text-danger">
            {complete.error instanceof ApiError ? complete.error.message : 'algo salió mal, reintentá'}
          </p>
        )}
      </div>

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

// Puerta común a video y lectura: el backend responde igual en ambos.
function LessonGate({ error, slug, lessonId, onRetry, aspect }: { error: unknown; slug: string; lessonId: string; onRetry: () => void; aspect?: boolean }) {
  const status = error instanceof ApiError ? error.status : 0
  const message = error instanceof ApiError ? error.message : 'algo salió mal, reintentá'
  const redirect = `/cursos/${slug}/lecciones/${lessonId}`
  const box = 'hairline flex flex-col items-center justify-center gap-4 rounded-card bg-surface-1 p-6 text-center ' + (aspect ? 'aspect-video' : 'py-12')

  if (status === 401) {
    return (
      <div className={box}>
        <h2 className="text-xl text-ink">Iniciá sesión para ver esta lección</h2>
        <p className="max-w-md text-sm text-ink-soft">Si ya compraste el curso, entrá con tu cuenta y seguí desde acá.</p>
        <ButtonLink variant="secondary" to="/ingresar" search={{ redirect }}>
          Ingresar
        </ButtonLink>
      </div>
    )
  }
  if (status === 403) {
    return (
      <div className={box}>
        <h2 className="text-xl text-ink">Esta lección es parte del curso completo</h2>
        <p className="max-w-md text-sm text-ink-soft">Comprá el curso o la carrera que lo incluye y tenés acceso de por vida.</p>
        <ButtonLink variant="secondary" to="/cursos/$slug" params={{ slug }}>
          Ver el curso
        </ButtonLink>
      </div>
    )
  }
  if (status === 409) {
    return (
      <div className={box}>
        <h2 className="text-xl text-ink">El video todavía no está listo</h2>
        <p className="max-w-md text-sm text-ink-soft">Se está procesando. Probá de nuevo en unos minutos.</p>
      </div>
    )
  }
  return <ErrorState message={message} onRetry={onRetry} />
}
