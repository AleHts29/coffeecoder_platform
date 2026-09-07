import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { admin, adminCourseQuery, move } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { formatClock, pad2 } from '@/lib/format'
import { Button, ButtonLink } from '@/components/Button'
import { Field } from '@/components/Field'
import { ProductForm } from '@/components/ProductForm'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { VideoUpload } from '@/components/VideoUpload'
import { ErrorState, Loading } from '@/components/PageState'
import { StatusBadge } from './Content'
import type { AdminLesson, AdminModule, LessonInput } from '@/types/admin'

// Editor de curso: datos, módulos y lecciones con reordenamiento
// (botones subir/bajar: accesibles y sin librería), upload de video.
export function CourseEditor({ id }: { id: string }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const course = useQuery(adminCourseQuery(id))
  useTitle(course.data ? `Admin · ${course.data.title}` : 'Admin · Curso')
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin'] })
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const fail = (err: unknown) => setMsg(err instanceof ApiError ? err.message : 'algo salió mal, reintentá')

  const save = useMutation({ mutationFn: (input: Parameters<typeof admin.updateCourse>[1]) => admin.updateCourse(id, input), onSuccess: () => { setMsg('Guardado.'); void invalidate() }, onError: fail })
  const remove = useMutation({ mutationFn: () => admin.deleteCourse(id), onSuccess: () => void navigate({ to: '/admin/contenido' }), onError: (e) => { setConfirmDelete(false); fail(e) } })
  const addModule = useMutation({ mutationFn: (title: string) => admin.createModule(id, title), onSuccess: () => void invalidate(), onError: fail })
  const reorderModules = useMutation({ mutationFn: (ids: string[]) => admin.reorderModules(id, ids), onSuccess: () => void invalidate(), onError: fail })

  if (course.isPending) return <Loading />
  if (course.isError) return <ErrorState message="No encontramos ese curso." onRetry={() => void course.refetch()} />
  const c = course.data

  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-col gap-1">
          <p className="font-mono text-xs text-ink-faint">
            curso · <StatusBadge status={c.status} />
          </p>
          <h1 className="text-3xl text-ink">{c.title}</h1>
        </div>
        <div className="flex gap-2">
          {c.status === 'published' && (
            <ButtonLink variant="ghost" to="/cursos/$slug" params={{ slug: c.slug }}>
              Ver publicado
            </ButtonLink>
          )}
          <Button variant="destructive" onClick={() => setConfirmDelete(true)}>
            Borrar curso
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

      <section aria-labelledby="curricula" className="flex flex-col gap-4">
        <h2 id="curricula" className="text-xl text-ink">
          Currícula
        </h2>
        {c.modules.map((m, i) => (
          <ModuleCard
            key={m.id}
            module={m}
            courseId={id}
            first={i === 0}
            last={i === c.modules.length - 1}
            onMove={(dir) => reorderModules.mutate(move(c.modules.map((x) => x.id), i, i + dir))}
            onError={fail}
          />
        ))}
        <InlineAdd label="Nuevo módulo" placeholder="Título del módulo" busy={addModule.isPending} onAdd={(title) => addModule.mutate(title)} />
      </section>

      <ConfirmDialog
        open={confirmDelete}
        title="¿Borrar este curso?"
        message="Se borran sus módulos, lecciones y el progreso de los alumnos. Si forma parte de una carrera, primero sacalo del camino."
        confirmLabel="Borrar curso"
        busy={remove.isPending}
        onConfirm={() => remove.mutate()}
        onCancel={() => setConfirmDelete(false)}
      />
    </div>
  )
}

function ModuleCard({ module, courseId, first, last, onMove, onError }: { module: AdminModule; courseId: string; first: boolean; last: boolean; onMove: (dir: -1 | 1) => void; onError: (e: unknown) => void }) {
  const queryClient = useQueryClient()
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin', 'courses', courseId] })
  const [editing, setEditing] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const rename = useMutation({ mutationFn: (title: string) => admin.updateModule(module.id, title), onSuccess: () => { setEditing(false); void invalidate() }, onError })
  const remove = useMutation({ mutationFn: () => admin.deleteModule(module.id), onSuccess: () => void invalidate(), onError })
  const addLesson = useMutation({ mutationFn: (input: LessonInput) => admin.createLesson(module.id, input), onSuccess: () => void invalidate(), onError })
  const reorder = useMutation({ mutationFn: (ids: string[]) => admin.reorderLessons(module.id, ids), onSuccess: () => void invalidate(), onError })

  return (
    <div className="hairline flex flex-col rounded-card bg-surface-1">
      <div className="flex flex-wrap items-center gap-2 border-b-[0.5px] border-border p-3">
        <span className="font-mono text-xs text-ink-faint">módulo {pad2(module.position)}</span>
        {editing ? (
          <form
            className="flex flex-1 gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              rename.mutate(String(new FormData(e.currentTarget).get('title')))
            }}
          >
            <input name="title" defaultValue={module.title} aria-label="Título del módulo" className="hairline-strong h-9 flex-1 rounded-control bg-surface-0 px-3 text-sm text-ink" autoFocus />
            <Button variant="secondary" type="submit" className="h-9">
              Guardar
            </Button>
            <Button variant="ghost" className="h-9" onClick={() => setEditing(false)}>
              Cancelar
            </Button>
          </form>
        ) : (
          <button type="button" onClick={() => setEditing(true)} className="flex-1 text-left text-ink hover:text-accent" title="Renombrar">
            {module.title}
          </button>
        )}
        <MoveButtons first={first} last={last} onMove={onMove} label="módulo" />
        <Button variant="destructive" className="h-9" onClick={() => setConfirm(true)}>
          Borrar
        </Button>
      </div>
      <ol className="flex flex-col">
        {module.lessons.map((l, i) => (
          <LessonRow
            key={l.id}
            lesson={l}
            courseId={courseId}
            first={i === 0}
            last={i === module.lessons.length - 1}
            onMove={(dir) => reorder.mutate(move(module.lessons.map((x) => x.id), i, i + dir))}
            onError={onError}
          />
        ))}
      </ol>
      <div className="p-3">
        <LessonForm submitLabel="Agregar lección" busy={addLesson.isPending} onSubmit={(input) => addLesson.mutate(input)} />
      </div>
      <ConfirmDialog open={confirm} title="¿Borrar este módulo?" message={`Se borran sus ${module.lessons.length} lecciones y sus videos quedan huérfanos en el provider.`} confirmLabel="Borrar módulo" busy={remove.isPending} onConfirm={() => remove.mutate()} onCancel={() => setConfirm(false)} />
    </div>
  )
}

function LessonRow({ lesson, courseId, first, last, onMove, onError }: { lesson: AdminLesson; courseId: string; first: boolean; last: boolean; onMove: (dir: -1 | 1) => void; onError: (e: unknown) => void }) {
  const queryClient = useQueryClient()
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin', 'courses', courseId] })
  const [editing, setEditing] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const update = useMutation({ mutationFn: (input: LessonInput) => admin.updateLesson(lesson.id, input), onSuccess: () => { setEditing(false); void invalidate() }, onError })
  const remove = useMutation({ mutationFn: () => admin.deleteLesson(lesson.id), onSuccess: () => void invalidate(), onError })

  return (
    <li className="flex flex-col gap-2 border-b-[0.5px] border-border p-3 last:border-b-0">
      <div className="flex flex-wrap items-center gap-2">
        <span className="w-6 font-mono text-xs text-ink-faint">{pad2(lesson.position)}</span>
        <span className="flex-1 text-sm text-ink">
          {lesson.title}
          {lesson.is_free_sample && <span className="ml-2 font-mono text-xs text-accent">gratis</span>}
        </span>
        <span className="font-mono text-xs text-ink-faint">{formatClock(lesson.duration_s)}</span>
        <MoveButtons first={first} last={last} onMove={onMove} label="lección" />
        <Button variant="ghost" className="h-9" onClick={() => setEditing((e) => !e)}>
          {editing ? 'Cerrar' : 'Editar'}
        </Button>
        <Button variant="destructive" className="h-9" onClick={() => setConfirm(true)}>
          Borrar
        </Button>
      </div>
      <div className="pl-8">
        <VideoUpload lessonId={lesson.id} courseId={courseId} status={lesson.video_status} />
      </div>
      {editing && (
        <div className="pl-8">
          <LessonForm initial={lesson} submitLabel="Guardar lección" busy={update.isPending} onSubmit={(input) => update.mutate(input)} />
        </div>
      )}
      <ConfirmDialog open={confirm} title="¿Borrar esta lección?" message="Se pierde el progreso de los alumnos en ella." confirmLabel="Borrar lección" busy={remove.isPending} onConfirm={() => remove.mutate()} onCancel={() => setConfirm(false)} />
    </li>
  )
}

function LessonForm({ initial, submitLabel, busy, onSubmit }: { initial?: AdminLesson; submitLabel: string; busy: boolean; onSubmit: (input: LessonInput) => void }) {
  function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const f = new FormData(e.currentTarget)
    onSubmit({
      title: String(f.get('title')),
      description: String(f.get('description')),
      duration_s: Math.round(Number(f.get('minutes') || 0) * 60),
      is_free_sample: f.get('free') === 'on',
    })
    if (!initial) e.currentTarget.reset()
  }
  return (
    <form onSubmit={submit} className="grid gap-3 sm:grid-cols-[1fr_120px_auto_auto]" noValidate>
      <Field label="Título" name="title" defaultValue={initial?.title ?? ''} required />
      <Field label="Minutos" name="minutes" type="number" min={0} step="0.5" defaultValue={initial ? String(Math.round(initial.duration_s / 6) / 10) : ''} className="font-mono text-xs" hint="la duración real la trae el video" />
      <label className="flex items-end gap-2 pb-3 text-sm text-ink-soft">
        <input type="checkbox" name="free" defaultChecked={initial?.is_free_sample} className="size-4 accent-accent" /> gratis
      </label>
      <div className="flex items-end pb-0.5">
        <Button variant="secondary" type="submit" disabled={busy}>
          {submitLabel}
        </Button>
      </div>
      <label className="flex flex-col gap-1.5 text-sm sm:col-span-4">
        <span className="text-ink-soft">Resumen</span>
        <textarea name="description" defaultValue={initial?.description ?? ''} rows={2} className="hairline-strong rounded-control bg-surface-0 px-3 py-2 text-ink" />
      </label>
    </form>
  )
}

function MoveButtons({ first, last, onMove, label }: { first: boolean; last: boolean; onMove: (dir: -1 | 1) => void; label: string }) {
  return (
    <span className="flex gap-1">
      <Button variant="ghost" className="h-9 w-9 px-0" disabled={first} onClick={() => onMove(-1)} aria-label={`Subir ${label}`}>
        ↑
      </Button>
      <Button variant="ghost" className="h-9 w-9 px-0" disabled={last} onClick={() => onMove(1)} aria-label={`Bajar ${label}`}>
        ↓
      </Button>
    </span>
  )
}

export function InlineAdd({ label, placeholder, busy, onAdd }: { label: string; placeholder: string; busy: boolean; onAdd: (value: string) => void }) {
  return (
    <form
      className="flex gap-2"
      onSubmit={(e) => {
        e.preventDefault()
        const v = String(new FormData(e.currentTarget).get('value')).trim()
        if (v) onAdd(v)
        e.currentTarget.reset()
      }}
    >
      <input name="value" placeholder={placeholder} aria-label={label} className="hairline-strong h-11 flex-1 rounded-control bg-surface-0 px-3 text-sm text-ink placeholder:text-ink-faint" />
      <Button variant="secondary" type="submit" disabled={busy}>
        {label}
      </Button>
    </form>
  )
}
