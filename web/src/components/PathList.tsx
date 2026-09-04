import { Link } from '@tanstack/react-router'
import type { CourseSummary } from '@/types/catalog'
import type { CourseCard } from '@/types/progress'
import { formatHours, pad2, plural } from '@/lib/format'
import { Meta } from './Meta'
import { ButtonLink } from './Button'
import { ProgressBar } from './ProgressBar'
import { CheckIcon, PlayIcon } from './icons'

type Props = {
  courses: CourseSummary[]
  /** Progreso por slug de curso, solo para compradores. */
  progress?: Record<string, CourseCard>
}

// "El camino": lista vertical conectada con nodos de estado por curso.
// Visitante: todos vacíos. Comprador: check = completado, anillo con
// play = en curso (barra + Continuar), vacío = pendiente.
export function PathList({ courses, progress }: Props) {
  return (
    <ol className="relative flex flex-col">
      {courses.map((course, i) => {
        const last = i === courses.length - 1
        const p = progress?.[course.slug]
        const status = p?.status ?? 'pending'
        return (
          <li key={course.id} className="relative flex gap-4 pb-6 last:pb-0">
            <div className="flex w-6 shrink-0 flex-col items-center">
              <Node status={status} />
              {!last && <span aria-hidden="true" className={'mt-1 w-0.5 flex-1 ' + (status === 'completed' ? 'bg-accent' : 'bg-border-strong')} />}
            </div>
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <p className="font-mono text-xs text-ink-faint">curso {pad2(course.position)}</p>
              <h3 className="text-lg text-ink">
                <Link to="/cursos/$slug" params={{ slug: course.slug }} className="rounded-control transition-colors duration-150 hover:text-accent">
                  {course.title}
                </Link>
              </h3>
              <p className="text-sm text-ink-soft">{course.subtitle}</p>
              <Meta items={[plural(course.lesson_count, 'lección', 'lecciones'), formatHours(course.duration_s)]} />
              {p && status === 'in_progress' && (
                <div className="mt-2 flex flex-col gap-3 sm:flex-row sm:items-center">
                  <ProgressBar
                    value={p.total_lessons > 0 ? (p.completed_lessons / p.total_lessons) * 100 : 0}
                    label={`Progreso de ${course.title}`}
                    className="flex-1"
                  />
                  {p.last_lesson_id && (
                    <ButtonLink
                      variant="secondary"
                      to="/cursos/$slug/lecciones/$lessonId"
                      params={{ slug: course.slug, lessonId: p.last_lesson_id }}
                      search={{}}
                    >
                      Continuar
                    </ButtonLink>
                  )}
                </div>
              )}
            </div>
          </li>
        )
      })}
    </ol>
  )
}

function Node({ status }: { status: CourseCard['status'] }) {
  const label = status === 'completed' ? 'completado' : status === 'in_progress' ? 'en curso' : 'pendiente'
  if (status === 'completed') {
    return (
      <span role="img" aria-label={label} className="mt-1 flex size-5 shrink-0 items-center justify-center rounded-full bg-accent text-on-accent">
        <CheckIcon size={12} />
      </span>
    )
  }
  if (status === 'in_progress') {
    return (
      <span role="img" aria-label={label} className="mt-1 flex size-5 shrink-0 items-center justify-center rounded-full border-2 border-accent text-accent">
        <PlayIcon size={10} />
      </span>
    )
  }
  return <span role="img" aria-label={label} className="hairline-strong mt-1 block size-5 shrink-0 rounded-full bg-surface-0" />
}
