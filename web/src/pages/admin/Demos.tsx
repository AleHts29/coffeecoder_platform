import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { admin, adminDemosQuery } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { Button } from '@/components/Button'
import { Field } from '@/components/Field'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { ErrorState, Loading } from '@/components/PageState'
import { AdjustmentsIcon } from '@/components/icons'
import type { AdminDemo, AdminDemoDetail, DemoInput } from '@/types/admin'

// Biblioteca de demos de un curso: listar, crear, editar y previsualizar
// con la URL firmada que devuelve el guardado.
export function DemoLibrary({ courseId }: { courseId: string }) {
  const queryClient = useQueryClient()
  const demos = useQuery(adminDemosQuery(courseId))
  const [editing, setEditing] = useState<AdminDemoDetail | 'new' | null>(null)
  const [target, setTarget] = useState<AdminDemo | null>(null)
  const [error, setError] = useState<string | null>(null)
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin'] })

  const open = useMutation({
    mutationFn: (id: string) => admin.getDemo(id),
    onSuccess: (d) => setEditing(d),
    onError: (e) => setError(e instanceof ApiError ? e.message : 'no pudimos abrir la demo'),
  })
  const remove = useMutation({
    mutationFn: (id: string) => admin.deleteDemo(id),
    onSuccess: () => {
      setTarget(null)
      void invalidate()
    },
    onError: (e) => {
      setTarget(null)
      setError(e instanceof ApiError ? e.message : 'no pudimos borrar la demo')
    },
  })

  if (demos.isPending) return <Loading />
  if (demos.isError) return <ErrorState message="No pudimos cargar las demos." onRetry={() => void demos.refetch()} />

  return (
    <section aria-labelledby="demos" className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col gap-1">
          <h2 id="demos" className="text-xl text-ink">
            Demos
          </h2>
          <p className="text-sm text-ink-soft">
            Gráficos interactivos del curso. Se insertan en un artículo con <code className="font-mono text-xs text-ink">::demo[slug]</code>.
          </p>
        </div>
        {!editing && (
          <Button variant="secondary" onClick={() => setEditing('new')}>
            Nueva demo
          </Button>
        )}
      </div>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}

      {editing ? (
        <DemoForm
          courseId={courseId}
          demo={editing === 'new' ? null : editing}
          onDone={() => {
            setEditing(null)
            void invalidate()
          }}
          onCancel={() => setEditing(null)}
        />
      ) : demos.data.length === 0 ? (
        <p className="text-sm text-ink-faint">Este curso todavía no tiene demos.</p>
      ) : (
        <ul className="hairline flex flex-col rounded-card bg-surface-1">
          {demos.data.map((d) => (
            <li key={d.id} className="flex flex-wrap items-center gap-3 border-b-[0.5px] border-border p-3 last:border-b-0">
              <AdjustmentsIcon size={16} className="shrink-0 text-accent" />
              <span className="text-sm text-ink">{d.title}</span>
              <span className="font-mono text-xs text-ink-faint">{d.slug}</span>
              <span className="font-mono text-xs text-ink-faint">
                {d.height_px}px · {Math.round(d.size_bytes / 1024)} KB
              </span>
              <span className="flex-1" />
              <span className="font-mono text-xs text-ink-faint">
                {d.used_by.length === 0 ? 'sin usar' : `en ${d.used_by.length} ${d.used_by.length === 1 ? 'lección' : 'lecciones'}`}
              </span>
              <Button variant="ghost" className="h-9" onClick={() => open.mutate(d.id)}>
                Editar
              </Button>
              <Button variant="destructive" className="h-9" onClick={() => setTarget(d)}>
                Borrar
              </Button>
            </li>
          ))}
        </ul>
      )}

      <ConfirmDialog
        open={!!target}
        title="¿Borrar esta demo?"
        message={
          target && target.used_by.length > 0
            ? `La usan ${target.used_by.length} ${target.used_by.length === 1 ? 'lección' : 'lecciones'}: ${target.used_by.map((l) => l.title).join(', ')}. Ahí va a dejar de aparecer.`
            : 'No la usa ninguna lección.'
        }
        confirmLabel="Borrar demo"
        busy={remove.isPending}
        onConfirm={() => target && remove.mutate(target.id)}
        onCancel={() => setTarget(null)}
      />
    </section>
  )
}

function DemoForm({ courseId, demo, onDone, onCancel }: { courseId: string; demo: AdminDemoDetail | null; onDone: () => void; onCancel: () => void }) {
  const [html, setHtml] = useState(demo?.html ?? '')
  const [preview, setPreview] = useState<AdminDemoDetail | null>(demo)
  const [error, setError] = useState<string | null>(null)

  const save = useMutation({
    mutationFn: (input: DemoInput) => (demo ? admin.updateDemo(demo.id, input) : admin.createDemo(courseId, input)),
    onSuccess: (d) => {
      setPreview(d)
      setError(null)
    },
    onError: (e) => setError(e instanceof ApiError ? e.message : 'no pudimos guardar la demo'),
  })

  return (
    <div className="hairline flex flex-col gap-4 rounded-card bg-surface-1 p-5">
      <h3 className="text-lg text-ink">{demo ? 'Editar demo' : 'Nueva demo'}</h3>
      <form
        className="flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault()
          const f = new FormData(e.currentTarget)
          save.mutate({ title: String(f.get('title')), slug: String(f.get('slug')), height_px: Number(f.get('height')), html })
        }}
      >
        <div className="grid gap-4 sm:grid-cols-[1fr_1fr_140px]">
          <Field label="Título" name="title" defaultValue={demo?.title ?? ''} required />
          <Field label="Slug" name="slug" defaultValue={demo?.slug ?? ''} hint="minúsculas y guiones" className="font-mono text-xs" required />
          <Field label="Alto (px)" name="height" type="number" min={120} max={1600} step={10} defaultValue={String(demo?.height_px ?? 420)} className="font-mono text-xs" required />
        </div>
        <label className="flex flex-col gap-1.5 text-sm">
          <span className="text-ink-soft">HTML de la demo</span>
          <textarea
            value={html}
            onChange={(e) => setHtml(e.target.value)}
            rows={14}
            spellCheck={false}
            placeholder="<!doctype html>…"
            className="hairline-strong rounded-control bg-surface-0 px-3 py-2 font-mono text-[13px] text-ink focus:border-accent"
          />
          <span className="font-mono text-xs text-ink-faint">
            un solo archivo, sin red ni storage · máx 200 KB · ver docs/DEMOS.md
          </span>
        </label>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="flex gap-2">
          <Button variant="primary" type="submit" disabled={save.isPending}>
            {save.isPending ? 'Guardando…' : 'Guardar y previsualizar'}
          </Button>
          <Button variant="ghost" onClick={onDone}>
            Listo
          </Button>
          <Button variant="ghost" onClick={onCancel}>
            Cancelar
          </Button>
        </div>
      </form>

      {preview && (
        <figure className="flex flex-col gap-2">
          <figcaption className="flex items-center gap-2 font-mono text-xs text-ink-faint">
            <AdjustmentsIcon size={16} className="text-accent" /> vista previa
          </figcaption>
          <iframe
            key={preview.frame_url}
            src={preview.frame_url}
            title={preview.title}
            height={preview.height_px}
            sandbox="allow-scripts"
            className="w-full rounded-control border-0 bg-surface-0"
          />
        </figure>
      )}
    </div>
  )
}
