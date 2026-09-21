import { useQuery, useSuspenseQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { careersQuery, categoriesQuery, coursesQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { LEVELS, type Level } from '@/types/catalog'
import { CareerCard, CourseCard } from '@/components/Cards'
import { EmptyState } from '@/components/PageState'
import { ButtonLink } from '@/components/Button'

export type CatalogSearch = { tueste?: Level; categoria?: string }

// Filtro por tueste. El filtro por tema queda para cuando el catálogo
// tenga un campo de tema (hoy el esquema no lo modela).
export function Catalog({ tueste, categoria }: CatalogSearch) {
  useTitle('Catálogo')
  const { data: careers } = useSuspenseQuery(careersQuery())
  const { data: courses } = useSuspenseQuery(coursesQuery())
  const categories = useQuery(categoriesQuery())

  const match = <T extends { level: Level; category: { slug: string } | null }>(c: T) =>
    (!tueste || c.level === tueste) && (!categoria || c.category?.slug === categoria)
  const visibleCareers = careers.filter(match)
  const visibleCourses = courses.filter(match)
  const nothing = visibleCareers.length === 0 && visibleCourses.length === 0
  const filtered = !!tueste || !!categoria
  // Solo ofrecemos categorías que hoy tienen algo publicado.
  const usable = (categories.data ?? []).filter((cat) =>
    careers.some((c) => c.category?.slug === cat.slug) || courses.some((c) => c.category?.slug === cat.slug),
  )

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
        {usable.length > 1 && (
          <fieldset className="flex flex-wrap items-center gap-2">
            <legend className="sr-only">Filtrar por categoría</legend>
            <span aria-hidden="true" className="mr-1 font-mono text-xs text-ink-faint">
              categoría
            </span>
            <Link to="/catalogo" search={{ tueste }} className={pill(!categoria)} aria-current={!categoria ? 'true' : undefined}>
              todas
            </Link>
            {usable.map((cat) => (
              <Link
                key={cat.slug}
                to="/catalogo"
                search={{ tueste, categoria: cat.slug }}
                className={pill(categoria === cat.slug)}
                aria-current={categoria === cat.slug ? 'true' : undefined}
              >
                {cat.name}
              </Link>
            ))}
          </fieldset>
        )}
        <fieldset className="flex flex-wrap items-center gap-2">
          <legend className="sr-only">Filtrar por tueste</legend>
          <span aria-hidden="true" className="mr-1 font-mono text-xs text-ink-faint">
            tueste
          </span>
          <Link to="/catalogo" search={{ categoria }} className={pill(!tueste)} aria-current={!tueste ? 'true' : undefined}>
            todos
          </Link>
          {LEVELS.map((level) => (
            <Link
              key={level}
              to="/catalogo"
              search={{ tueste: level, categoria }}
              className={pill(tueste === level)}
              aria-current={tueste === level ? 'true' : undefined}
            >
              {level}
            </Link>
          ))}
        </fieldset>
      </header>

      {nothing && !filtered ? (
        <EmptyState title="El primer café se está preparando" message="Todavía no hay contenido publicado. Volvé en unos días." />
      ) : nothing ? (
        <EmptyState
          title="Nada con esos filtros todavía"
          message="Probá con otra combinación o mirá el catálogo completo."
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
