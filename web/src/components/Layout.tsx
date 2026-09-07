import { useEffect, useState } from 'react'
import { Link, Outlet, useRouterState } from '@tanstack/react-router'
import { Wordmark } from './Wordmark'
import { useAuth } from '@/lib/auth'
import { Button, ButtonLink } from './Button'
import { MenuIcon, XIcon } from './icons'

const navLink =
  'inline-flex h-11 items-center rounded-control px-3 text-sm text-ink-soft transition-colors duration-150 hover:bg-surface-2 hover:text-ink'

export function Layout() {
  const { status, user, logout } = useAuth()
  const [open, setOpen] = useState(false)
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  // El menú móvil se cierra al navegar.
  useEffect(() => setOpen(false), [pathname])

  const links = (
    <>
      <li>
        <Link to="/catalogo" search={{}} className={navLink} activeProps={{ className: 'text-ink', 'aria-current': 'page' }}>
          Catálogo
        </Link>
      </li>
      {status === 'authenticated' && user && (
        <>
          <li>
            <Link to="/panel" className={navLink} activeProps={{ className: 'text-ink', 'aria-current': 'page' }}>
              Mi panel
            </Link>
          </li>
          <li>
            <Link to="/cuenta" className={navLink} activeProps={{ className: 'text-ink', 'aria-current': 'page' }}>
              Mi cuenta
            </Link>
          </li>
          {user.role === 'admin' && (
            <li>
              <Link to="/admin/contenido" className={navLink + ' font-mono text-xs text-accent'} activeProps={{ 'aria-current': 'page' }}>
                admin
              </Link>
            </li>
          )}
          <li>
            <Button variant="ghost" onClick={() => void logout()}>
              Salir
            </Button>
          </li>
        </>
      )}
      {status === 'anonymous' && (
        <li>
          <ButtonLink variant="ghost" to="/ingresar" search={{}}>
            Ingresar
          </ButtonLink>
        </li>
      )}
    </>
  )

  return (
    <div className="flex min-h-dvh flex-col">
      <a
        href="#contenido"
        className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:rounded-control focus:bg-accent focus:px-3 focus:py-2 focus:text-on-accent"
      >
        Ir al contenido
      </a>

      <header className="sticky top-0 z-40 border-b-[0.5px] border-border bg-surface-0/95 backdrop-blur">
        <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link to="/" aria-label="CoffeeCoder, inicio" className="rounded-control">
            <Wordmark />
          </Link>
          <nav aria-label="Principal" className="hidden sm:block">
            <ul className="flex items-center gap-1">{links}</ul>
          </nav>
          <button
            type="button"
            className="inline-flex size-11 items-center justify-center rounded-control text-ink-soft hover:bg-surface-2 hover:text-ink sm:hidden"
            aria-expanded={open}
            aria-controls="menu-movil"
            aria-label={open ? 'Cerrar menú' : 'Abrir menú'}
            onClick={() => setOpen((o) => !o)}
          >
            {open ? <XIcon /> : <MenuIcon />}
          </button>
        </div>
        <nav id="menu-movil" aria-label="Principal" hidden={!open} className="border-t-[0.5px] border-border sm:hidden">
          <ul className="mx-auto flex w-full max-w-6xl flex-col gap-1 px-4 py-2 [&>li>*]:w-full [&>li>*]:justify-start">{links}</ul>
        </nav>
      </header>

      <main id="contenido" className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6 sm:py-10">
        <Outlet />
      </main>

      <footer className="border-t-[0.5px] border-border">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-2 px-4 py-6 text-sm text-ink-faint sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <Wordmark />
          <p className="font-mono text-xs">backend en profundidad · español</p>
        </div>
      </footer>
    </div>
  )
}
