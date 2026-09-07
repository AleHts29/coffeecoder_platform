import { useEffect } from 'react'
import { Link, Outlet, useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { Loading, NotFoundState } from './PageState'

const tabs = [
  { to: '/admin/contenido', label: 'Contenido' },
  { to: '/admin/ventas', label: 'Ventas' },
  { to: '/admin/alumnos', label: 'Alumnos' },
] as const

// Guard + sub-navegación del panel de administración.
export function AdminLayout() {
  const { status, user } = useAuth()
  const navigate = useNavigate()
  useEffect(() => {
    if (status === 'anonymous') void navigate({ to: '/ingresar', search: { redirect: '/admin/contenido' }, replace: true })
  }, [status, navigate])

  if (status === 'loading') return <Loading />
  if (status === 'anonymous') return null
  if (user?.role !== 'admin') {
    return <NotFoundState title="Esta zona es del instructor" message="Tu cuenta no tiene permisos de administración." />
  }
  return (
    <div className="flex flex-col gap-8">
      <nav aria-label="Administración" className="flex items-center gap-1 border-b-[0.5px] border-border">
        <span className="mr-3 font-mono text-xs text-ink-faint">admin</span>
        {tabs.map((t) => (
          <Link
            key={t.to}
            to={t.to}
            className="-mb-px border-b-2 border-transparent px-3 py-3 text-sm text-ink-soft transition-colors duration-150 hover:text-ink"
            activeProps={{ className: 'border-accent text-ink' }}
            activeOptions={{ exact: false }}
          >
            {t.label}
          </Link>
        ))}
      </nav>
      <Outlet />
    </div>
  )
}
