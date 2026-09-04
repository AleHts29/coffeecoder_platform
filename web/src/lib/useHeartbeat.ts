import { useEffect, useRef, type RefObject } from 'react'
import { api } from './api'
import { tz } from './queries'

const INTERVAL_MS = 15_000

type Options = {
  lessonId: string
  enabled: boolean
  onResult?: (r: { seconds: number; completed: boolean }) => void
}

// Heartbeats del player: cada 15 s mientras reproduce, al pausar, al
// ocultar la pestaña y al salir (keepalive). Solo la posición: el
// servidor decide el completado.
export function useHeartbeat(video: RefObject<HTMLVideoElement | null>, { lessonId, enabled, onResult }: Options) {
  const last = useRef(-1)
  const cb = useRef(onResult)
  cb.current = onResult

  useEffect(() => {
    const el = video.current
    if (!el || !enabled) return
    last.current = -1

    const send = (keepalive = false) => {
      const seconds = Math.floor(el.currentTime)
      if (seconds === last.current) return
      last.current = seconds
      void api<{ seconds: number; completed: boolean }>(
        `/lessons/${lessonId}/heartbeat`,
        { method: 'POST', body: JSON.stringify({ seconds, tz: tz() }), keepalive },
      )
        .then((r) => cb.current?.(r))
        .catch(() => {
          /* el próximo heartbeat lo reintenta */
        })
    }

    let timer: number | undefined
    const start = () => {
      stop()
      timer = window.setInterval(() => send(), INTERVAL_MS)
    }
    const stop = () => {
      if (timer) window.clearInterval(timer)
      timer = undefined
    }
    const onPause = () => {
      stop()
      send()
    }
    const onHidden = () => {
      if (document.visibilityState === 'hidden') send(true)
    }
    const onLeave = () => send(true)

    el.addEventListener('play', start)
    el.addEventListener('pause', onPause)
    el.addEventListener('ended', onPause)
    document.addEventListener('visibilitychange', onHidden)
    window.addEventListener('pagehide', onLeave)
    if (!el.paused) start()

    return () => {
      stop()
      send(true)
      el.removeEventListener('play', start)
      el.removeEventListener('pause', onPause)
      el.removeEventListener('ended', onPause)
      document.removeEventListener('visibilitychange', onHidden)
      window.removeEventListener('pagehide', onLeave)
    }
  }, [video, lessonId, enabled])
}
