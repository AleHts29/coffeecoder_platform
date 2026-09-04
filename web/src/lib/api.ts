// Cliente HTTP mínimo. Todas las respuestas de error de la API tienen
// el shape { error: "mensaje en español" }; lo propagamos tal cual.
const BASE = (import.meta.env.VITE_API_URL ?? '') + '/api/v1'

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message)
    this.name = 'ApiError'
  }
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    res = await fetch(BASE + path, {
      ...init,
      headers: { Accept: 'application/json', ...(init?.headers ?? {}) },
    })
  } catch {
    throw new ApiError(0, 'no pudimos conectar con el servidor, revisá tu conexión y reintentá')
  }
  if (!res.ok) {
    let message = 'algo salió mal, reintentá'
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      /* cuerpo no JSON: nos quedamos con el mensaje genérico */
    }
    throw new ApiError(res.status, message)
  }
  return (await res.json()) as T
}
