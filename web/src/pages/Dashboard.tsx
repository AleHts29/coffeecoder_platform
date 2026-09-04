import { useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { dashboardQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { formatClock, formatHours, pad2 } from '@/lib/format'
import { ButtonLink } from '@/components/Button'
import { LevelBadge } from '@/components/LevelBadge'
import { ProgressBar, SegmentBar } from '@/components/ProgressBar'
import { EmptyState, ErrorState, Loading } from '@/components/PageState'
import { PlayIcon } from '@/components/icons'
import type { CourseCard } from '@/types/progress'

// Panel del alumno: "seguí donde quedaste", racha y horas en mono,
// carreras con segmentos por curso, cursos sueltos con barra fina.
// Todo sale de agregados: el backend no toca la tabla caliente.
export function Dashboard() {
  useTitle('Mi panel')
  const { status, user } = useAuth()
  const navigate = useNavigate()
  const dashboard = useQuery(dashboardQuery(user?.id ?? null))

  useEffect(() => {
    if (status === 'anonymous') void navigate({ to: '/ingresar', search: { redirect: '/panel' }, replace: true })
  }, [status, navigate])

  if (status !== 'authenticated' || dashboard.isPending) return <Loading label="Cargando tu panel" />
  if (dashboard.isError) return <ErrorState message="No pudimos cargar tu panel." onRetry={() => void dashboard.refetch()} />

  const d = dashboard.data
  const empty = d.careers.length === 0 && d.courses.length === 0
  const firstName = (user?.name || user?.email || '').split(' ')[0]

  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl text-ink">Hola, {firstName}</h1>
        <p className="font-mono text-sm text-ink-soft">
          racha de {d.streak_days} {d.streak_days === 1 ? 'día' : 'días'} · {formatHours(d.week_seconds)} esta semana
        </p>
      </header>

      {empty ? (
        <EmptyState title="Todavía no empezaste ningún camino" message="Elegí una carrera o un curso y este panel se llena solo.">
          <ButtonLink variant="primary" to="/catalogo" search={{}}>
            Ver el catálogo
          </ButtonLink>
        </EmptyState>
      ) : (
        <>
          {d.continue && (
            <section aria-labelledby="continuar" className="hairline flex flex-col gap-4 rounded-card bg-surface-1 p-5 sm:flex-row sm:items-center">
              <div className="flex aspect-video w-full shrink-0 items-center justify-center rounded-control bg-surface-2 sm:w-48" aria-hidden="true">
                <PlayIcon size={28} className="text-accent" />
              </div>
              <div className="flex min-w-0 flex-1 flex-col gap-2">
                <h2 id="continuar" className="font-mono text-xs text-ink-faint">
                  seguí donde quedaste
                </h2>
                <p className="text-lg text-ink">{d.continue.lesson_title}</p>
                <p className="text-sm text-ink-soft">
                  {d.continue.course_title} · módulo {pad2(d.continue.module_position)}
                </p>
                <ProgressBar
                  value={d.continue.duration_s > 0 ? (d.continue.seconds / d.continue.duration_s) * 100 : 0}
                  label={`Avance en ${d.continue.lesson_title}`}
                />
                <p className="font-mono text-xs text-ink-faint">
                  {formatClock(d.continue.seconds)} / {formatClock(d.continue.duration_s)}
                </p>
              </div>
              <ButtonLink
                variant="primary"
                to="/cursos/$slug/lecciones/$lessonId"
                params={{ slug: d.continue.course_slug, lessonId: d.continue.lesson_id }}
                search={{}}
                className="shrink-0"
              >
                Continuar
              </ButtonLink>
            </section>
          )}

          {d.careers.length > 0 && (
            <section aria-labelledby="mis-carreras" className="flex flex-col gap-4">
              <h2 id="mis-carreras" className="text-2xl text-ink">
                Mis carreras
              </h2>
              <div className="grid gap-4 md:grid-cols-2">
                {d.careers.map((c) => {
                  const pct = c.total_lessons > 0 ? Math.round((c.completed_lessons / c.total_lessons) * 100) : 0
                  return (
                    <Link
                      key={c.slug}
                      to="/carreras/$slug"
                      params={{ slug: c.slug }}
                      className="hairline flex flex-col gap-4 rounded-card bg-surface-1 p-5 transition-colors duration-150 hover:bg-surface-2"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <LevelBadge kind="carrera" level={c.level} />
                        <span className="font-mono text-sm text-ink">{pct}%</span>
                      </div>
                      <h3 className="text-lg text-ink">{c.title}</h3>
                      <SegmentBar
                        label={`${pct}% de ${c.title}`}
                        segments={c.courses.map((course) => ({ status: course.status, weight: Math.max(course.total_lessons, 1), title: course.title }))}
                      />
                      <p className="font-mono text-xs text-ink-faint">
                        {c.completed_lessons}/{c.total_lessons} lecciones · {c.courses.filter((x) => x.status === 'completed').length}/{c.courses.length} cursos
                      </p>
                    </Link>
                  )
                })}
              </div>
            </section>
          )}

          {d.courses.length > 0 && (
            <section aria-labelledby="cursos-sueltos" className="flex flex-col gap-4">
              <h2 id="cursos-sueltos" className="text-2xl text-ink">
                Cursos sueltos
              </h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {d.courses.map((c) => (
                  <CourseProgressCard key={c.slug} course={c} />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  )
}

function CourseProgressCard({ course }: { course: CourseCard }) {
  const pct = course.total_lessons > 0 ? (course.completed_lessons / course.total_lessons) * 100 : 0
  return (
    <Link
      to="/cursos/$slug"
      params={{ slug: course.slug }}
      className="hairline flex flex-col gap-3 rounded-card bg-surface-1 p-5 transition-colors duration-150 hover:bg-surface-2"
    >
      <LevelBadge kind="curso" level={course.level} />
      <h3 className="text-lg text-ink">{course.title}</h3>
      <ProgressBar value={pct} label={`Progreso de ${course.title}`} className="mt-auto" />
      <p className="font-mono text-xs text-ink-faint">
        {course.completed_lessons}/{course.total_lessons} lecciones
      </p>
    </Link>
  )
}
