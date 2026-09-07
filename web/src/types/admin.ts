import type { Level } from './catalog'

export type ProductStatus = 'draft' | 'published' | 'archived'

export interface ProductInput {
  slug: string
  title: string
  subtitle: string
  description: string
  level: Level
  price_cents: number
  status: ProductStatus
}

export interface AdminProduct extends ProductInput {
  id: string
  position: number
  updated_at: string
  course_count?: number
  lesson_count?: number
}

export type VideoStatus = 'none' | 'uploading' | 'processing' | 'ready' | 'failed'

export interface AdminLesson {
  id: string
  title: string
  description: string
  duration_s: number
  is_free_sample: boolean
  position: number
  video_status: VideoStatus
}

export interface AdminModule {
  id: string
  title: string
  position: number
  lessons: AdminLesson[]
}

export interface AdminCourseDetail extends AdminProduct {
  modules: AdminModule[]
}

export interface AdminCareerDetail extends AdminProduct {
  courses: AdminProduct[]
}

export interface LessonInput {
  title: string
  description: string
  duration_s: number
  is_free_sample: boolean
}

export interface UploadTicket {
  endpoint: string
  headers: Record<string, string>
  expires_at: string
}

export interface AdminOrder {
  id: string
  status: 'pending' | 'approved' | 'rejected' | 'refunded'
  product_type: 'course' | 'career'
  product_title: string
  amount_cents: number
  currency: string
  provider: string
  created_at: string
  user_email: string
  user_name: string
}

export interface Student {
  id: string
  email: string
  name: string
  role: 'student' | 'admin'
  created_at: string
  active_enrollments: number
}

export interface StudentEnrollment {
  id: string
  scope: 'course' | 'career'
  scope_id: string
  product_title: string
  product_slug: string
  order_id: string | null
  activated_at: string
  revoked_at: string | null
}

export interface StudentDetail extends Student {
  enrollments: StudentEnrollment[]
}
