export interface DemoRef {
  slug: string
  title: string
  height_px: number
  frame_url: string
}

export interface LessonContentData {
  kind: 'video' | 'article'
  body_md: string
  reading_time_s: number
  demos: DemoRef[]
}
