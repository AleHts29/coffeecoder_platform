import { useEffect, useState } from 'react'
import { highlight } from '@/lib/highlight'

// Bloque de código: se muestra en mono desde el primer frame y el
// resaltado llega después, sin salto de layout (misma fuente y tamaño).
export function CodeBlock({ code, lang }: { code: string; lang?: string }) {
  const [html, setHtml] = useState<string | null>(null)

  useEffect(() => {
    let alive = true
    void highlight(code, lang).then((h) => {
      if (alive) setHtml(h)
    })
    return () => {
      alive = false
    }
  }, [code, lang])

  const shell = 'hairline my-6 overflow-x-auto rounded-card bg-surface-1 p-4 font-mono text-[13px] leading-relaxed'
  if (html) {
    return (
      <div
        className={shell + ' [&_pre]:!bg-transparent [&_pre]:m-0'}
        // Shiki devuelve HTML propio, generado en el cliente a partir del
        // texto del bloque: no hay HTML del autor acá.
        dangerouslySetInnerHTML={{ __html: html }}
      />
    )
  }
  return (
    <pre className={shell + ' text-ink'}>
      <code>{code}</code>
    </pre>
  )
}
