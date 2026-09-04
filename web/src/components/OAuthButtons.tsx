import { buttonClass } from './Button'

// Los links van al backend, que redirige al proveedor. El redirect
// post-login se guarda en sessionStorage (no es un token) para que
// /auth/callback sepa a dónde volver.
export function OAuthButtons({ redirect }: { redirect?: string }) {
  const remember = () => {
    try {
      if (redirect) sessionStorage.setItem('cc.redirect', redirect)
    } catch {
      /* sin storage: volvemos al inicio */
    }
  }
  return (
    <div className="flex flex-col gap-3">
      <p className="flex items-center gap-3 font-mono text-xs text-ink-faint">
        <span aria-hidden="true" className="h-px flex-1 bg-border" />o<span aria-hidden="true" className="h-px flex-1 bg-border" />
      </p>
      <div className="grid gap-2 sm:grid-cols-2">
        <a href="/api/v1/auth/oauth/google" onClick={remember} className={buttonClass('secondary')}>
          Continuar con Google
        </a>
        <a href="/api/v1/auth/oauth/github" onClick={remember} className={buttonClass('secondary')}>
          Continuar con GitHub
        </a>
      </div>
    </div>
  )
}
