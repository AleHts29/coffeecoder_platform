// Línea de metadatos en mono, separados por "·".
export function Meta({ items, className = '' }: { items: string[]; className?: string }) {
  return (
    <p className={`font-mono text-sm text-ink-faint ${className}`}>
      {items.map((item, i) => (
        <span key={i}>
          {i > 0 && <span aria-hidden="true"> · </span>}
          {item}
        </span>
      ))}
    </p>
  )
}
