import type { CourseStatus } from '@/types/progress'

// Barra fina: caramelo sobre surface-2. El porcentaje va en mono al lado.
export function ProgressBar({ value, label, className = '' }: { value: number; label?: string; className?: string }) {
  const pct = Math.max(0, Math.min(100, Math.round(value)))
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <div
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label ?? 'Progreso'}
        className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-2"
      >
        <div className="h-full rounded-full bg-accent" style={{ width: `${pct}%` }} />
      </div>
      <span className="font-mono text-xs text-ink-soft">{pct}%</span>
    </div>
  )
}

// Segmentos por curso: lleno = completado, 55 % = en curso, surface-2 = pendiente.
export function SegmentBar({ segments, label }: { segments: { status: CourseStatus; weight: number; title: string }[]; label: string }) {
  const total = segments.reduce((a, s) => a + s.weight, 0) || 1
  return (
    <div role="img" aria-label={label} className="flex h-1.5 gap-0.5 overflow-hidden rounded-full">
      {segments.map((s, i) => (
        <div
          key={i}
          title={s.title}
          style={{ width: `${(s.weight / total) * 100}%` }}
          className={
            'h-full ' +
            (s.status === 'completed' ? 'bg-accent' : s.status === 'in_progress' ? 'bg-accent/55' : 'bg-surface-2')
          }
        />
      ))}
    </div>
  )
}
