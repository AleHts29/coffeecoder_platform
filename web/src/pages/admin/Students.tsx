import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { admin, adminCareersQuery, adminCoursesQuery, adminStudentQuery, adminStudentsQuery } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { Button, ButtonLink } from '@/components/Button'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { ErrorState, Loading } from '@/components/PageState'
import type { StudentEnrollment } from '@/types/admin'

// Alumnos: búsqueda por email o nombre.
export function AdminStudents({ q }: { q: string }) {
  useTitle('Admin · Alumnos')
  const students = useQuery(adminStudentsQuery(q))
  const [value, setValue] = useState(q)

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-3xl text-ink">Alumnos</h1>
      </header>
      <form
        role="search"
        className="flex max-w-lg gap-2"
        onSubmit={(e) => {
          e.preventDefault()
        }}
      >
        <input
          type="search"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder="Buscar por email o nombre"
          aria-label="Buscar alumnos"
          className="hairline-strong h-11 flex-1 rounded-control bg-surface-0 px-3 text-sm text-ink placeholder:text-ink-faint"
        />
        <ButtonLink variant="secondary" to="/admin/alumnos" search={{ q: value }}>
          Buscar
        </ButtonLink>
      </form>
      {students.isPending ? (
        <Loading />
      ) : students.isError ? (
        <ErrorState message="No pudimos cargar los alumnos." onRetry={() => void students.refetch()} />
      ) : students.data.length === 0 ? (
        <p className="text-sm text-ink-soft">Nadie coincide con esa búsqueda.</p>
      ) : (
        <div className="hairline overflow-x-auto rounded-card bg-surface-1">
          <table className="w-full text-sm">
            <thead className="text-left font-mono text-xs text-ink-faint">
              <tr className="border-b-[0.5px] border-border">
                <th className="px-4 py-3 font-medium">alumno</th>
                <th className="px-4 py-3 font-medium">alta</th>
                <th className="px-4 py-3 font-medium">accesos</th>
                <th className="px-4 py-3 font-medium">rol</th>
              </tr>
            </thead>
            <tbody>
              {students.data.map((s) => (
                <tr key={s.id} className="border-b-[0.5px] border-border last:border-b-0 hover:bg-surface-2">
                  <td className="px-4 py-3">
                    <Link to="/admin/alumnos/$id" params={{ id: s.id }} className="text-ink hover:text-accent">
                      {s.name || '—'}
                    </Link>
                    <span className="block font-mono text-xs text-ink-faint">{s.email}</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-ink-soft">{new Date(s.created_at).toLocaleDateString('es-AR')}</td>
                  <td className="px-4 py-3 font-mono text-xs text-ink">{s.active_enrollments}</td>
                  <td className="px-4 py-3 font-mono text-xs text-ink-faint">{s.role}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// Detalle: enrollments vigentes y revocados, alta manual, revocación.
export function AdminStudent({ id }: { id: string }) {
  const queryClient = useQueryClient()
  const student = useQuery(adminStudentQuery(id))
  const careers = useQuery(adminCareersQuery())
  const courses = useQuery(adminCoursesQuery())
  useTitle(student.data ? `Admin · ${student.data.email}` : 'Admin · Alumno')
  const [scope, setScope] = useState<'career' | 'course'>('career')
  const [target, setTarget] = useState<StudentEnrollment | null>(null)
  const [error, setError] = useState<string | null>(null)
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin', 'students'] })
  const fail = (e: unknown) => setError(e instanceof ApiError ? e.message : 'algo salió mal, reintentá')

  const enroll = useMutation({ mutationFn: (scopeId: string) => admin.enroll(id, scope, scopeId), onSuccess: () => { setError(null); void invalidate() }, onError: fail })
  const revoke = useMutation({ mutationFn: (eid: string) => admin.revoke(eid), onSuccess: () => { setTarget(null); void invalidate() }, onError: (e) => { setTarget(null); fail(e) } })

  if (student.isPending || careers.isPending || courses.isPending) return <Loading />
  if (student.isError || careers.isError || courses.isError) return <ErrorState message="No encontramos ese alumno." onRetry={() => void invalidate()} />
  const s = student.data
  const options = scope === 'career' ? careers.data : courses.data

  return (
    <div className="flex flex-col gap-8">
      <header className="flex flex-col gap-1">
        <p className="font-mono text-xs text-ink-faint">alumno · {s.role}</p>
        <h1 className="text-3xl text-ink">{s.name || s.email}</h1>
        <p className="font-mono text-sm text-ink-soft">{s.email}</p>
      </header>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}

      <section aria-labelledby="accesos" className="flex flex-col gap-3">
        <h2 id="accesos" className="text-xl text-ink">
          Accesos
        </h2>
        {s.enrollments.length === 0 ? (
          <p className="text-sm text-ink-soft">No tiene accesos.</p>
        ) : (
          <ul className="hairline flex flex-col rounded-card bg-surface-1">
            {s.enrollments.map((e) => (
              <li key={e.id} className="flex flex-wrap items-center gap-3 border-b-[0.5px] border-border p-3 last:border-b-0">
                <span className="font-mono text-xs text-ink-faint">{e.scope === 'career' ? 'carrera' : 'curso'}</span>
                <span className="flex-1 text-sm text-ink">{e.product_title || e.scope_id}</span>
                <span className="font-mono text-xs text-ink-faint">
                  {e.order_id ? 'compra' : 'manual'} · {new Date(e.activated_at).toLocaleDateString('es-AR')}
                </span>
                {e.revoked_at ? (
                  <span className="font-mono text-xs text-ink-disabled">revocado</span>
                ) : (
                  <Button variant="destructive" className="h-9" onClick={() => setTarget(e)}>
                    Revocar
                  </Button>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="alta" className="hairline flex max-w-xl flex-col gap-3 rounded-card bg-surface-1 p-5">
        <h2 id="alta" className="text-xl text-ink">
          Dar acceso manual
        </h2>
        <p className="text-sm text-ink-soft">Para becas, cortesías o ventas fuera de la plataforma. No genera orden.</p>
        <form
          className="flex flex-col gap-3 sm:flex-row"
          onSubmit={(e) => {
            e.preventDefault()
            const v = String(new FormData(e.currentTarget).get('product'))
            if (v) enroll.mutate(v)
          }}
        >
          <select value={scope} onChange={(e) => setScope(e.target.value as 'career' | 'course')} aria-label="Tipo" className="hairline-strong h-11 rounded-control bg-surface-0 px-3 font-mono text-xs text-ink">
            <option value="career">carrera</option>
            <option value="course">curso</option>
          </select>
          <select name="product" aria-label="Producto" className="hairline-strong h-11 flex-1 rounded-control bg-surface-0 px-3 text-sm text-ink">
            {options.map((p) => (
              <option key={p.id} value={p.id}>
                {p.title}
              </option>
            ))}
          </select>
          <Button variant="primary" type="submit" disabled={enroll.isPending || options.length === 0}>
            Dar acceso
          </Button>
        </form>
      </section>

      <ConfirmDialog open={!!target} title="¿Revocar este acceso?" message={target ? `${s.email} deja de ver ${target.product_title}. Se puede volver a dar acceso después.` : ''} confirmLabel="Revocar" busy={revoke.isPending} onConfirm={() => target && revoke.mutate(target.id)} onCancel={() => setTarget(null)} />
    </div>
  )
}
