import { formatPrice } from '@/lib/format'
import { ButtonLink } from './Button'
import { CertificateIcon, CreditCardIcon, InfinityIcon, RefreshIcon } from './icons'

type Props = {
  kind: 'carrera' | 'curso'
  slug: string
  priceCents: number
  children?: React.ReactNode
}

// Card de compra: precio en mono, único botón primario de la vista,
// tres promesas y la nota de cuotas.
export function PurchaseCard({ kind, slug, priceCents, children }: Props) {
  return (
    <aside
      aria-label={`Comprar ${kind}`}
      className="hairline flex flex-col gap-5 rounded-card bg-surface-1 p-5 lg:sticky lg:top-20"
    >
      <p className="font-mono text-3xl text-ink">{formatPrice(priceCents)}</p>
      <ButtonLink
        variant="primary"
        to="/checkout"
        search={{ producto: kind, slug }}
        className="w-full"
      >
        Comprar {kind}
      </ButtonLink>
      <ul className="flex flex-col gap-2 text-sm text-ink-soft">
        <li className="flex items-center gap-2">
          <InfinityIcon size={18} className="shrink-0 text-accent" /> Acceso de por vida
        </li>
        <li className="flex items-center gap-2">
          <RefreshIcon size={18} className="shrink-0 text-accent" /> Actualizaciones incluidas
        </li>
        <li className="flex items-center gap-2">
          <CertificateIcon size={18} className="shrink-0 text-accent" /> Certificado al completar
        </li>
      </ul>
      <p className="flex items-center gap-2 border-t-[0.5px] border-border pt-4 text-xs text-ink-faint">
        <CreditCardIcon size={16} className="shrink-0" /> En cuotas con Mercado Pago
      </p>
      {children}
    </aside>
  )
}
