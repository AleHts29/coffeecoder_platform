import { useEffect, useState } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { api, ApiError } from '@/lib/api'
import { careerQuery, courseQuery } from '@/lib/queries'
import { useTitle } from '@/lib/useTitle'
import { formatHours, formatPrice, plural } from '@/lib/format'
import { Button, ButtonLink } from '@/components/Button'
import { LevelBadge } from '@/components/LevelBadge'
import { Meta } from '@/components/Meta'
import { ErrorState, Loading, NotFoundState } from '@/components/PageState'
import { CreditCardIcon, InfinityIcon, RefreshIcon } from '@/components/icons'
import type { CreateOrderResponse } from '@/types/billing'

export type CheckoutSearch = { producto: 'carrera' | 'curso'; slug: string }

// Checkout: resumen del producto y un solo botón, que crea la orden y
// redirige al checkout de Mercado Pago (o al simulado en desarrollo).
export function Checkout({ producto, slug }: CheckoutSearch) {
  useTitle('Checkout')
  const { status, user } = useAuth()
  const navigate = useNavigate()
  const isCareer = producto === 'carrera'
  const career = useQuery({ ...careerQuery(slug), enabled: isCareer })
  const course = useQuery({ ...courseQuery(slug), enabled: !isCareer })
  const product = isCareer ? career.data : course.data
  const query = isCareer ? career : course
  const [redirecting, setRedirecting] = useState(false)

  const redirect = `/checkout?producto=${producto}&slug=${slug}`
  useEffect(() => {
    if (status === 'anonymous') void navigate({ to: '/ingresar', search: { redirect }, replace: true })
  }, [status, navigate, redirect])

  const order = useMutation({
    mutationFn: () =>
      api<CreateOrderResponse>('/orders', {
        method: 'POST',
        body: JSON.stringify({ product_type: isCareer ? 'career' : 'course', product_id: product!.id }),
      }),
    onSuccess: (res) => {
      setRedirecting(true)
      window.location.assign(res.checkout_url)
    },
  })

  if (status !== 'authenticated' || query.isPending) return <Loading label="Preparando el checkout" />
  if (query.isError || !product) {
    return <NotFoundState title="Ese producto no está disponible" message="Puede que ya no esté a la venta. El catálogo tiene lo vigente." />
  }

  const err = order.error instanceof ApiError ? order.error : null
  const back = isCareer ? ('/carreras/$slug' as const) : ('/cursos/$slug' as const)

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-8 py-4">
      <header className="flex flex-col gap-2">
        <p className="font-mono text-xs text-ink-faint">checkout</p>
        <h1 className="text-3xl text-ink">Confirmá tu compra</h1>
      </header>

      <section aria-label="Resumen" className="hairline flex flex-col gap-4 rounded-card bg-surface-1 p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-2">
            <LevelBadge kind={producto} level={product.level} />
            <h2 className="text-xl text-ink">{product.title}</h2>
            <p className="text-sm text-ink-soft">{product.subtitle}</p>
          </div>
          <p className="shrink-0 font-mono text-2xl text-ink">{formatPrice(product.price_cents)}</p>
        </div>
        <Meta
          items={[
            ...('course_count' in product ? [plural(product.course_count, 'curso', 'cursos')] : []),
            plural(product.lesson_count, 'lección', 'lecciones'),
            formatHours(product.duration_s),
          ]}
        />
        <ul className="flex flex-col gap-2 border-t-[0.5px] border-border pt-4 text-sm text-ink-soft">
          <li className="flex items-center gap-2">
            <InfinityIcon size={18} className="shrink-0 text-accent" /> Acceso de por vida
          </li>
          <li className="flex items-center gap-2">
            <RefreshIcon size={18} className="shrink-0 text-accent" /> Actualizaciones incluidas
          </li>
          <li className="flex items-center gap-2">
            <CreditCardIcon size={18} className="shrink-0 text-accent" /> En cuotas con Mercado Pago
          </li>
        </ul>
      </section>

      <p className="text-sm text-ink-soft">
        Comprás como <span className="text-ink">{user?.email}</span>. El cobro se hace en pesos al tipo de cambio del día; Mercado Pago te muestra el monto final antes de pagar.
      </p>

      {err?.status === 409 ? (
        <ErrorState message="Ya tenés acceso a este producto. No hace falta volver a comprarlo." onRetry={undefined} />
      ) : (
        err && <ErrorState message={err.message} onRetry={() => order.mutate()} />
      )}

      <div className="flex flex-wrap items-center gap-3">
        <Button variant="primary" onClick={() => order.mutate()} disabled={order.isPending || redirecting || err?.status === 409}>
          {order.isPending || redirecting ? 'Redirigiendo a Mercado Pago…' : 'Pagar con Mercado Pago'}
        </Button>
        <ButtonLink variant="ghost" to={back} params={{ slug }}>
          Volver
        </ButtonLink>
      </div>
    </div>
  )
}
