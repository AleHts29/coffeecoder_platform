import { useEffect, useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import * as tus from 'tus-js-client'
import { admin } from '@/lib/admin'
import { ApiError } from '@/lib/api'
import type { VideoStatus } from '@/types/admin'
import { Button } from './Button'

const LABEL: Record<VideoStatus, string> = {
  none: 'sin video',
  uploading: 'subiendo',
  processing: 'procesando',
  ready: 'listo',
  failed: 'falló',
}

type Props = { lessonId: string; courseId: string; status: VideoStatus }

// Upload TUS directo al provider con el ticket firmado del backend.
// Mientras el provider transcodifica, consulta el estado cada 5 s.
export function VideoUpload({ lessonId, courseId, status }: Props) {
  const queryClient = useQueryClient()
  const input = useRef<HTMLInputElement>(null)
  const [progress, setProgress] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['admin', 'courses', courseId] })

  useEffect(() => {
    if (status !== 'uploading' && status !== 'processing') return
    if (progress !== null) return // el upload sigue en curso en este browser
    const t = window.setInterval(() => {
      void admin.syncVideo(lessonId).then(refresh).catch(() => undefined)
    }, 5000)
    return () => window.clearInterval(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, progress, lessonId])

  async function onFile(file: File) {
    setError(null)
    setProgress(0)
    try {
      const { upload } = await admin.startUpload(lessonId)
      if (upload.endpoint.startsWith('fake://')) {
        await admin.syncVideo(lessonId)
        setProgress(null)
        await refresh()
        return
      }
      await new Promise<void>((resolve, reject) => {
        const u = new tus.Upload(file, {
          endpoint: upload.endpoint,
          headers: upload.headers,
          metadata: { filetype: file.type, title: file.name },
          retryDelays: [0, 3000, 10000, 30000],
          onProgress: (sent, total) => setProgress(Math.round((sent / total) * 100)),
          onError: reject,
          onSuccess: () => resolve(),
        })
        u.start()
      })
      setProgress(null)
      await admin.syncVideo(lessonId).catch(() => undefined)
      await refresh()
    } catch (err) {
      setProgress(null)
      setError(err instanceof ApiError ? err.message : 'la subida falló, reintentá')
      await refresh()
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <span
        className={
          'font-mono text-xs ' +
          (status === 'ready' ? 'text-accent' : status === 'failed' ? 'text-danger' : 'text-ink-faint')
        }
      >
        video: {LABEL[status]}
        {progress !== null && ` · ${progress}%`}
      </span>
      <input
        ref={input}
        type="file"
        accept="video/*"
        className="sr-only"
        aria-label="Elegir archivo de video"
        onChange={(e) => {
          const f = e.target.files?.[0]
          if (f) void onFile(f)
          e.target.value = ''
        }}
      />
      <Button variant="ghost" onClick={() => input.current?.click()} disabled={progress !== null}>
        {status === 'none' ? 'Subir video' : 'Reemplazar video'}
      </Button>
      {(status === 'uploading' || status === 'processing') && progress === null && (
        <Button variant="ghost" onClick={() => void admin.syncVideo(lessonId).then(refresh)}>
          Actualizar estado
        </Button>
      )}
      {error && (
        <span role="alert" className="text-xs text-danger">
          {error}
        </span>
      )}
    </div>
  )
}
