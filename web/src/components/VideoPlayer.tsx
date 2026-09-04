import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import Hls from 'hls.js'
import { prefs } from '@/lib/prefs'

const RATES = [0.75, 1, 1.25, 1.5, 1.75, 2]

type Props = {
  src: string
  title: string
  autoplay: boolean
  /** Segundo desde el que retomar (posición guardada). */
  startAt?: number
  onEnded?: () => void
}

// Player HLS: hls.js donde hace falta (Chrome, Firefox), nativo en
// Safari. La calidad la maneja HLS (ABR). Controles nativos + velocidad.
export const VideoPlayer = forwardRef<HTMLVideoElement | null, Props>(function VideoPlayer(
  { src, title, autoplay, startAt, onEnded },
  ref,
) {
  const videoRef = useRef<HTMLVideoElement>(null)
  useImperativeHandle(ref, () => videoRef.current as HTMLVideoElement, [])
  const [rate, setRate] = useState(prefs.rate)
  const [unsupported, setUnsupported] = useState(false)

  useEffect(() => {
    const video = videoRef.current
    if (!video) return
    video.playbackRate = rate

    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = src
      return
    }
    if (!Hls.isSupported()) {
      setUnsupported(true)
      return
    }
    const hls = new Hls({ enableWorker: true })
    hls.loadSource(src)
    hls.attachMedia(video)
    return () => hls.destroy()
    // rate se aplica en su propio efecto; acá solo importa la fuente.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src])

  useEffect(() => {
    if (videoRef.current) videoRef.current.playbackRate = rate
  }, [rate])

  // Retomar: al conocer la duración, saltar a la posición guardada salvo
  // que esté a punto de terminar (ahí conviene arrancar de cero).
  useEffect(() => {
    const video = videoRef.current
    if (!video || !startAt) return
    const seek = () => {
      if (Number.isFinite(video.duration) && startAt < video.duration - 5) video.currentTime = startAt
    }
    if (video.readyState >= 1) seek()
    else video.addEventListener('loadedmetadata', seek, { once: true })
    return () => video.removeEventListener('loadedmetadata', seek)
  }, [startAt, src])

  if (unsupported) {
    return (
      <div role="alert" className="flex aspect-video items-center justify-center rounded-card bg-surface-1 p-6 text-center text-sm text-ink-soft">
        Tu navegador no puede reproducir este video. Probá con una versión reciente de Chrome, Firefox o Safari.
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <video
        ref={videoRef}
        controls
        playsInline
        autoPlay={autoplay}
        preload="metadata"
        aria-label={title}
        onEnded={onEnded}
        className="aspect-video w-full rounded-card bg-surface-1"
      />
      <div className="flex flex-wrap items-center gap-4 text-sm">
        <label className="flex items-center gap-2 text-ink-soft">
          velocidad
          <select
            value={rate}
            onChange={(e) => {
              const r = Number(e.target.value)
              setRate(r)
              prefs.setRate(r)
            }}
            className="hairline-strong h-9 rounded-control bg-surface-1 px-2 font-mono text-xs text-ink"
          >
            {RATES.map((r) => (
              <option key={r} value={r}>
                {r}×
              </option>
            ))}
          </select>
        </label>
      </div>
    </div>
  )
})
