import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { orderQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { formatPrice } from '@/lib/format'
import { ButtonLink } from '@/components/Button'
import { ErrorState, Loading } from '@/components/PageState'
import { CheckIcon } from '@/components/icons'

export type ResultSearch = { orden: string; estado?: 'aprobado' | 'pendiente' | 'rechazado'; simulado?: boolean }

const POLL_MS = 2500
const POLL_MAX_MS = 90_000

// Vuelta del checkout. El estado real lo da la orden (el webhook puede
// llegar unos segundos después del redirect): se consulta cada 2,5 s
// hasta que deje de estar pending o pase el tiempo máximo.
export function CheckoutResult({ orden, estado, simulado }: ResultSearch) {
  useTitle('Resultado del pago')
  const { status, user } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const order = useQuery({
    ...orderQuery(orden, user?.id ?? null),
    refetchInterval: (q) => {
      const data = q.state.data
      const started = q.state.dataUpdatedAt || Date.now()
      if (!data || data.status !== 'pending') return false
      return Date.now() - started > POLL_MAX_MS ? false : POLL_MS
    },
  })

  useEffect(() => {
    if (status === 'anonymous') {
      void navigate({ to: '/ingresar', search: { redirect: `/checkout/resultado?orden=${orden}` }, replace: true })
    }
  }, [status, navigate, orden])

  useEffect(() => {
    if (order.data?.status === 'approved') {
      void queryClient.invalidateQueries({ queryKey: ['dashboard'] })
      void queryClient.invalidateQueries({ queryKey: ['progress'] })
      void queryClient.invalidateQueries({ queryKey: ['playback'] })
    }
  }, [order.data?.status, queryClient])

  if (status !== 'authenticated' || order.isPending) return <Loading label="Consultando el pago" />
  if (order.isError) return <ErrorState message="No encontramos esa orden." onRetry={() => void order.refetch()} />

  const o = order.data
  const productTo = o.product_type === 'career' ? ('/carreras/$slug' as const) : ('/cursos/$slug' as const)

  return (
    <div className="mx-auto flex w-full max-w-xl flex-col gap-6 py-6">
      <p className="font-mono text-xs text-ink-faint">
        orden {o.id.slice(0, 8)} · {formatPrice(o.amount_cents, o.currency)}
      </p>

      {o.status === 'approved' && (
        <>
          <h1 className="flex items-center gap-3 text-3xl text-ink">
            <CheckIcon size={28} className="text-accent" /> Listo, ya es tuyo
          </h1>
          <p className="text-ink-soft">
            El pago de <span className="text-ink">{o.product_title}</span> se acreditó. Tenés acceso de por vida, con todas las actualizaciones. Te mandamos la confirmación por email.
          </p>
          <div className="flex flex-wrap gap-3">
            <ButtonLink variant="primary" to={productTo} params={{ slug: o.product_slug }}>
              Empezar
            </ButtonLink>
            <ButtonLink variant="ghost" to="/panel">
              Ir a mi panel
            </ButtonLink>
          </div>
        </>
      )}

      {o.status === 'pending' && (
        <>
          <h1 className="text-3xl text-ink">Estamos esperando la confirmación</h1>
          <p className="text-ink-soft">
            {estado === 'rechazado'
              ? 'Mercado Pago informó un problema con el pago. Si se resuelve, esta página se actualiza sola.'
              : 'Algunos medios de pago tardan unos minutos en acreditarse. Esta página se actualiza sola; también podés cerrarla y volver más tarde desde Mi cuenta.'}
          </p>
          <div role="status" aria-live="polite" className="font-mono text-xs text-ink-faint">
            {order.isFetching ? 'consultando…' : 'esperando al proveedor de pagos'}
          </div>
          {simulado && (
            <p className="hairline rounded-card bg-surface-1 p-4 font-mono text-xs text-ink-soft">
              modo desarrollo: aprobá esta orden con <span className="text-ink">make dev-pay ORDER={o.id}</span>
            </p>
          )}
          <div className="flex flex-wrap gap-3">
            <ButtonLink variant="secondary" to="/cuenta">
              Ver mis compras
            </ButtonLink>
          </div>
        </>
      )}

      {o.status === 'rejected' && (
        <>
          <h1 className="text-3xl text-ink">El pago no se aprobó</h1>
          <p className="text-ink-soft">
            Mercado Pago rechazó el pago de <span className="text-ink">{o.product_title}</span>. No se te cobró nada. Podés intentar con otro medio de pago.
          </p>
          <div className="flex flex-wrap gap-3">
            <ButtonLink
              variant="primary"
              to="/checkout"
              search={{ producto: o.product_type === 'career' ? 'carrera' : 'curso', slug: o.product_slug }}
            >
              Reintentar
            </ButtonLink>
            <ButtonLink variant="ghost" to={productTo} params={{ slug: o.product_slug }}>
              Volver al {o.product_type === 'career' ? 'la carrera' : 'curso'}
            </ButtonLink>
          </div>
        </>
      )}

      {o.status === 'refunded' && (
        <>
          <h1 className="text-3xl text-ink">Esta compra fue reembolsada</h1>
          <p className="text-ink-soft">El acceso quedó revocado. Si tenés dudas, escribinos.</p>
        </>
      )}
    </div>
  )
}
