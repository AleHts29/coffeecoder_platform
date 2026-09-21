import { Link } from '@tanstack/react-router'
import type { CareerSummary, CourseSummary } from '@/types/catalog'
import { formatHours, formatPrice, plural } from '@/lib/format'
import { LevelBadge } from './LevelBadge'
import { Meta } from './Meta'
import { ArrowRightIcon } from './icons'

const card =
  'hairline group flex flex-col gap-4 rounded-card bg-surface-1 p-5 transition-colors duration-150 hover:bg-surface-2 focus-visible:outline-2'

export function CareerCard({ career }: { career: CareerSummary }) {
  return (
    <Link to="/carreras/$slug" params={{ slug: career.slug }} className={card}>
      <div className="flex items-start justify-between gap-3">
        <span className="flex flex-wrap items-center gap-2">
          <LevelBadge kind="carrera" level={career.level} />
          {career.category && <span className="font-mono text-xs text-ink-faint">{career.category.name}</span>}
        </span>
        <span className="font-mono text-sm text-ink">{formatPrice(career.price_cents)}</span>
      </div>
      <div className="flex flex-col gap-1">
        <h3 className="text-xl text-ink">{career.title}</h3>
        <p className="text-sm text-ink-soft">{career.subtitle}</p>
      </div>
      <Meta
        className="mt-auto"
        items={[
          plural(career.course_count, 'curso', 'cursos'),
          plural(career.lesson_count, 'lección', 'lecciones'),
          formatHours(career.duration_s),
        ]}
      />
      <span className="inline-flex items-center gap-1 text-sm text-ink-soft group-hover:text-ink">
        Ver el camino <ArrowRightIcon size={16} />
      </span>
    </Link>
  )
}

export function CourseCard({ course }: { course: CourseSummary }) {
  return (
    <Link to="/cursos/$slug" params={{ slug: course.slug }} className={card}>
      <div className="flex items-start justify-between gap-3">
        <span className="flex flex-wrap items-center gap-2">
          <LevelBadge kind="curso" level={course.level} />
          {course.category && <span className="font-mono text-xs text-ink-faint">{course.category.name}</span>}
        </span>
        <span className="font-mono text-sm text-ink">{formatPrice(course.price_cents)}</span>
      </div>
      <div className="flex flex-col gap-1">
        <h3 className="text-lg text-ink">{course.title}</h3>
        <p className="text-sm text-ink-soft">{course.subtitle}</p>
      </div>
      <Meta
        className="mt-auto"
        items={[plural(course.lesson_count, 'lección', 'lecciones'), formatHours(course.duration_s)]}
      />
    </Link>
  )
}
