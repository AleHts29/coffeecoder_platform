// El access token vive SOLO acá, en memoria. Nunca en localStorage.
// El refresh viaja en cookie HttpOnly y lo maneja el backend.
let accessToken: string | null = null

export const session = {
  get: () => accessToken,
  set: (token: string | null) => {
    accessToken = token
  },
}
