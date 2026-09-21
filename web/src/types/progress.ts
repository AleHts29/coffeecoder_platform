export interface LessonProgress {
  lesson_id: string
  seconds: number
  completed: boolean
}

export interface CourseProgress {
  course_id: string
  completed_lessons: number
  total_lessons: number
  last_lesson_id: string | null
  lessons: LessonProgress[]
}

export type CourseStatus = 'pending' | 'in_progress' | 'completed'

export interface CourseCard {
  slug: string
  title: string
  subtitle: string
  level: 'suave' | 'medio' | 'intenso'
  position: number
  completed_lessons: number
  total_lessons: number
  last_lesson_id: string | null
  status: CourseStatus
}

export interface CareerCard {
  slug: string
  title: string
  level: 'suave' | 'medio' | 'intenso'
  completed_lessons: number
  total_lessons: number
  courses: CourseCard[]
}

export interface ContinueWatching {
  lesson_id: string
  kind: 'video' | 'article' 
  lesson_title: string
  module_title: string
  module_position: number
  seconds: number
  duration_s: number
  course_slug: string
  course_title: string
}

export interface Dashboard {
  continue: ContinueWatching | null
  streak_days: number
  week_seconds: number
  careers: CareerCard[]
  courses: CourseCard[]
}
