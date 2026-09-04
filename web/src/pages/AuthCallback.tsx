import { useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { Loading, ErrorState } from '@/components/PageState'

// Aterrizaje del OAuth: el backend ya dejó la cookie de refresh.
export function AuthCallback() {
  const { resume } = useAuth()
  const navigate = useNavigate()
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let redirect = '/'
    try {
      redirect = sessionStorage.getItem('cc.redirect') ?? '/'
      sessionStorage.removeItem('cc.redirect')
    } catch {
      /* sin storage */
    }
    void resume().then((ok) => (ok ? navigate({ to: redirect, replace: true }) : setFailed(true)))
  }, [resume, navigate])

  if (failed) {
    return (
      <ErrorState
        message="No pudimos completar el ingreso con el proveedor. Volvé a intentarlo desde Ingresar."
        onRetry={() => navigate({ to: '/ingresar' })}
      />
    )
  }
  return <Loading label="Completando el ingreso" />
}
