import { CoffeeIcon } from './icons'

// Wordmark aprobado: ícono de café caramelo + `coffeecoder_` en mono 500
// con el cursor en caramelo.
export function Wordmark() {
  return (
    <span className="inline-flex items-center gap-2 font-mono text-base font-medium text-ink">
      <CoffeeIcon size={22} className="text-accent" />
      <span>
        coffeecoder<span className="text-accent">_</span>
      </span>
    </span>
  )
}
