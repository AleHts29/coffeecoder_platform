import { useEffect } from 'react'

// Título y descripción por página. Los crawlers reciben además el OG
// inyectado por el backend (internal/server/web.go); esto es para la
// pestaña y el historial.
export function useTitle(title?: string, description?: string) {
  useEffect(() => {
    document.title = title ? `${title} · CoffeeCoder` : 'CoffeeCoder'
    if (description) {
      const tag = document.querySelector('meta[name="description"]')
      tag?.setAttribute('content', description)
    }
  }, [title, description])
}
