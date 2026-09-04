import { ButtonLink } from './Button'
import { ProgressBar } from './ProgressBar'
import { CheckIcon } from './icons'

type Props = {
  kind: 'carrera' | 'curso'
  completed: number
  total: number
  continueTo: { slug: string; lessonId: string } | null
}

// Reemplaza la card de compra cuando el alumno ya tiene acceso.
// Único primario de la vista: Continuar.
export function AccessCard({ kind, completed, total, continueTo }: Props) {
  const pct = total > 0 ? (completed / total) * 100 : 0
  return (
    <aside aria-label={`Tu ${kind}`} className="hairline flex flex-col gap-4 rounded-card bg-surface-1 p-5 lg:sticky lg:top-20">
      <p className="inline-flex items-center gap-2 font-mono text-xs text-accent">
        <CheckIcon size={14} /> ya tenés {kind === 'carrera' ? 'esta carrera' : 'este curso'}
      </p>
      <ProgressBar value={pct} label={`Progreso de tu ${kind}`} />
      <p className="font-mono text-xs text-ink-faint">
        {completed}/{total} lecciones
      </p>
      {continueTo && (
        <ButtonLink
          variant="primary"
          to="/cursos/$slug/lecciones/$lessonId"
          params={continueTo}
          search={{}}
          className="w-full"
        >
          {completed === 0 ? 'Empezar' : completed >= total ? 'Repasar' : 'Continuar'}
        </ButtonLink>
      )}
    </aside>
  )
}
