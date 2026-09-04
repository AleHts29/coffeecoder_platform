import type { ButtonHTMLAttributes } from 'react'
import { Link, type LinkProps } from '@tanstack/react-router'

// Jerarquía de 4 niveles (DESIGN.md). El componente fuerza la jerarquía:
// no hay forma de pintar un botón caramelo sin declarar variant="primary",
// y la regla "máximo un primario por vista" se revisa por pantalla.
export type Variant = 'primary' | 'secondary' | 'ghost' | 'destructive'

const base =
  'inline-flex h-11 items-center justify-center gap-2 rounded-control px-4 text-sm font-medium ' +
  'whitespace-nowrap transition-colors duration-150 select-none ' +
  'disabled:cursor-not-allowed disabled:bg-surface-1 disabled:text-ink-disabled disabled:border-border'

const variants: Record<Variant, string> = {
  primary: 'bg-accent text-on-accent hover:bg-accent-hover',
  secondary: 'hairline-strong bg-surface-2 text-ink hover:bg-surface-2-hover hover:border-ink-disabled',
  ghost: 'bg-transparent text-ink-soft hover:bg-surface-2 hover:text-ink',
  destructive:
    'border-[0.5px] border-solid border-danger-border bg-transparent text-danger hover:bg-danger-surface hover:border-danger-border-hover',
}

export function buttonClass(variant: Variant = 'secondary', className = ''): string {
  return `${base} ${variants[variant]} ${className}`.trim()
}

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }

export function Button({ variant = 'secondary', className = '', type = 'button', ...rest }: ButtonProps) {
  return <button type={type} className={buttonClass(variant, className)} {...rest} />
}

type ButtonLinkProps = LinkProps & { variant?: Variant; className?: string }

export function ButtonLink({ variant = 'secondary', className = '', ...rest }: ButtonLinkProps) {
  return <Link className={buttonClass(variant, className)} {...rest} />
}
