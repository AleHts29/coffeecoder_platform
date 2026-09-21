// Shapes públicos de la API de catálogo (internal/catalog/handlers.go).
// Nunca incluyen video_asset_id ni status.

export const LEVELS = ['suave', 'medio', 'intenso'] as const
export type Level = (typeof LEVELS)[number]

export function isLevel(v: unknown): v is Level {
  return typeof v === 'string' && (LEVELS as readonly string[]).includes(v)
}

export interface CourseSummary {
  id: string
  slug: string
  title: string
  subtitle: string
  description: string
  level: Level
  price_cents: number
  position: number
  lesson_count: number
  duration_s: number
}

export interface CareerSummary {
  id: string
  slug: string
  title: string
  subtitle: string
  description: string
  level: Level
  price_cents: number
  position: number
  course_count: number
  lesson_count: number
  duration_s: number
}

export interface CareerDetail extends CareerSummary {
  courses: CourseSummary[]
}

export type LessonKind = 'video' | 'article'

export interface Lesson {
  id: string
  title: string
  description: string
  duration_s: number
  is_free_sample: boolean
  position: number
  kind: LessonKind
}

export interface Module {
  id: string
  title: string
  position: number
  lessons: Lesson[]
}

export interface CareerRef {
  slug: string
  title: string
  price_cents: number
}

export interface CourseDetail extends CourseSummary {
  modules: Module[]
  careers: CareerRef[]
}
