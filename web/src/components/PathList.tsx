import { Link } from '@tanstack/react-router'
import type { CourseSummary } from '@/types/catalog'
import { formatHours, pad2, plural } from '@/lib/format'
import { Meta } from './Meta'

// "El camino": lista vertical conectada con nodos de estado por curso.
// En P3 todos los nodos son "pendiente" (visitante). P5 agrega
// completado (check relleno) y en curso (anillo + barra + Continuar).
export function PathList({ courses }: { courses: CourseSummary[] }) {
  return (
    <ol className="relative flex flex-col">
      {courses.map((course, i) => {
        const last = i === courses.length - 1
        return (
          <li key={course.id} className="relative flex gap-4 pb-6 last:pb-0">
            <div className="flex w-6 shrink-0 flex-col items-center">
              <span
                aria-hidden="true"
                className="hairline-strong mt-1 block size-5 shrink-0 rounded-full bg-surface-0"
              />
              {!last && <span aria-hidden="true" className="mt-1 w-0.5 flex-1 bg-border-strong" />}
            </div>
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <p className="font-mono text-xs text-ink-faint">curso {pad2(course.position)}</p>
              <h3 className="text-lg text-ink">
                <Link
                  to="/cursos/$slug"
                  params={{ slug: course.slug }}
                  className="rounded-control transition-colors duration-150 hover:text-accent"
                >
                  {course.title}
                </Link>
              </h3>
              <p className="text-sm text-ink-soft">{course.subtitle}</p>
              <Meta
                items={[plural(course.lesson_count, 'lección', 'lecciones'), formatHours(course.duration_s)]}
              />
            </div>
          </li>
        )
      })}
    </ol>
  )
}
