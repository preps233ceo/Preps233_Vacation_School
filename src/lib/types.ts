export type VideoProvider = 'google_drive' | 'youtube' | 'vimeo' | 'cloudflare_stream' | 'bunny'

export interface Subject {
  id: string
  name: string
  slug: string
  description: string | null
  icon: string
  color: string
  is_active: boolean
  sort_order: number
  created_at: string
}

export interface Topic {
  id: string
  subject_id: string
  title: string
  slug: string
  description: string | null
  sort_order: number
  is_active: boolean
  created_at: string
}

export interface Lesson {
  id: string
  topic_id: string
  title: string
  description: string | null
  video_provider: VideoProvider
  video_id: string
  duration_seconds: number
  sort_order: number
  is_active: boolean
  created_at: string
}

export interface Question {
  id: string
  lesson_id: string
  question: string
  options: string[]
  correct_answer: number
  explanation: string | null
  source: string | null
  sort_order: number
  created_at: string
}

// Sent to client — correct_answer is never included
export type QuestionForClient = Omit<Question, 'correct_answer'>

export interface Profile {
  id: string
  full_name: string | null
  is_admin: boolean
  created_at: string
  updated_at: string
}

export interface LessonProgress {
  id: string
  user_id: string
  lesson_id: string
  watch_seconds: number
  video_completed: boolean
  quiz_score: number | null
  quiz_passed: boolean
  quiz_attempts: number
  passed_at: string | null
  updated_at: string
}

export interface QuizResult {
  score: number
  passed: boolean
  results: Array<{ correct: boolean; explanation: string | null }>
}

export type Database = {
  public: {
    Tables: {
      subjects: {
        Row: Subject
        Insert: Omit<Subject, 'id' | 'created_at'> & { id?: string; created_at?: string }
        Update: Partial<Omit<Subject, 'id' | 'created_at'>>
      }
      topics: {
        Row: Topic
        Insert: Omit<Topic, 'id' | 'created_at'> & { id?: string; created_at?: string }
        Update: Partial<Omit<Topic, 'id' | 'created_at'>>
      }
      lessons: {
        Row: Lesson
        Insert: Omit<Lesson, 'id' | 'created_at'> & { id?: string; created_at?: string }
        Update: Partial<Omit<Lesson, 'id' | 'created_at'>>
      }
      questions: {
        Row: Question
        Insert: Omit<Question, 'id' | 'created_at'> & { id?: string; created_at?: string }
        Update: Partial<Omit<Question, 'id' | 'created_at'>>
      }
      profiles: {
        Row: Profile
        Insert: Omit<Profile, 'created_at' | 'updated_at'> & { created_at?: string; updated_at?: string }
        Update: Partial<Omit<Profile, 'id' | 'created_at'>>
      }
      lesson_progress: {
        Row: LessonProgress
        Insert: Omit<LessonProgress, 'id' | 'updated_at'> & { id?: string; updated_at?: string }
        Update: Partial<Omit<LessonProgress, 'id' | 'user_id' | 'lesson_id'>>
      }
    }
  }
}
