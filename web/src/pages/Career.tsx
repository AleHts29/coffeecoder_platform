import { useQuery, useSuspenseQuery } from '@tanstack/react-query'
import { careerQuery, dashboardQuery } from '@/lib/queries'
import { useAuth } from '@/lib/auth'
import { AccessCard } from '@/components/AccessCard'
import { useTitle } from '@/lib/useTitle'
import { formatHours, plural } from '@/lib/format'
import { LevelBadge } from '@/components/LevelBadge'
import { Meta } from '@/components/Meta'
import { PathList } from '@/components/PathList'
import { PurchaseCard } from '@/components/PurchaseCard'
import type { CourseCard } from '@/types/progress'

// Página de venta principal: hero + card de compra sticky + "El camino".
export function Career({ slug }: { slug: string }) {
  const { data: career } = useSuspenseQuery(careerQuery(slug))
  useTitle(career.title)
  const { user } = useAuth()
  const dashboard = useQuery(dashboardQuery(user?.id ?? null))
  const mine = dashboard.data?.careers.find((c) => c.slug === slug)
  const progress = mine ? Object.fromEntries(mine.courses.map((c) => [c.slug, c])) : undefined

  // Para compradores, la card de compra se reemplaza por la de acceso.
  const card = mine ? (
    <AccessCard kind="carrera" completed={mine.completed_lessons} total={mine.total_lessons} continueTo={continueTarget(mine.courses)} />
  ) : (
    <PurchaseCard kind="carrera" slug={career.slug} priceCents={career.price_cents} />
  )

  return (
    <article className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_320px] lg:gap-12">
      <div className="flex flex-col gap-12">
        <header className="flex flex-col gap-5">
          <LevelBadge kind="carrera" level={career.level} />
          <h1 className="text-4xl leading-tight text-ink sm:text-5xl">{career.title}</h1>
          <p className="max-w-2xl text-lg text-ink-soft">{career.subtitle}</p>
          <Meta
            items={[
              plural(career.course_count, 'curso', 'cursos'),
              plural(career.lesson_count, 'lección', 'lecciones'),
              formatHours(career.duration_s),
            ]}
          />
          {career.description && (
            <p className="max-w-prose whitespace-pre-line text-ink-soft">{career.description}</p>
          )}
        </header>

        <div className="lg:hidden">{card}</div>

        <section aria-labelledby="camino" className="flex flex-col gap-6">
          <div className="flex flex-col gap-1">
            <h2 id="camino" className="text-2xl text-ink">
              El camino
            </h2>
            <p className="text-sm text-ink-soft">
              Cursos en orden. Cada uno construye sobre el anterior.
            </p>
          </div>
          <PathList courses={career.courses} progress={progress} />
        </section>
      </div>

      <div className="hidden lg:block">{card}</div>
    </article>
  )
}

// Continuar: la última lección del primer curso en curso. Sin nada
// iniciado, el camino ya lleva a cada curso y ahí está "Empezar".
function continueTarget(cards: CourseCard[]) {
  const inProgress = cards.find((c) => c.status === 'in_progress' && c.last_lesson_id)
  return inProgress ? { slug: inProgress.slug, lessonId: inProgress.last_lesson_id! } : null
}
