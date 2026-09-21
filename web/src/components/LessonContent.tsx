import { memo, useMemo } from 'react'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { splitBody } from '@/lib/lessonBody'
import { CodeBlock } from './CodeBlock'
import { AdjustmentsIcon } from './icons'
import type { DemoRef } from '@/types/content'

type Props = {
  body: string
  demos: DemoRef[]
  /** En la preview del admin los slugs sin demo se marcan en rojo. */
  showMissing?: boolean
}

// Render del texto de una lección: Markdown (sin HTML crudo), código con
// Shiki y demos incrustadas en su card. Lo usan el lector, la tab
// Resumen del player y la preview del admin.
export const LessonContent = memo(function LessonContent({ body, demos, showMissing }: Props) {
  const segments = useMemo(() => splitBody(body), [body])
  const bySlug = useMemo(() => new Map(demos.map((d) => [d.slug, d])), [demos])

  return (
    <div className="prose-cc flex flex-col">
      {segments.map((seg, i) =>
        seg.type === 'markdown' ? (
          <Markdown
            key={i}
            remarkPlugins={[remarkGfm]}
            components={{
              code({ className, children, ...rest }) {
                const text = String(children).replace(/\n$/, '')
                const lang = /language-(\w+)/.exec(className ?? '')?.[1]
                // Inline: sin className de lenguaje y sin saltos.
                if (!lang && !text.includes('\n')) {
                  return (
                    <code className="hairline rounded bg-surface-1 px-1.5 py-0.5 font-mono text-[0.9em] text-ink" {...rest}>
                      {children}
                    </code>
                  )
                }
                return <CodeBlock code={text} lang={lang} />
              },
              pre({ children }) {
                return <>{children}</>
              },
              img({ src, alt }) {
                return <img src={typeof src === 'string' ? src : undefined} alt={alt ?? ''} loading="lazy" className="hairline my-6 rounded-card" />
              },
              a({ href, children }) {
                const external = typeof href === 'string' && /^https?:/.test(href)
                return (
                  <a href={href} className="text-ink underline underline-offset-4 hover:text-accent" {...(external ? { target: '_blank', rel: 'noreferrer noopener' } : {})}>
                    {children}
                  </a>
                )
              },
            }}
          >
            {seg.text}
          </Markdown>
        ) : (
          <DemoCard key={i} demo={bySlug.get(seg.slug)} slug={seg.slug} showMissing={showMissing} />
        ),
      )}
    </div>
  )
})

function DemoCard({ demo, slug, showMissing }: { demo?: DemoRef; slug: string; showMissing?: boolean }) {
  if (!demo) {
    // Para el alumno se omite en silencio; el admin necesita verlo.
    if (!showMissing) return null
    return (
      <p role="alert" className="hairline my-6 rounded-card bg-surface-1 p-4 font-mono text-xs text-danger">
        no hay ninguna demo con el slug “{slug}” en este curso
      </p>
    )
  }
  return (
    <figure className="hairline my-6 flex flex-col gap-2 rounded-card bg-surface-1 p-4">
      <figcaption className="flex items-center gap-2 font-mono text-xs text-ink-faint">
        <AdjustmentsIcon size={16} className="text-accent" />
        demo interactiva · {demo.title}
      </figcaption>
      <iframe
        src={demo.frame_url}
        title={demo.title}
        height={demo.height_px}
        loading="lazy"
        // sandbox también en el atributo: defensa en capas sobre la CSP
        // que manda el backend en la respuesta del frame.
        sandbox="allow-scripts"
        className="w-full rounded-control border-0 bg-surface-0"
      />
    </figure>
  )
}
