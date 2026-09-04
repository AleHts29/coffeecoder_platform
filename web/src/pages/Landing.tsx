import { useSuspenseQuery } from '@tanstack/react-query'
import { careersQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { ButtonLink } from '@/components/Button'
import { CareerCard } from '@/components/Cards'

export function Landing() {
  useTitle()
  const { data: careers } = useSuspenseQuery(careersQuery())
  const featured = careers.slice(0, 2)

  return (
    <div className="flex flex-col gap-16">
      <section className="flex flex-col gap-6 py-6 sm:py-12">
        <p className="font-mono text-xs text-ink-faint">carreras · backend · en profundidad</p>
        <h1 className="max-w-3xl text-4xl leading-tight text-ink sm:text-5xl">
          Backend en serio, sin relleno.
        </h1>
        <p className="max-w-2xl text-lg text-ink-soft">
          Catálogo chico y profundo. Carreras curadas que te llevan de cero a producción con Go y
          PostgreSQL, en video, a tu ritmo, con acceso de por vida.
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <ButtonLink variant="primary" to="/catalogo">
            Ver carreras
          </ButtonLink>
          <p className="text-sm text-ink-faint">Servite un café y empezá.</p>
        </div>
      </section>

      {featured.length > 0 && (
        <section aria-labelledby="destacadas" className="flex flex-col gap-5">
          <div className="flex items-baseline justify-between gap-4">
            <h2 id="destacadas" className="text-2xl text-ink">
              Carreras destacadas
            </h2>
            <ButtonLink variant="ghost" to="/catalogo">
              Todo el catálogo
            </ButtonLink>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {featured.map((c) => (
              <CareerCard key={c.id} career={c} />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
