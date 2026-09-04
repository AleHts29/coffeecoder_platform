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
