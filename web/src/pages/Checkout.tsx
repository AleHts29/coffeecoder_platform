import { useTitle } from '@/lib/useTitle'
import { ButtonLink } from '@/components/Button'

export type CheckoutSearch = { producto: 'carrera' | 'curso'; slug: string }

// Placeholder hasta P6 (pagos). Existe para que el CTA de compra ya
// apunte a la ruta definitiva.
export function Checkout({ producto, slug }: CheckoutSearch) {
  useTitle('Checkout')
  const back = producto === 'carrera' ? ('/carreras/$slug' as const) : ('/cursos/$slug' as const)
  return (
    <div className="flex max-w-prose flex-col items-start gap-4 py-10">
      <p className="font-mono text-xs text-ink-faint">checkout · {producto} · {slug}</p>
      <h1 className="text-3xl text-ink">Todavía no se puede comprar</h1>
      <p className="text-ink-soft">
        El pago con Mercado Pago llega en la próxima etapa. Mientras tanto, la currícula completa
        ya está publicada para que decidas con calma.
      </p>
      <ButtonLink variant="secondary" to={back} params={{ slug }}>
        Volver
      </ButtonLink>
    </div>
  )
}
