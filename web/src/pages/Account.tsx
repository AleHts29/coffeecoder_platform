import { useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { myOrdersQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { formatPrice } from '@/lib/format'
import { ButtonLink } from '@/components/Button'
import { EmptyState, ErrorState, Loading } from '@/components/PageState'
import type { OrderStatus } from '@/types/billing'

const STATUS: Record<OrderStatus, string> = {
  pending: 'pendiente',
  approved: 'aprobada',
  rejected: 'rechazada',
  refunded: 'reembolsada',
}

// Perfil y compras: datos básicos e historial de órdenes.
export function Account() {
  useTitle('Mi cuenta')
  const { status, user } = useAuth()
  const navigate = useNavigate()
  const orders = useQuery(myOrdersQuery(user?.id ?? null))

  useEffect(() => {
    if (status === 'anonymous') void navigate({ to: '/ingresar', search: { redirect: '/cuenta' }, replace: true })
  }, [status, navigate])

  if (status !== 'authenticated' || !user) return <Loading label="Cargando tu cuenta" />

  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl text-ink">Mi cuenta</h1>
        <p className="text-ink-soft">{user.name}</p>
        <p className="font-mono text-sm text-ink-faint">{user.email}</p>
      </header>

      <section aria-labelledby="compras" className="flex flex-col gap-4">
        <h2 id="compras" className="text-2xl text-ink">
          Mis compras
        </h2>
        {orders.isPending ? (
          <Loading />
        ) : orders.isError ? (
          <ErrorState message="No pudimos cargar tus compras." onRetry={() => void orders.refetch()} />
        ) : orders.data.length === 0 ? (
          <EmptyState title="Todavía no compraste nada" message="Cuando lo hagas, acá va a estar el historial.">
            <ButtonLink variant="secondary" to="/catalogo" search={{}}>
              Ver el catálogo
            </ButtonLink>
          </EmptyState>
        ) : (
          <div className="hairline overflow-x-auto rounded-card bg-surface-1">
            <table className="w-full text-sm">
              <thead className="text-left font-mono text-xs text-ink-faint">
                <tr className="border-b-[0.5px] border-border">
                  <th className="px-4 py-3 font-medium">fecha</th>
                  <th className="px-4 py-3 font-medium">producto</th>
                  <th className="px-4 py-3 font-medium">monto</th>
                  <th className="px-4 py-3 font-medium">estado</th>
                </tr>
              </thead>
              <tbody>
                {orders.data.map((o) => (
                  <tr key={o.id} className="border-b-[0.5px] border-border last:border-b-0">
                    <td className="px-4 py-3 font-mono text-xs text-ink-soft">{new Date(o.created_at).toLocaleDateString('es-AR')}</td>
                    <td className="px-4 py-3 text-ink">
                      {o.product_slug ? (
                        <Link
                          to={o.product_type === 'career' ? '/carreras/$slug' : '/cursos/$slug'}
                          params={{ slug: o.product_slug }}
                          className="hover:text-accent"
                        >
                          {o.product_title}
                        </Link>
                      ) : (
                        o.product_title || 'producto no disponible'
                      )}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-ink">{formatPrice(o.amount_cents, o.currency)}</td>
                    <td className="px-4 py-3">
                      {o.status === 'pending' ? (
                        <Link to="/checkout/resultado" search={{ orden: o.id }} className="font-mono text-xs text-accent">
                          {STATUS[o.status]} →
                        </Link>
                      ) : (
                        <span className={'font-mono text-xs ' + (o.status === 'approved' ? 'text-accent' : 'text-ink-faint')}>{STATUS[o.status]}</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}
