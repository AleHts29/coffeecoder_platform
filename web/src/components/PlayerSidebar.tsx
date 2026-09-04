import { Link } from '@tanstack/react-router'
import type { CourseDetail } from '@/types/catalog'
import { formatClock, formatHours, pad2, plural } from '@/lib/format'
import { ChevronDownIcon, PlayIcon } from './icons'

type Props = {
  course: CourseDetail
  activeLessonId: string
}

// Sidebar del player: curso, resumen en mono, módulos como acordeones,
// lección activa con fondo surface-2 y borde izquierdo caramelo.
// Progreso real (barra, checks de completado) llega en P5.
export function PlayerSidebar({ course, activeLessonId }: Props) {
  return (
    <aside aria-label="Contenido del curso" className="hairline flex flex-col rounded-card bg-surface-1">
      <div className="flex flex-col gap-2 border-b-[0.5px] border-border p-4">
        <Link to="/cursos/$slug" params={{ slug: course.slug }} className="text-ink hover:text-accent">
          {course.title}
        </Link>
        <p className="font-mono text-xs text-ink-faint">
          {plural(course.lesson_count, 'lección', 'lecciones')} · {formatHours(course.duration_s)}
        </p>
      </div>
      <div className="flex flex-col">
        {course.modules.map((module) => {
          const containsActive = module.lessons.some((l) => l.id === activeLessonId)
          return (
            <details key={module.id} open={containsActive} className="group border-b-[0.5px] border-border last:border-b-0">
              <summary className="flex min-h-12 cursor-pointer list-none items-center gap-3 px-4 py-2 text-sm hover:bg-surface-2 [&::-webkit-details-marker]:hidden">
                <span className="font-mono text-xs text-ink-faint">{pad2(module.position)}</span>
                <span className="flex-1 text-ink">{module.title}</span>
                <ChevronDownIcon size={16} className="text-ink-faint transition-transform duration-150 group-open:rotate-180" />
              </summary>
              <ol>
                {module.lessons.map((lesson) => {
                  const active = lesson.id === activeLessonId
                  return (
                    <li key={lesson.id}>
                      <Link
                        to="/cursos/$slug/lecciones/$lessonId"
                        params={{ slug: course.slug, lessonId: lesson.id }}
                        aria-current={active ? 'page' : undefined}
                        className={
                          'flex min-h-11 items-center gap-3 border-l-2 py-2 pr-4 pl-3 text-sm transition-colors duration-150 ' +
                          (active
                            ? 'border-accent bg-surface-2 text-ink'
                            : 'border-transparent text-ink-soft hover:bg-surface-2 hover:text-ink')
                        }
                      >
                        <span className="w-5 font-mono text-xs text-ink-faint">{pad2(lesson.position)}</span>
                        <span className="flex-1">{lesson.title}</span>
                        {lesson.is_free_sample && <PlayIcon size={14} className="text-accent" aria-label="gratis" />}
                        <span className="font-mono text-xs text-ink-faint">{formatClock(lesson.duration_s)}</span>
                      </Link>
                    </li>
                  )
                })}
              </ol>
            </details>
          )
        })}
      </div>
    </aside>
  )
}
