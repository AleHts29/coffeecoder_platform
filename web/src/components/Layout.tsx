import { Link, Outlet } from '@tanstack/react-router'
import { Wordmark } from './Wordmark'
import { useAuth } from '@/lib/auth'
import { Button, ButtonLink } from './Button'

export function Layout() {
  const { status, user, logout } = useAuth()
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
          <nav aria-label="Principal">
            <ul className="flex items-center gap-1">
              <li>
                <Link
                  to="/catalogo"
                  className="inline-flex h-11 items-center rounded-control px-3 text-sm text-ink-soft transition-colors duration-150 hover:bg-surface-2 hover:text-ink"
                  activeProps={{ className: 'text-ink', 'aria-current': 'page' }}
                >
                  Catálogo
                </Link>
              </li>
              {status === 'anonymous' && (
                <li>
                  <ButtonLink variant="ghost" to="/ingresar" search={{}}>
                    Ingresar
                  </ButtonLink>
                </li>
              )}
              {status === 'authenticated' && user && (
                <>
                  <li>
                    <Link
                      to="/panel"
                      className="inline-flex h-11 items-center rounded-control px-3 text-sm text-ink-soft transition-colors duration-150 hover:bg-surface-2 hover:text-ink"
                      activeProps={{ className: 'text-ink', 'aria-current': 'page' }}
                    >
                      Mi panel
                    </Link>
                  </li>
                  <li>
                    <Link
                      to="/cuenta"
                      className="inline-flex h-11 items-center rounded-control px-3 text-sm text-ink-soft transition-colors duration-150 hover:bg-surface-2 hover:text-ink"
                      activeProps={{ className: 'text-ink', 'aria-current': 'page' }}
                    >
                      Mi cuenta
                    </Link>
                  </li>
                  {user.role === 'admin' && (
                    <li>
                      <Link
                        to="/admin/contenido"
                        className="inline-flex h-11 items-center rounded-control px-3 font-mono text-xs text-accent transition-colors duration-150 hover:bg-surface-2"
                        activeProps={{ 'aria-current': 'page' }}
                      >
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
            </ul>
          </nav>
        </div>
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
