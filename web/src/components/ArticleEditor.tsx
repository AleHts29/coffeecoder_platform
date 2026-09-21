import { useRef, useState } from 'react'
import { admin } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { LessonContent } from './LessonContent'
import { Button } from './Button'
import type { AdminDemo } from '@/types/admin'
import type { DemoRef } from '@/types/content'

type Props = {
  value: string
  onChange: (body: string) => void
  demos: AdminDemo[]
}

// Editor de artículo: Markdown a la izquierda, preview a la derecha con
// el mismo componente que ve el alumno. En mobile, tabs.
export function ArticleEditor({ value, onChange, demos }: Props) {
  const area = useRef<HTMLTextAreaElement>(null)
  const file = useRef<HTMLInputElement>(null)
  const [tab, setTab] = useState<'write' | 'preview'>('write')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Las demos del curso, ya firmadas: la preview muestra las que el
  // texto referencia aunque todavía no se haya guardado.
  const refs: DemoRef[] = demos.map((d) => ({ slug: d.slug, title: d.title, height_px: d.height_px, frame_url: d.frame_url }))

  const insert = (text: string) => {
    const el = area.current
    if (!el) {
      onChange(value + text)
      return
    }
    const start = el.selectionStart
    const end = el.selectionEnd
    const next = value.slice(0, start) + text + value.slice(end)
    onChange(next)
    requestAnimationFrame(() => {
      el.focus()
      el.selectionStart = el.selectionEnd = start + text.length
    })
  }

  async function onFile(f: File) {
    setBusy(true)
    setError(null)
    try {
      const { url } = await admin.uploadImage(f)
      insert(`\n![${f.name.replace(/\.[^.]+$/, '')}](${url})\n`)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'no pudimos subir la imagen')
    } finally {
      setBusy(false)
    }
  }

  const tabBtn = (id: 'write' | 'preview', label: string) => (
    <button
      type="button"
      role="tab"
      aria-selected={tab === id}
      onClick={() => setTab(id)}
      className={'-mb-px border-b-2 px-3 py-2 text-sm ' + (tab === id ? 'border-accent text-ink' : 'border-transparent text-ink-soft hover:text-ink')}
    >
      {label}
    </button>
  )

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <label className="flex items-center gap-2 text-sm text-ink-soft">
          <span className="sr-only">Insertar demo</span>
          <select
            aria-label="Insertar demo"
            value=""
            onChange={(e) => {
              if (e.target.value) insert(`\n::demo[${e.target.value}]\n`)
              e.target.value = ''
            }}
            disabled={demos.length === 0}
            className="hairline-strong h-9 rounded-control bg-surface-0 px-2 font-mono text-xs text-ink disabled:text-ink-disabled"
          >
            <option value="">{demos.length ? 'Insertar demo…' : 'sin demos en este curso'}</option>
            {demos.map((d) => (
              <option key={d.id} value={d.slug}>
                {d.title} ({d.slug})
              </option>
            ))}
          </select>
        </label>
        <input
          ref={file}
          type="file"
          accept="image/*"
          className="sr-only"
          aria-label="Elegir imagen"
          onChange={(e) => {
            const f = e.target.files?.[0]
            if (f) void onFile(f)
            e.target.value = ''
          }}
        />
        <Button variant="ghost" className="h-9" onClick={() => file.current?.click()} disabled={busy}>
          {busy ? 'Subiendo…' : 'Subir imagen'}
        </Button>
        <span className="flex-1" />
        <div role="tablist" className="flex gap-1 border-b-[0.5px] border-border lg:hidden">
          {tabBtn('write', 'Escribir')}
          {tabBtn('preview', 'Vista previa')}
        </div>
      </div>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}

      <div className="grid gap-4 lg:grid-cols-2">
        <label className={(tab === 'write' ? 'flex' : 'hidden') + ' flex-col gap-1.5 text-sm lg:flex'}>
          <span className="text-ink-soft">Markdown</span>
          <textarea
            ref={area}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            rows={20}
            spellCheck
            className="hairline-strong min-h-[420px] rounded-control bg-surface-0 px-3 py-2 font-mono text-[13px] leading-relaxed text-ink focus:border-accent"
          />
        </label>
        <div className={(tab === 'preview' ? 'flex' : 'hidden') + ' flex-col gap-1.5 text-sm lg:flex'}>
          <span className="text-ink-soft">Vista previa</span>
          <div className="hairline min-h-[420px] overflow-y-auto rounded-control bg-surface-0 p-4">
            {value.trim() ? (
              <LessonContent body={value} demos={refs} showMissing />
            ) : (
              <p className="text-sm text-ink-faint">Escribí algo para ver la vista previa.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
