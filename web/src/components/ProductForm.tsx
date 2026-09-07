import { useState, type FormEvent } from 'react'
import { Button } from './Button'
import { Field } from './Field'
import { LEVELS } from '@/types/catalog'
import type { ProductInput, ProductStatus } from '@/types/admin'

const STATUSES: { value: ProductStatus; label: string }[] = [
  { value: 'draft', label: 'borrador' },
  { value: 'published', label: 'publicado' },
  { value: 'archived', label: 'archivado' },
]

type Props = {
  initial?: Partial<ProductInput>
  submitLabel: string
  busy?: boolean
  error?: string | null
  onSubmit: (input: ProductInput) => void
  onCancel?: () => void
}

// Formulario compartido de curso y carrera. Precio en USD (catálogo).
export function ProductForm({ initial, submitLabel, busy, error, onSubmit, onCancel }: Props) {
  const [status, setStatus] = useState<ProductStatus>(initial?.status ?? 'draft')
  const [level, setLevel] = useState(initial?.level ?? 'medio')

  function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const f = new FormData(e.currentTarget)
    onSubmit({
      title: String(f.get('title')),
      slug: String(f.get('slug')),
      subtitle: String(f.get('subtitle')),
      description: String(f.get('description')),
      level,
      status,
      price_cents: Math.round(Number(f.get('price')) * 100),
    })
  }

  const select = 'hairline-strong h-11 rounded-control bg-surface-0 px-3 font-mono text-xs text-ink'

  return (
    <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
      <Field label="Título" name="title" defaultValue={initial?.title ?? ''} required />
      <Field label="Slug" name="slug" defaultValue={initial?.slug ?? ''} hint="vacío = se deriva del título" className="font-mono text-xs" />
      <Field label="Subtítulo" name="subtitle" defaultValue={initial?.subtitle ?? ''} />
      <label className="flex flex-col gap-1.5 text-sm">
        <span className="text-ink-soft">Descripción</span>
        <textarea
          name="description"
          defaultValue={initial?.description ?? ''}
          rows={5}
          className="hairline-strong rounded-control bg-surface-0 px-3 py-2 text-ink focus:border-accent"
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Precio (USD)" name="price" type="number" min={0} step="1" defaultValue={initial ? String((initial.price_cents ?? 0) / 100) : ''} className="font-mono text-xs" required />
        <label className="flex flex-col gap-1.5 text-sm">
          <span className="text-ink-soft">Tueste</span>
          <select value={level} onChange={(e) => setLevel(e.target.value as (typeof LEVELS)[number])} className={select}>
            {LEVELS.map((l) => (
              <option key={l} value={l}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1.5 text-sm">
          <span className="text-ink-soft">Estado</span>
          <select value={status} onChange={(e) => setStatus(e.target.value as ProductStatus)} className={select}>
            {STATUSES.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>
        </label>
      </div>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}
      <div className="flex gap-2">
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? 'Guardando…' : submitLabel}
        </Button>
        {onCancel && (
          <Button variant="ghost" onClick={onCancel}>
            Cancelar
          </Button>
        )}
      </div>
    </form>
  )
}
