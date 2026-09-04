import { session } from './session'

// Cliente HTTP mínimo. Todas las respuestas de error de la API tienen
// el shape { error: "mensaje en español" }; lo propagamos tal cual.
// Si un request autenticado devuelve 401, intenta un refresh (cookie
// HttpOnly) y reintenta una sola vez.
const BASE = (import.meta.env.VITE_API_URL ?? '') + '/api/v1'

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

type Options = { retry?: boolean }

export async function api<T>(path: string, init?: RequestInit, opts: Options = {}): Promise<T> {
  const headers = new Headers(init?.headers)
  headers.set('Accept', 'application/json')
  if (init?.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json')
  const token = session.get()
  if (token) headers.set('Authorization', `Bearer ${token}`)

  let res: Response
  try {
    res = await fetch(BASE + path, { ...init, headers, credentials: 'same-origin' })
  } catch {
    throw new ApiError(0, 'no pudimos conectar con el servidor, revisá tu conexión y reintentá')
  }

  if (res.status === 401 && token && opts.retry !== false) {
    if (await refreshSession()) return api<T>(path, init, { retry: false })
  }

  if (!res.ok) throw new ApiError(res.status, await errorMessage(res))
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

async function errorMessage(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as { error?: string }
    if (body.error) return body.error
  } catch {
    /* cuerpo no JSON */
  }
  return 'algo salió mal, reintentá'
}

let refreshing: Promise<boolean> | null = null

// refreshSession pide un access token nuevo con la cookie de refresh.
// Single-flight: varios 401 simultáneos comparten un solo refresh.
export function refreshSession(): Promise<boolean> {
  if (!refreshing) {
    refreshing = (async () => {
      try {
        const res = await fetch(BASE + '/auth/refresh', { method: 'POST', credentials: 'same-origin' })
        if (!res.ok) {
          session.set(null)
          return false
        }
        const body = (await res.json()) as { access_token: string }
        session.set(body.access_token)
        return true
      } catch {
        session.set(null)
        return false
      } finally {
        refreshing = null
      }
    })()
  }
  return refreshing
}
