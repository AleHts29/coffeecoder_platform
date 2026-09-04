import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { Button } from '@/components/Button'
import { Field } from '@/components/Field'
import { OAuthButtons } from '@/components/OAuthButtons'

export type LoginSearch = { redirect?: string }

export function Login({ redirect }: LoginSearch) {
  useTitle('Ingresar')
  const { login } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const data = new FormData(e.currentTarget)
    setBusy(true)
    setError(null)
    try {
      await login(String(data.get('email')), String(data.get('password')))
      void navigate({ to: redirect ?? '/', replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'algo salió mal, reintentá')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-sm flex-col gap-8 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl text-ink">Ingresar</h1>
        <p className="text-sm text-ink-soft">Seguí donde quedaste.</p>
      </header>

      <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
        <Field label="Email" name="email" type="email" autoComplete="email" required />
        <Field label="Contraseña" name="password" type="password" autoComplete="current-password" required />
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? 'Ingresando…' : 'Ingresar'}
        </Button>
      </form>

      <OAuthButtons redirect={redirect} />

      <p className="text-sm text-ink-soft">
        ¿Todavía no tenés cuenta?{' '}
        <Link to="/registro" search={{ redirect }} className="text-ink underline underline-offset-4 hover:text-accent">
          Registrate
        </Link>
      </p>
    </div>
  )
}
