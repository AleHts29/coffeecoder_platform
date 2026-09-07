import { useEffect, useRef } from 'react'
import { Button } from './Button'

type Props = {
  open: boolean
  title: string
  message: string
  confirmLabel: string
  busy?: boolean
  onConfirm: () => void
  onCancel: () => void
}

// Confirmación destructiva: <dialog> nativo. El único lugar de la
// plataforma con el botón rojo relleno.
export function ConfirmDialog({ open, title, message, confirmLabel, busy, onConfirm, onCancel }: Props) {
  const ref = useRef<HTMLDialogElement>(null)
  useEffect(() => {
    const d = ref.current
    if (!d) return
    if (open && !d.open) d.showModal()
    if (!open && d.open) d.close()
  }, [open])

  return (
    <dialog
      ref={ref}
      onClose={onCancel}
      className="hairline-strong m-auto w-[min(92vw,420px)] rounded-card bg-surface-1 p-6 text-ink backdrop:bg-surface-0/80"
    >
      <h2 className="text-lg">{title}</h2>
      <p className="mt-2 text-sm text-ink-soft">{message}</p>
      <div className="mt-6 flex justify-end gap-2">
        <Button variant="ghost" onClick={onCancel} disabled={busy}>
          Cancelar
        </Button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={busy}
          className="inline-flex h-11 items-center rounded-control bg-danger px-4 text-sm font-medium text-on-accent transition-colors duration-150 hover:bg-danger-border-hover disabled:cursor-not-allowed disabled:bg-surface-2 disabled:text-ink-disabled"
        >
          {busy ? 'Un momento…' : confirmLabel}
        </button>
      </div>
    </dialog>
  )
}
