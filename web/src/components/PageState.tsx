import { Button, ButtonLink } from './Button'

// Estados de página consistentes: cargando, error accionable, vacío con
// invitación. Voz de marca: directo, sin lamento.

export function Loading({ label = 'Cargando' }: { label?: string }) {
  return (
    <div role="status" aria-live="polite" className="flex flex-col gap-3 py-10">
      <span className="sr-only">{label}…</span>
      <div aria-hidden="true" className="h-4 w-40 animate-pulse rounded-control bg-surface-2" />
      <div aria-hidden="true" className="h-8 w-2/3 animate-pulse rounded-control bg-surface-2" />
      <div aria-hidden="true" className="h-4 w-1/2 animate-pulse rounded-control bg-surface-2" />
    </div>
  )
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="hairline flex flex-col items-start gap-4 rounded-card bg-surface-1 p-6">
      <div className="flex flex-col gap-1">
        <h2 className="text-lg text-ink">No pudimos cargar esto</h2>
        <p className="text-sm text-ink-soft">{message}</p>
      </div>
      {onRetry && (
        <Button variant="secondary" onClick={onRetry}>
          Reintentar
        </Button>
      )}
    </div>
  )
}

export function NotFoundState({ title, message }: { title: string; message: string }) {
  return (
    <div className="flex flex-col items-start gap-4 py-10">
      <p className="font-mono text-xs text-ink-faint">404</p>
      <h1 className="text-3xl text-ink">{title}</h1>
      <p className="max-w-prose text-ink-soft">{message}</p>
      <ButtonLink variant="secondary" to="/catalogo">
        Ir al catálogo
      </ButtonLink>
    </div>
  )
}

export function EmptyState({ title, message, children }: { title: string; message: string; children?: React.ReactNode }) {
  return (
    <div className="hairline flex flex-col items-start gap-3 rounded-card bg-surface-1 p-6">
      <h3 className="text-lg text-ink">{title}</h3>
      <p className="text-sm text-ink-soft">{message}</p>
      {children}
    </div>
  )
}
