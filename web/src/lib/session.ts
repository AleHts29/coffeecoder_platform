// El access token vive SOLO acá, en memoria. Nunca en localStorage.
// El refresh viaja en cookie HttpOnly y lo maneja el backend.
let accessToken: string | null = null

// Marca "hay sesión que retomar": evita pedir /auth/refresh a cada
// visitante anónimo (y el 401 en consola). No es un token: solo un
// booleano en localStorage que se borra al cerrar sesión.
const HINT = 'cc.session'

export const session = {
  get: () => accessToken,
  set: (token: string | null) => {
    accessToken = token
    try {
      if (token) localStorage.setItem(HINT, '1')
      else localStorage.removeItem(HINT)
    } catch {
      /* sin storage */
    }
  },
  hasHint: () => {
    try {
      return localStorage.getItem(HINT) === '1'
    } catch {
      return false
    }
  },
}
