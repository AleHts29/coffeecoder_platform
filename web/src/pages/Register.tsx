import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { useAuth } from '@/lib/auth'
import { ApiError } from '@/lib/api'
import { useTitle } from '@/lib/useTitle'
import { Button } from '@/components/Button'
import { Field } from '@/components/Field'
import { OAuthButtons } from '@/components/OAuthButtons'
import type { LoginSearch } from './Login'

export function Register({ redirect }: LoginSearch) {
  useTitle('Crear cuenta')
  const { register } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const data = new FormData(e.currentTarget)
    const password = String(data.get('password'))
    if (password.length < 8) {
      setError('la contraseña debe tener al menos 8 caracteres')
      return
    }
    setBusy(true)
    setError(null)
    try {
      await register(String(data.get('email')), password, String(data.get('name')))
      void navigate({ to: redirect ?? '/panel', replace: true })
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'algo salió mal, reintentá')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-sm flex-col gap-8 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl text-ink">Crear cuenta</h1>
        <p className="text-sm text-ink-soft">Un café, una cuenta, y arrancamos.</p>
      </header>

      <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
        <Field label="Nombre" name="name" autoComplete="name" required />
        <Field label="Email" name="email" type="email" autoComplete="email" required />
        <Field
          label="Contraseña"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={8}
          hint="mínimo 8 caracteres"
          required
        />
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <Button variant="primary" type="submit" disabled={busy}>
          {busy ? 'Creando…' : 'Crear cuenta'}
        </Button>
      </form>

      <OAuthButtons redirect={redirect} />

      <p className="text-sm text-ink-soft">
        ¿Ya tenés cuenta?{' '}
        <Link to="/ingresar" search={{ redirect }} className="text-ink underline underline-offset-4 hover:text-accent">
          Ingresá
        </Link>
      </p>
    </div>
  )
}
