import type { Level } from '@/types/catalog'

// Badge outline en mono, ej: `carrera · tueste medio`.
export function LevelBadge({ kind, level }: { kind: 'carrera' | 'curso'; level: Level }) {
  return (
    <span className="hairline-strong inline-flex h-7 items-center rounded-control px-2 font-mono text-xs text-ink-soft">
      {kind} · tueste {level}
    </span>
  )
}
