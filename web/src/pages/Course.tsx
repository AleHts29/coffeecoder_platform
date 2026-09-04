import { useQuery, useSuspenseQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { courseProgressQuery, courseQuery } from '@/lib/queries'
import { useAuth } from '@/lib/auth'
import { AccessCard } from '@/components/AccessCard'
import { useTitle } from '@/lib/useTitle'
import { formatHours, formatPrice, plural } from '@/lib/format'
import { LevelBadge } from '@/components/LevelBadge'
import { Meta } from '@/components/Meta'
import { Curriculum } from '@/components/Curriculum'
import { PurchaseCard } from '@/components/PurchaseCard'
import { ArrowRightIcon } from '@/components/icons'

export function Course({ slug }: { slug: string }) {
  const { data: course } = useSuspenseQuery(courseQuery(slug))
  useTitle(course.title)
  const career = course.careers[0]
  const { user } = useAuth()
  const progress = useQuery(courseProgressQuery(course.slug, user?.id ?? null))
  const firstLesson = course.modules[0]?.lessons[0]?.id

  // Upsell al bundle: el curso avisa a qué carrera pertenece.
  const upsell = career && (
    <Link
      to="/carreras/$slug"
      params={{ slug: career.slug }}
      className="hairline group flex flex-col gap-1 rounded-card bg-surface-0 p-4 transition-colors duration-150 hover:bg-surface-2"
    >
      <span className="font-mono text-xs text-ink-faint">parte de la carrera</span>
      <span className="flex items-center justify-between gap-2 text-sm text-ink">
        {career.title}
        <ArrowRightIcon size={16} className="shrink-0 text-ink-faint group-hover:text-ink" />
      </span>
      <span className="font-mono text-xs text-ink-soft">
        carrera completa por {formatPrice(career.price_cents)}
      </span>
    </Link>
  )

  const card = progress.isSuccess ? (
    <AccessCard
      kind="curso"
      completed={progress.data.completed_lessons}
      total={progress.data.total_lessons}
      continueTo={
        progress.data.last_lesson_id
          ? { slug: course.slug, lessonId: progress.data.last_lesson_id }
          : firstLesson
            ? { slug: course.slug, lessonId: firstLesson }
            : null
      }
    />
  ) : (
    <PurchaseCard kind="curso" slug={course.slug} priceCents={course.price_cents}>
      {upsell}
    </PurchaseCard>
  )

  return (
    <article className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_320px] lg:gap-12">
      <div className="flex flex-col gap-12">
        <header className="flex flex-col gap-5">
          <LevelBadge kind="curso" level={course.level} />
          <h1 className="text-4xl leading-tight text-ink sm:text-5xl">{course.title}</h1>
          <p className="max-w-2xl text-lg text-ink-soft">{course.subtitle}</p>
          <Meta
            items={[
              plural(course.modules.length, 'módulo', 'módulos'),
              plural(course.lesson_count, 'lección', 'lecciones'),
              formatHours(course.duration_s),
            ]}
          />
          {course.description && (
            <p className="max-w-prose whitespace-pre-line text-ink-soft">{course.description}</p>
          )}
        </header>

        <div className="lg:hidden">{card}</div>

        <section aria-labelledby="curricula" className="flex flex-col gap-6">
          <div className="flex flex-col gap-1">
            <h2 id="curricula" className="text-2xl text-ink">
              Currícula
            </h2>
            <p className="text-sm text-ink-soft">
              Las lecciones marcadas como gratis se pueden ver sin comprar.
            </p>
          </div>
          <Curriculum modules={course.modules} courseSlug={course.slug} />
        </section>
      </div>

      <div className="hidden lg:block">{card}</div>
    </article>
  )
}
