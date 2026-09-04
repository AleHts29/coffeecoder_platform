export interface User {
  id: string
  email: string
  name: string
  role: 'student' | 'admin'
}

export interface AuthResponse {
  access_token: string
  expires_in: number
  user: User
}
