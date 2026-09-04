import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { api, refreshSession } from './api'
import { session } from './session'
import type { AuthResponse, User } from '@/types/auth'

type Status = 'loading' | 'anonymous' | 'authenticated'

type AuthContextValue = {
  status: Status
  user: User | null
  login: (email: string, password: string) => Promise<User>
  register: (email: string, password: string, name: string) => Promise<User>
  logout: () => Promise<void>
  /** Tras un callback OAuth: toma la cookie y carga el usuario. */
  resume: () => Promise<boolean>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient()
  const [status, setStatus] = useState<Status>('loading')
  const [user, setUser] = useState<User | null>(null)

  const resume = useCallback(async () => {
    if (!(await refreshSession())) {
      setUser(null)
      setStatus('anonymous')
      return false
    }
    try {
      setUser(await api<User>('/me'))
      setStatus('authenticated')
      return true
    } catch {
      session.set(null)
      setUser(null)
      setStatus('anonymous')
      return false
    }
  }, [])

  useEffect(() => {
    void resume()
  }, [resume])

  const applyAuth = useCallback(
    (res: AuthResponse) => {
      session.set(res.access_token)
      setUser(res.user)
      setStatus('authenticated')
      // Lo que dependía del usuario (playback, progreso) se vuelve a pedir.
      void queryClient.invalidateQueries()
      return res.user
    },
    [queryClient],
  )

  const login = useCallback(
    async (email: string, password: string) =>
      applyAuth(await api<AuthResponse>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) })),
    [applyAuth],
  )

  const register = useCallback(
    async (email: string, password: string, name: string) =>
      applyAuth(
        await api<AuthResponse>('/auth/register', { method: 'POST', body: JSON.stringify({ email, password, name }) }),
      ),
    [applyAuth],
  )

  const logout = useCallback(async () => {
    try {
      await api<void>('/auth/logout', { method: 'POST' }, { retry: false })
    } finally {
      session.set(null)
      setUser(null)
      setStatus('anonymous')
      void queryClient.invalidateQueries()
    }
  }, [queryClient])

  const value = useMemo(
    () => ({ status, user, login, register, logout, resume }),
    [status, user, login, register, logout, resume],
  )
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth fuera de AuthProvider')
  return ctx
}
