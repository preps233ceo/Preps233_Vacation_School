import { createServerSupabaseClient, getVideoEmbedUrl } from '@/lib/supabase'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import LessonViewer from './LessonViewer'
import type { QuestionForClient, LessonProgress } from '@/lib/types'

export const dynamic = 'force-dynamic'

interface Props {
  params: { subject: string; topic: string; lesson: string }
}

export default async function LessonPage({ params }: Props) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) notFound()

  // Load subject
  const { data: subject } = await supabase
    .from('subjects')
    .select('id, name, slug, icon, color')
    .eq('slug', params.subject)
    .single()
  if (!subject) notFound()

  // Load topic
  const { data: topic } = await supabase
    .from('topics')
    .select('id, title, slug')
    .eq('subject_id', subject.id)
    .eq('slug', params.topic)
    .single()
  if (!topic) notFound()

  // Load lesson by ID (params.lesson is the lesson UUID)
  const { data: lesson } = await supabase
    .from('lessons')
    .select('*')
    .eq('topic_id', topic.id)
    .eq('id', params.lesson)
    .eq('is_active', true)
    .single()
  if (!lesson) notFound()

  // Load questions WITHOUT correct_answer
  const { data: questionsRaw } = await supabase
    .from('questions')
    .select('id, lesson_id, question, options, explanation, source, sort_order, created_at')
    .eq('lesson_id', lesson.id)
    .order('sort_order')

  const questions: QuestionForClient[] = questionsRaw ?? []

  // Load user's existing progress for this lesson
  const { data: progress } = await supabase
    .from('lesson_progress')
    .select('*')
    .eq('user_id', user.id)
    .eq('lesson_id', lesson.id)
    .maybeSingle()

  // Find previous and next lessons for navigation
  const { data: allLessons } = await supabase
    .from('lessons')
    .select('id, sort_order')
    .eq('topic_id', topic.id)
    .eq('is_active', true)
    .order('sort_order')

  const lessonIdx = (allLessons ?? []).findIndex(l => l.id === lesson.id)
  const prevLesson = lessonIdx > 0 ? allLessons![lessonIdx - 1] : null
  const nextLesson = lessonIdx < (allLessons ?? []).length - 1 ? allLessons![lessonIdx + 1] : null

  const prevHref = prevLesson ? `/${params.subject}/${params.topic}/${prevLesson.id}` : null
  const nextHref = nextLesson ? `/${params.subject}/${params.topic}/${nextLesson.id}` : null

  const videoUrl = getVideoEmbedUrl(lesson.video_provider, lesson.video_id)
  const userEmail = user.email ?? ''

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Top nav */}
      <div className="bg-white border-b border-gray-100 sticky top-0 z-30 shadow-sm">
        <div className="max-w-5xl mx-auto px-4 py-3 flex items-center gap-2 text-sm">
          <Link href="/" className="text-gray-400 hover:text-gray-600 transition-colors font-medium">
            Preps233 Learn
          </Link>
          <span className="text-gray-200">/</span>
          <Link href={`/${subject.slug}`} className="text-gray-500 hover:text-gray-700 transition-colors truncate max-w-[100px]">
            {subject.icon} {subject.name}
          </Link>
          <span className="text-gray-200">/</span>
          <Link href={`/${subject.slug}/${topic.slug}`} className="text-gray-500 hover:text-gray-700 transition-colors truncate max-w-[120px]">
            {topic.title}
          </Link>
          <span className="text-gray-200">/</span>
          <span className="text-gray-900 font-medium truncate">{lesson.title}</span>
        </div>
      </div>

      {/* Main content */}
      <div className="max-w-5xl mx-auto px-4 py-6">
        <LessonViewer
          lesson={lesson}
          questions={questions}
          initialProgress={progress as LessonProgress | null}
          videoUrl={videoUrl}
          userEmail={userEmail}
          prevLessonHref={prevHref}
          nextLessonHref={nextHref}
          subjectSlug={params.subject}
          topicSlug={params.topic}
        />
      </div>
    </div>
  )
}
