import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { admin, adminCareerQuery, adminCoursesQuery, move } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { pad2 } from '@/lib/format'
import { Button, ButtonLink } from '@/components/Button'
import { ProductForm } from '@/components/ProductForm'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { ErrorState, Loading } from '@/components/PageState'
import { StatusBadge } from './Content'

// Editor de carrera: datos y "el camino" (secuencia de cursos).
export function CareerEditor({ id }: { id: string }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const career = useQuery(adminCareerQuery(id))
  const courses = useQuery(adminCoursesQuery())
  useTitle(career.data ? `Admin · ${career.data.title}` : 'Admin · Carrera')
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin'] })
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const fail = (err: unknown) => setMsg(err instanceof ApiError ? err.message : 'algo salió mal, reintentá')

  const save = useMutation({ mutationFn: (input: Parameters<typeof admin.updateCareer>[1]) => admin.updateCareer(id, input), onSuccess: () => { setMsg('Guardado.'); void invalidate() }, onError: fail })
  const setPath = useMutation({ mutationFn: (ids: string[]) => admin.setCareerCourses(id, ids), onSuccess: () => void invalidate(), onError: fail })
  const remove = useMutation({ mutationFn: () => admin.deleteCareer(id), onSuccess: () => void navigate({ to: '/admin/contenido' }), onError: fail })

  if (career.isPending || courses.isPending) return <Loading />
  if (career.isError || courses.isError) return <ErrorState message="No encontramos esa carrera." onRetry={() => void invalidate()} />
  const c = career.data
  const pathIds = c.courses.map((x) => x.id)
  const available = courses.data.filter((x) => !pathIds.includes(x.id))

  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <p className="font-mono text-xs text-ink-faint">
            carrera · <StatusBadge status={c.status} />
          </p>
          <h1 className="text-3xl text-ink">{c.title}</h1>
        </div>
        <div className="flex gap-2">
          {c.status === 'published' && (
            <ButtonLink variant="ghost" to="/carreras/$slug" params={{ slug: c.slug }}>
              Ver publicada
            </ButtonLink>
          )}
          <Button variant="destructive" onClick={() => setConfirmDelete(true)}>
            Borrar carrera
          </Button>
        </div>
      </header>

      {msg && (
        <p role="status" className={'text-sm ' + (msg === 'Guardado.' ? 'text-accent' : 'text-danger')}>
          {msg}
        </p>
      )}

      <section aria-labelledby="datos" className="hairline max-w-2xl rounded-card bg-surface-1 p-5">
        <h2 id="datos" className="mb-4 text-xl text-ink">
          Datos
        </h2>
        <ProductForm initial={c} submitLabel="Guardar" busy={save.isPending} onSubmit={(input) => save.mutate(input)} />
      </section>

      <section aria-labelledby="camino" className="flex max-w-2xl flex-col gap-4">
        <div className="flex flex-col gap-1">
          <h2 id="camino" className="text-xl text-ink">
            El camino
          </h2>
          <p className="text-sm text-ink-soft">Los cursos en el orden en que se cursan. Comprar la carrera da acceso a todos, incluso a los que agregues después.</p>
        </div>
        {c.courses.length === 0 && <p className="text-sm text-ink-faint">Todavía no tiene cursos.</p>}
        <ol className="hairline flex flex-col rounded-card bg-surface-1">
          {c.courses.map((course, i) => (
            <li key={course.id} className="flex items-center gap-3 border-b-[0.5px] border-border p-3 last:border-b-0">
              <span className="font-mono text-xs text-ink-faint">{pad2(i + 1)}</span>
              <span className="flex-1 text-sm text-ink">
                {course.title} <StatusBadge status={course.status} />
              </span>
              <Button variant="ghost" className="h-9 w-9 px-0" disabled={i === 0} aria-label="Subir curso" onClick={() => setPath.mutate(move(pathIds, i, i - 1))}>
                ↑
              </Button>
              <Button variant="ghost" className="h-9 w-9 px-0" disabled={i === c.courses.length - 1} aria-label="Bajar curso" onClick={() => setPath.mutate(move(pathIds, i, i + 1))}>
                ↓
              </Button>
              <Button variant="ghost" className="h-9" onClick={() => setPath.mutate(pathIds.filter((x) => x !== course.id))}>
                Quitar
              </Button>
            </li>
          ))}
        </ol>
        {available.length > 0 && (
          <form
            className="flex gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              const v = String(new FormData(e.currentTarget).get('course'))
              if (v) setPath.mutate([...pathIds, v])
            }}
          >
            <select name="course" aria-label="Curso a agregar" className="hairline-strong h-11 flex-1 rounded-control bg-surface-0 px-3 text-sm text-ink">
              {available.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.title} ({x.status === 'published' ? 'publicado' : x.status})
                </option>
              ))}
            </select>
            <Button variant="secondary" type="submit" disabled={setPath.isPending}>
              Agregar al camino
            </Button>
          </form>
        )}
      </section>

      <ConfirmDialog open={confirmDelete} title="¿Borrar esta carrera?" message="Los cursos siguen existiendo; se pierde solo la secuencia. Quienes la compraron pierden el acceso por carrera." confirmLabel="Borrar carrera" busy={remove.isPending} onConfirm={() => remove.mutate()} onCancel={() => setConfirmDelete(false)} />
    </div>
  )
}
