import type { Level } from './catalog'

export type ProductStatus = 'draft' | 'published' | 'archived'

export interface ProductInput {
  category: string
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

export type LessonKind = 'video' | 'article'

export interface AdminLesson {
  id: string
  title: string
  description: string
  duration_s: number
  is_free_sample: boolean
  position: number
  video_status: VideoStatus
  kind: LessonKind
  body_md: string
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
  kind: LessonKind
  body_md: string
}

export interface AdminDemo {
  id: string
  slug: string
  title: string
  height_px: number
  size_bytes: number
  frame_url: string
  used_by: { id: string; title: string; module_title: string }[]
}

export interface AdminDemoDetail {
  id: string
  slug: string
  title: string
  html: string
  height_px: number
  frame_url: string
}

export interface DemoInput {
  slug: string
  title: string
  html: string
  height_px: number
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
