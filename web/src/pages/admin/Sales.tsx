import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { admin, adminOrdersQuery } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { formatPrice } from '@/lib/format'
import { Button } from '@/components/Button'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { ErrorState, Loading } from '@/components/PageState'
import type { AdminOrder } from '@/types/admin'

const STATUS: Record<AdminOrder['status'], string> = { pending: 'pendiente', approved: 'aprobada', rejected: 'rechazada', refunded: 'reembolsada' }

// Ventas: órdenes con estado y producto; reembolso con confirmación.
export function AdminSales() {
  useTitle('Admin · Ventas')
  const queryClient = useQueryClient()
  const orders = useQuery(adminOrdersQuery())
  const [target, setTarget] = useState<AdminOrder | null>(null)
  const [error, setError] = useState<string | null>(null)
  const refund = useMutation({
    mutationFn: (id: string) => admin.refund(id),
    onSuccess: () => { setTarget(null); void queryClient.invalidateQueries({ queryKey: ['admin', 'orders'] }) },
    onError: (e) => { setTarget(null); setError(e instanceof ApiError ? e.message : 'algo salió mal, reintentá') },
  })

  if (orders.isPending) return <Loading />
  if (orders.isError) return <ErrorState message="No pudimos cargar las ventas." onRetry={() => void orders.refetch()} />

  const approved = orders.data.filter((o) => o.status === 'approved')
  const total = approved.reduce((a, o) => a + o.amount_cents, 0)
  const currency = approved[0]?.currency ?? 'ARS'

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-3xl text-ink">Ventas</h1>
        <p className="font-mono text-sm text-ink-soft">
          {approved.length} aprobadas · {formatPrice(total, currency)}
        </p>
      </header>
      {error && (
        <p role="alert" className="text-sm text-danger">
          {error}
        </p>
      )}
      {orders.data.length === 0 ? (
        <p className="text-sm text-ink-soft">Todavía no hay órdenes.</p>
      ) : (
        <div className="hairline overflow-x-auto rounded-card bg-surface-1">
          <table className="w-full text-sm">
            <thead className="text-left font-mono text-xs text-ink-faint">
              <tr className="border-b-[0.5px] border-border">
                <th className="px-4 py-3 font-medium">fecha</th>
                <th className="px-4 py-3 font-medium">comprador</th>
                <th className="px-4 py-3 font-medium">producto</th>
                <th className="px-4 py-3 font-medium">monto</th>
                <th className="px-4 py-3 font-medium">estado</th>
                <th className="px-4 py-3 font-medium">
                  <span className="sr-only">acciones</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {orders.data.map((o) => (
                <tr key={o.id} className="border-b-[0.5px] border-border last:border-b-0">
                  <td className="px-4 py-3 font-mono text-xs text-ink-soft">{new Date(o.created_at).toLocaleString('es-AR', { dateStyle: 'short', timeStyle: 'short' })}</td>
                  <td className="px-4 py-3 text-ink">
                    {o.user_name || '—'}
                    <span className="block font-mono text-xs text-ink-faint">{o.user_email}</span>
                  </td>
                  <td className="px-4 py-3 text-ink">
                    {o.product_title}
                    <span className="ml-2 font-mono text-xs text-ink-faint">{o.product_type === 'career' ? 'carrera' : 'curso'}</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-ink">{formatPrice(o.amount_cents, o.currency)}</td>
                  <td className="px-4 py-3">
                    <span className={'font-mono text-xs ' + (o.status === 'approved' ? 'text-accent' : 'text-ink-faint')}>{STATUS[o.status]}</span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    {o.status === 'approved' && (
                      <Button variant="destructive" className="h-9" onClick={() => setTarget(o)}>
                        Reembolsar
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <ConfirmDialog
        open={!!target}
        title="¿Reembolsar esta compra?"
        message={target ? `Se devuelve ${formatPrice(target.amount_cents, target.currency)} a ${target.user_email} en el proveedor de pagos y se revoca el acceso a ${target.product_title}.` : ''}
        confirmLabel="Reembolsar"
        busy={refund.isPending}
        onConfirm={() => target && refund.mutate(target.id)}
        onCancel={() => setTarget(null)}
      />
    </div>
  )
}
