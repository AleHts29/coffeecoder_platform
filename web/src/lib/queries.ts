import { queryOptions } from '@tanstack/react-query'
import { api } from './api'
import type { CareerDetail, CareerSummary, CourseDetail, CourseSummary } from '@/types/catalog'

export const careersQuery = () =>
  queryOptions({ queryKey: ['careers'], queryFn: () => api<CareerSummary[]>('/careers') })

export const careerQuery = (slug: string) =>
  queryOptions({ queryKey: ['careers', slug], queryFn: () => api<CareerDetail>(`/careers/${slug}`) })

export const coursesQuery = () =>
  queryOptions({ queryKey: ['courses'], queryFn: () => api<CourseSummary[]>('/courses') })

export const courseQuery = (slug: string) =>
  queryOptions({ queryKey: ['courses', slug], queryFn: () => api<CourseDetail>(`/courses/${slug}`) })

export interface Playback {
  url: string
  expires_at: string
}

// La key incluye al usuario: al loguearse cambia y se vuelve a pedir.
export const playbackQuery = (lessonId: string, userId: string | null) =>
  queryOptions({
    queryKey: ['playback', lessonId, userId],
    queryFn: () => api<Playback>(`/lessons/${lessonId}/playback`),
    staleTime: 5 * 60_000,
    retry: false,
  })

import type { CourseProgress, Dashboard } from '@/types/progress'

export const tz = (): string => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  } catch {
    return ''
  }
}

// Progreso del alumno en un curso. 403 si no lo compró: la página lo
// usa para saber si mostrar la card de compra o la de acceso.
export const courseProgressQuery = (slug: string, userId: string | null) =>
  queryOptions({
    queryKey: ['progress', 'course', slug, userId],
    queryFn: () => api<CourseProgress>(`/me/courses/${slug}/progress`),
    enabled: !!userId,
    retry: false,
    staleTime: 30_000,
  })

export const dashboardQuery = (userId: string | null) =>
  queryOptions({
    queryKey: ['dashboard', userId],
    queryFn: () => api<Dashboard>(`/me/dashboard?tz=${encodeURIComponent(tz())}`),
    enabled: !!userId,
    staleTime: 30_000,
  })

import type { Order } from '@/types/billing'

export const orderQuery = (id: string, userId: string | null) =>
  queryOptions({
    queryKey: ['orders', id, userId],
    queryFn: () => api<Order>(`/orders/${id}`),
    enabled: !!userId,
    retry: false,
  })

export const myOrdersQuery = (userId: string | null) =>
  queryOptions({
    queryKey: ['orders', 'mine', userId],
    queryFn: () => api<Order[]>('/me/orders'),
    enabled: !!userId,
  })


import type { LessonContentData } from '@/types/content'

// Contenido de una lección de lectura (o los apuntes de una de video).
// Misma regla de acceso que playback: 401/403 si no corresponde.
export const lessonContentQuery = (lessonId: string, userId: string | null) =>
  queryOptions({
    queryKey: ['content', lessonId, userId],
    queryFn: () => api<LessonContentData>(`/lessons/${lessonId}/content`),
    // Las frame_url de las demos vienen firmadas con TTL corto.
    staleTime: 5 * 60_000,
    retry: false,
  })
