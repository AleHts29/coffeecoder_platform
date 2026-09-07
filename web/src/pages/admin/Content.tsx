import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate } from '@tanstack/react-router'
import { admin, adminCareersQuery, adminCoursesQuery } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { formatPrice } from '@/lib/format'
import { Button } from '@/components/Button'
import { ProductForm } from '@/components/ProductForm'
import { ErrorState, Loading } from '@/components/PageState'
import type { AdminProduct, ProductInput } from '@/types/admin'

export function StatusBadge({ status }: { status: AdminProduct['status'] }) {
  const label = status === 'published' ? 'publicado' : status === 'archived' ? 'archivado' : 'borrador'
  return <span className={'font-mono text-xs ' + (status === 'published' ? 'text-accent' : 'text-ink-faint')}>{label}</span>
}

// Gestión de contenido: carreras y cursos en cualquier estado.
export function AdminContent() {
  useTitle('Admin · Contenido')
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const careers = useQuery(adminCareersQuery())
  const courses = useQuery(adminCoursesQuery())
  const [creating, setCreating] = useState<'course' | 'career' | null>(null)

  const create = useMutation({
    mutationFn: (input: ProductInput) => (creating === 'career' ? admin.createCareer(input) : admin.createCourse(input)),
    onSuccess: (p) => {
      void queryClient.invalidateQueries({ queryKey: ['admin'] })
      setCreating(null)
      void navigate({ to: creating === 'career' ? '/admin/carreras/$id' : '/admin/cursos/$id', params: { id: p.id } })
    },
  })

  if (careers.isPending || courses.isPending) return <Loading />
  if (careers.isError || courses.isError) return <ErrorState message="No pudimos cargar el contenido." onRetry={() => void queryClient.invalidateQueries({ queryKey: ['admin'] })} />

  return (
    <div className="flex flex-col gap-10">
      {creating ? (
        <section className="hairline flex max-w-2xl flex-col gap-4 rounded-card bg-surface-1 p-5">
          <h2 className="text-xl text-ink">{creating === 'career' ? 'Nueva carrera' : 'Nuevo curso'}</h2>
          <ProductForm
            submitLabel="Crear"
            busy={create.isPending}
            error={create.error instanceof ApiError ? create.error.message : null}
            onSubmit={(input) => create.mutate(input)}
            onCancel={() => setCreating(null)}
          />
        </section>
      ) : (
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setCreating('course')}>
            Nuevo curso
          </Button>
          <Button variant="secondary" onClick={() => setCreating('career')}>
            Nueva carrera
          </Button>
        </div>
      )}

      <ProductTable title="Carreras" items={careers.data} to="/admin/carreras/$id" count={(c) => `${c.course_count ?? 0} cursos`} />
      <ProductTable title="Cursos" items={courses.data} to="/admin/cursos/$id" count={(c) => `${c.lesson_count ?? 0} lecciones`} />
    </div>
  )
}

function ProductTable({ title, items, to, count }: { title: string; items: AdminProduct[]; to: '/admin/carreras/$id' | '/admin/cursos/$id'; count: (p: AdminProduct) => string }) {
  return (
    <section aria-labelledby={title} className="flex flex-col gap-3">
      <h2 id={title} className="text-2xl text-ink">
        {title}
      </h2>
      {items.length === 0 ? (
        <p className="text-sm text-ink-soft">Todavía no hay nada acá.</p>
      ) : (
        <div className="hairline overflow-x-auto rounded-card bg-surface-1">
          <table className="w-full text-sm">
            <thead className="text-left font-mono text-xs text-ink-faint">
              <tr className="border-b-[0.5px] border-border">
                <th className="px-4 py-3 font-medium">#</th>
                <th className="px-4 py-3 font-medium">título</th>
                <th className="px-4 py-3 font-medium">tueste</th>
                <th className="px-4 py-3 font-medium">precio</th>
                <th className="px-4 py-3 font-medium">contenido</th>
                <th className="px-4 py-3 font-medium">estado</th>
              </tr>
            </thead>
            <tbody>
              {items.map((p) => (
                <tr key={p.id} className="border-b-[0.5px] border-border last:border-b-0 hover:bg-surface-2">
                  <td className="px-4 py-3 font-mono text-xs text-ink-faint">{p.position}</td>
                  <td className="px-4 py-3">
                    <Link to={to} params={{ id: p.id }} className="text-ink hover:text-accent">
                      {p.title}
                    </Link>
                    <span className="ml-2 font-mono text-xs text-ink-faint">{p.slug}</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-ink-soft">{p.level}</td>
                  <td className="px-4 py-3 font-mono text-xs text-ink">{formatPrice(p.price_cents)}</td>
                  <td className="px-4 py-3 font-mono text-xs text-ink-soft">{count(p)}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={p.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
