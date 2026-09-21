// Parte el cuerpo de una lección en tramos de Markdown y referencias a
// demos. Una directiva `::demo[slug]` cuenta solo si está sola en su
// línea y fuera de un bloque de código, igual que en el backend
// (internal/content/markdown.go).

export type Segment = { type: 'markdown'; text: string } | { type: 'demo'; slug: string }

const directive = /^[ \t]*::demo\[([a-z0-9]+(?:-[a-z0-9]+)*)\][ \t]*$/
const fence = /^[ \t]*(```|~~~)/

export function splitBody(body: string): Segment[] {
  const segments: Segment[] = []
  let buffer: string[] = []
  let inFence = false

  const flush = () => {
    const text = buffer.join('\n').trim()
    if (text) segments.push({ type: 'markdown', text })
    buffer = []
  }

  for (const line of body.split('\n')) {
    if (fence.test(line)) inFence = !inFence
    const match = !inFence && directive.exec(line)
    if (match) {
      flush()
      segments.push({ type: 'demo', slug: match[1] })
    } else {
      buffer.push(line)
    }
  }
  flush()
  return segments
}
