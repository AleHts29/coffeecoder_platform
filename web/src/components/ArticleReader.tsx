import { useEffect, useRef } from 'react'
import { LessonContent } from './LessonContent'
import type { LessonContentData } from '@/types/content'

type Props = {
  content: LessonContentData
  /** Se dispara una sola vez cuando el final entra en viewport. */
  onReachedEnd?: () => void
}

// Lector de artículos: el contenido y un marcador al final que, al
// entrar en pantalla, da la lección por leída.
export function ArticleReader({ content, onReachedEnd }: Props) {
  const marker = useRef<HTMLDivElement>(null)
  const fired = useRef(false)
  const cb = useRef(onReachedEnd)
  cb.current = onReachedEnd

  useEffect(() => {
    const el = marker.current
    if (!el || !cb.current) return
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting) && !fired.current) {
          fired.current = true
          cb.current?.()
          io.disconnect()
        }
      },
      { rootMargin: '0px 0px -10% 0px' },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [content.body_md])

  return (
    <article>
      <LessonContent body={content.body_md} demos={content.demos} />
      <div ref={marker} aria-hidden="true" className="h-px" />
    </article>
  )
}
