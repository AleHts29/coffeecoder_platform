import type { InputHTMLAttributes } from 'react'

type Props = InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string }

// Input con label visible siempre (accesibilidad) y estilo del sistema.
export function Field({ label, hint, id, className = '', ...rest }: Props) {
  const inputId = id ?? rest.name
  return (
    <label htmlFor={inputId} className="flex flex-col gap-1.5 text-sm">
      <span className="text-ink-soft">{label}</span>
      <input
        id={inputId}
        className={`hairline-strong h-11 rounded-control bg-surface-0 px-3 text-ink placeholder:text-ink-faint focus:border-accent ${className}`}
        {...rest}
      />
      {hint && <span className="font-mono text-xs text-ink-faint">{hint}</span>}
    </label>
  )
}
