import type { Module } from '@/types/catalog'
import { formatClock, formatHours, pad2, plural } from '@/lib/format'
import { ChevronDownIcon, PlayIcon } from './icons'

// Currícula expandible por módulos. Usa <details> nativo: accesible,
// sin JS, y el estado abierto sobrevive a re-renders.
export function Curriculum({ modules }: { modules: Module[] }) {
  return (
    <div className="flex flex-col gap-2">
      {modules.map((module, i) => {
        const seconds = module.lessons.reduce((acc, l) => acc + l.duration_s, 0)
        return (
          <details
            key={module.id}
            open={i === 0}
            className="hairline group rounded-card bg-surface-1 open:bg-surface-1"
          >
            <summary className="flex min-h-14 cursor-pointer list-none items-center gap-3 rounded-card px-4 py-3 transition-colors duration-150 hover:bg-surface-2 [&::-webkit-details-marker]:hidden">
              <span className="font-mono text-xs text-ink-faint">módulo {pad2(module.position)}</span>
              <span className="flex-1 text-ink">{module.title}</span>
              <span className="hidden font-mono text-xs text-ink-faint sm:inline">
                {plural(module.lessons.length, 'lección', 'lecciones')} · {formatHours(seconds)}
              </span>
              <ChevronDownIcon
                size={18}
                className="shrink-0 text-ink-faint transition-transform duration-150 group-open:rotate-180"
              />
            </summary>
            <ol className="flex flex-col border-t-[0.5px] border-border">
              {module.lessons.map((lesson) => (
                <li
                  key={lesson.id}
                  className="flex min-h-11 items-center gap-3 px-4 py-2 text-sm"
                >
                  <span className="w-6 shrink-0 font-mono text-xs text-ink-faint">{pad2(lesson.position)}</span>
                  <span className="flex-1 text-ink-soft">{lesson.title}</span>
                  {lesson.is_free_sample && (
                    <span className="inline-flex items-center gap-1 font-mono text-xs text-accent">
                      <PlayIcon size={14} /> gratis
                    </span>
                  )}
                  <span className="font-mono text-xs text-ink-faint">{formatClock(lesson.duration_s)}</span>
                </li>
              ))}
            </ol>
          </details>
        )
      })}
    </div>
  )
}
