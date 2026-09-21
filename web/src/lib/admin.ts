import { queryOptions } from '@tanstack/react-query'
import { api } from './api'
import type {
  AdminCareerDetail, AdminCourseDetail, AdminDemo, AdminDemoDetail, AdminLesson, AdminModule,
  AdminOrder, AdminProduct, DemoInput, LessonInput, ProductInput, Student, StudentDetail,
  StudentEnrollment, UploadTicket,
} from '@/types/admin'

const json = (body: unknown): RequestInit => ({ method: 'POST', body: JSON.stringify(body) })
const put = (body: unknown): RequestInit => ({ method: 'PUT', body: JSON.stringify(body) })
const del: RequestInit = { method: 'DELETE' }

// Queries (solo se habilitan con sesión admin: el caller pasa enabled).
export const adminCareersQuery = () => queryOptions({ queryKey: ['admin', 'careers'], queryFn: () => api<AdminProduct[]>('/admin/careers') })
export const adminCoursesQuery = () => queryOptions({ queryKey: ['admin', 'courses'], queryFn: () => api<AdminProduct[]>('/admin/courses') })
export const adminCourseQuery = (id: string) => queryOptions({ queryKey: ['admin', 'courses', id], queryFn: () => api<AdminCourseDetail>(`/admin/courses/${id}`) })
export const adminCareerQuery = (id: string) => queryOptions({ queryKey: ['admin', 'careers', id], queryFn: () => api<AdminCareerDetail>(`/admin/careers/${id}`) })
export const adminOrdersQuery = () => queryOptions({ queryKey: ['admin', 'orders'], queryFn: () => api<AdminOrder[]>('/admin/orders?limit=200') })
export const adminStudentsQuery = (q: string) => queryOptions({ queryKey: ['admin', 'students', q], queryFn: () => api<Student[]>(`/admin/students?q=${encodeURIComponent(q)}&limit=100`) })
export const adminDemosQuery = (courseId: string) =>
  queryOptions({ queryKey: ['admin', 'demos', courseId], queryFn: () => api<AdminDemo[]>(`/admin/courses/${courseId}/demos`) })
export const adminStudentQuery = (id: string) => queryOptions({ queryKey: ['admin', 'students', 'detail', id], queryFn: () => api<StudentDetail>(`/admin/students/${id}`) })

// Mutaciones
export const admin = {
  createCourse: (input: ProductInput) => api<AdminProduct>('/admin/courses', json(input)),
  updateCourse: (id: string, input: ProductInput) => api<AdminProduct>(`/admin/courses/${id}`, put(input)),
  deleteCourse: (id: string) => api<void>(`/admin/courses/${id}`, del),
  createCareer: (input: ProductInput) => api<AdminProduct>('/admin/careers', json(input)),
  updateCareer: (id: string, input: ProductInput) => api<AdminProduct>(`/admin/careers/${id}`, put(input)),
  deleteCareer: (id: string) => api<void>(`/admin/careers/${id}`, del),
  setCareerCourses: (id: string, ids: string[]) => api<void>(`/admin/careers/${id}/courses`, put({ ids })),

  createModule: (courseId: string, title: string) => api<AdminModule>(`/admin/courses/${courseId}/modules`, json({ title })),
  updateModule: (id: string, title: string) => api<AdminModule>(`/admin/modules/${id}`, put({ title })),
  deleteModule: (id: string) => api<void>(`/admin/modules/${id}`, del),
  reorderModules: (courseId: string, ids: string[]) => api<void>(`/admin/courses/${courseId}/modules/order`, put({ ids })),

  createLesson: (moduleId: string, input: LessonInput) => api<AdminLesson>(`/admin/modules/${moduleId}/lessons`, json(input)),
  updateLesson: (id: string, input: LessonInput) => api<AdminLesson>(`/admin/lessons/${id}`, put(input)),
  deleteLesson: (id: string) => api<void>(`/admin/lessons/${id}`, del),
  reorderLessons: (moduleId: string, ids: string[]) => api<void>(`/admin/modules/${moduleId}/lessons/order`, put({ ids })),

  startUpload: (lessonId: string) => api<{ upload: UploadTicket }>(`/admin/lessons/${lessonId}/video`, { method: 'POST' }),
  syncVideo: (lessonId: string) => api<{ id: string; video_status: string; duration_s: number }>(`/admin/lessons/${lessonId}/video/sync`, { method: 'POST' }),

  listDemos: (courseId: string) => api<AdminDemo[]>(`/admin/courses/${courseId}/demos`),
  getDemo: (id: string) => api<AdminDemoDetail>(`/admin/demos/${id}`),
  createDemo: (courseId: string, input: DemoInput) => api<AdminDemoDetail>(`/admin/courses/${courseId}/demos`, json(input)),
  updateDemo: (id: string, input: DemoInput) => api<AdminDemoDetail>(`/admin/demos/${id}`, put(input)),
  deleteDemo: (id: string) => api<void>(`/admin/demos/${id}`, del),

  // La imagen viaja cruda con su Content-Type; el backend la guarda y
  // devuelve la URL pública para pegar en el Markdown.
  uploadImage: (file: File) =>
    api<{ url: string }>('/admin/images', { method: 'POST', body: file, headers: { 'Content-Type': file.type } }),

  refund: (orderId: string) => api<AdminOrder>(`/admin/orders/${orderId}/refund`, { method: 'POST' }),
  enroll: (userId: string, scope: 'course' | 'career', scopeId: string) => api<StudentEnrollment>(`/admin/students/${userId}/enrollments`, json({ scope, scope_id: scopeId })),
  revoke: (enrollmentId: string) => api<StudentEnrollment>(`/admin/enrollments/${enrollmentId}`, del),
}

export function move<T>(list: T[], from: number, to: number): T[] {
  if (to < 0 || to >= list.length) return list
  const next = list.slice()
  const [item] = next.splice(from, 1)
  next.splice(to, 0, item)
  return next
}
