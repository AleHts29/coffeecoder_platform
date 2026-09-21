// Formateo de datos. Todo lo que devuelve esto se muestra en JetBrains Mono.

/** 12900 → "USD 129". Precios en moneda base; el regional llega en billing. */
export function formatPrice(cents: number, currency = 'USD'): string {
  const whole = Math.round(cents / 100)
  return `${currency} ${whole.toLocaleString('es-AR')}`
}

/** 31020 → "8 h 37 min"; 1500 → "25 min". */
export function formatHours(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.round((seconds % 3600) / 60)
  if (h === 0) return `${m} min`
  if (m === 0) return `${h} h`
  return `${h} h ${m} min`
}

/** 615 → "10:15". Para duraciones de lección. */
export function formatClock(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

/** 7 → "07". Numeración de módulos y lecciones. */
export function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

export function plural(n: number, one: string, many: string): string {
  return `${n} ${n === 1 ? one : many}`
}

/** Duración de una lección según su tipo: `12:30` en video, `6 min` en lectura. */
export function formatLessonDuration(seconds: number, kind: 'video' | 'article'): string {
  if (kind === 'article') return `${Math.max(1, Math.round(seconds / 60))} min`
  return formatClock(seconds)
}
