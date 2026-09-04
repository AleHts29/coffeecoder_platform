import { useSuspenseQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { careersQuery, coursesQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { LEVELS, type Level } from '@/types/catalog'
import { CareerCard, CourseCard } from '@/components/Cards'
import { EmptyState } from '@/components/PageState'
import { ButtonLink } from '@/components/Button'

export type CatalogSearch = { tueste?: Level }

// Filtro por tueste. El filtro por tema queda para cuando el catálogo
// tenga un campo de tema (hoy el esquema no lo modela).
export function Catalog({ tueste }: CatalogSearch) {
  useTitle('Catálogo')
  const { data: careers } = useSuspenseQuery(careersQuery())
  const { data: courses } = useSuspenseQuery(coursesQuery())

  const visibleCareers = tueste ? careers.filter((c) => c.level === tueste) : careers
  const visibleCourses = tueste ? courses.filter((c) => c.level === tueste) : courses
  const nothing = visibleCareers.length === 0 && visibleCourses.length === 0

  const pill = (active: boolean) =>
    `inline-flex h-9 items-center rounded-control px-3 font-mono text-xs transition-colors duration-150 ` +
    (active
      ? 'bg-surface-2 text-ink hairline-strong'
      : 'text-ink-soft hover:bg-surface-2 hover:text-ink')

  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-col gap-6">
        <div className="flex flex-col gap-2">
          <h1 className="text-3xl text-ink">Catálogo</h1>
          <p className="max-w-2xl text-ink-soft">
            Las carreras son el camino completo. Los cursos, la puerta de entrada.
          </p>
        </div>
        <fieldset className="flex flex-wrap items-center gap-2">
          <legend className="sr-only">Filtrar por tueste</legend>
          <span aria-hidden="true" className="mr-1 font-mono text-xs text-ink-faint">
            tueste
          </span>
          <Link to="/catalogo" search={{}} className={pill(!tueste)} aria-current={!tueste ? 'true' : undefined}>
            todos
          </Link>
          {LEVELS.map((level) => (
            <Link
              key={level}
              to="/catalogo"
              search={{ tueste: level }}
              className={pill(tueste === level)}
              aria-current={tueste === level ? 'true' : undefined}
            >
              {level}
            </Link>
          ))}
        </fieldset>
      </header>

      {nothing ? (
        <EmptyState
          title="Nada con ese tueste todavía"
          message="Probá con otro nivel o mirá el catálogo completo."
        >
          <ButtonLink variant="secondary" to="/catalogo" search={{}}>
            Ver todo
          </ButtonLink>
        </EmptyState>
      ) : (
        <>
          {visibleCareers.length > 0 && (
            <section aria-labelledby="carreras" className="flex flex-col gap-5">
              <h2 id="carreras" className="text-2xl text-ink">
                Carreras
              </h2>
              <div className="grid gap-4 md:grid-cols-2">
                {visibleCareers.map((c) => (
                  <CareerCard key={c.id} career={c} />
                ))}
              </div>
            </section>
          )}
          {visibleCourses.length > 0 && (
            <section aria-labelledby="cursos" className="flex flex-col gap-5">
              <h2 id="cursos" className="text-2xl text-ink">
                Cursos
              </h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {visibleCourses.map((c) => (
                  <CourseCard key={c.id} course={c} />
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  )
}
