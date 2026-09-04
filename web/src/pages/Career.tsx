import { useSuspenseQuery } from '@tanstack/react-query'
import { careerQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { formatHours, plural } from '@/lib/format'
import { LevelBadge } from '@/components/LevelBadge'
import { Meta } from '@/components/Meta'
import { PathList } from '@/components/PathList'
import { PurchaseCard } from '@/components/PurchaseCard'

// Página de venta principal: hero + card de compra sticky + "El camino".
export function Career({ slug }: { slug: string }) {
  const { data: career } = useSuspenseQuery(careerQuery(slug))
  useTitle(career.title)

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

        <div className="lg:hidden">
          <PurchaseCard kind="carrera" slug={career.slug} priceCents={career.price_cents} />
        </div>

        <section aria-labelledby="camino" className="flex flex-col gap-6">
          <div className="flex flex-col gap-1">
            <h2 id="camino" className="text-2xl text-ink">
              El camino
            </h2>
            <p className="text-sm text-ink-soft">
              Cursos en orden. Cada uno construye sobre el anterior.
            </p>
          </div>
          <PathList courses={career.courses} />
        </section>
      </div>

      <div className="hidden lg:block">
        <PurchaseCard kind="carrera" slug={career.slug} priceCents={career.price_cents} />
      </div>
    </article>
  )
}
