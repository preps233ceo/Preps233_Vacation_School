import { createServerSupabaseClient, formatDuration } from '@/lib/supabase'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import type { Lesson } from '@/lib/types'

export const dynamic = 'force-dynamic'

interface Props {
  params: { subject: string; topic: string }
}

export default async function TopicPage({ params }: Props) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: subject } = await supabase
    .from('subjects')
    .select('id, name, slug, icon, color')
    .eq('slug', params.subject)
    .eq('is_active', true)
    .single()

  if (!subject) notFound()

  const { data: topic } = await supabase
    .from('topics')
    .select('*')
    .eq('subject_id', subject.id)
    .eq('slug', params.topic)
    .eq('is_active', true)
    .single()

  if (!topic) notFound()

  const { data: lessons } = await supabase
    .from('lessons')
    .select('*')
    .eq('topic_id', topic.id)
    .eq('is_active', true)
    .order('sort_order')

  const lessonList = lessons ?? []

  // User progress
  let progressMap: Record<string, { watch_seconds: number; quiz_passed: boolean }> = {}
  if (user && lessonList.length > 0) {
    const { data: prog } = await supabase
      .from('lesson_progress')
      .select('lesson_id, watch_seconds, quiz_passed')
      .eq('user_id', user.id)
      .in('lesson_id', lessonList.map(l => l.id))

    ;(prog ?? []).forEach(p => {
      progressMap[p.lesson_id] = { watch_seconds: p.watch_seconds, quiz_passed: p.quiz_passed }
    })
  }

  const passedCount = Object.values(progressMap).filter(p => p.quiz_passed).length

  // Sequential unlock: lesson i is unlocked if lesson i-1 is quiz_passed
  const isLessonUnlocked = (index: number): boolean => {
    if (index === 0) return true
    const prev = lessonList[index - 1]
    return progressMap[prev.id]?.quiz_passed ?? false
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div style={{ backgroundColor: subject.color }} className="relative overflow-hidden">
        <div className="absolute inset-0 opacity-10" style={{ background: 'radial-gradient(circle at 70% 50%, white, transparent)' }} />
        <div className="relative max-w-4xl mx-auto px-6 py-10">
          {/* Breadcrumb */}
          <nav className="flex items-center gap-1.5 text-white/60 text-sm mb-6">
            <Link href="/" className="hover:text-white transition-colors">Home</Link>
            <span>/</span>
            <Link href={`/${subject.slug}`} className="hover:text-white transition-colors">
              {subject.icon} {subject.name}
            </Link>
            <span>/</span>
            <span className="text-white">{topic.title}</span>
          </nav>

          <h1 className="text-2xl font-bold text-white mb-1" style={{ fontFamily: 'Sora, sans-serif' }}>
            {topic.title}
          </h1>
          {topic.description && (
            <p className="text-white/80 text-sm">{topic.description}</p>
          )}
          <div className="mt-4 flex gap-5 text-white/70 text-sm">
            <span>{lessonList.length} lesson{lessonList.length !== 1 ? 's' : ''}</span>
            {user && lessonList.length > 0 && (
              <span>{passedCount}/{lessonList.length} completed</span>
            )}
          </div>
        </div>
      </div>

      {/* Lessons list */}
      <div className="max-w-4xl mx-auto px-6 py-8">
        {lessonList.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <p className="text-4xl mb-3">🎬</p>
            <p className="font-medium">No lessons added yet</p>
            <p className="text-sm mt-1">Check back soon!</p>
          </div>
        ) : (
          <div className="space-y-3">
            {lessonList.map((lesson, i) => {
              const unlocked = isLessonUnlocked(i)
              const prog = progressMap[lesson.id]
              const quizPassed = prog?.quiz_passed ?? false
              const watchPct = lesson.duration_seconds > 0
                ? Math.min(100, Math.round(((prog?.watch_seconds ?? 0) / lesson.duration_seconds) * 100))
                : 0

              return (
                <LessonCard
                  key={lesson.id}
                  lesson={lesson}
                  number={i + 1}
                  subjectSlug={params.subject}
                  topicSlug={params.topic}
                  unlocked={unlocked}
                  quizPassed={quizPassed}
                  watchPct={watchPct}
                />
              )
            })}
          </div>
        )}

        {/* Back link */}
        <div className="mt-8">
          <Link href={`/${subject.slug}`} className="text-sm text-gray-500 hover:text-gray-700 transition-colors">
            ← Back to {subject.name}
          </Link>
        </div>
      </div>
    </div>
  )
}

interface LessonCardProps {
  lesson: Lesson
  number: number
  subjectSlug: string
  topicSlug: string
  unlocked: boolean
  quizPassed: boolean
  watchPct: number
}

function LessonCard({ lesson, number, subjectSlug, topicSlug, unlocked, quizPassed, watchPct }: LessonCardProps) {
  const duration = formatDuration(lesson.duration_seconds)

  if (!unlocked) {
    return (
      <div className="bg-white border border-gray-100 rounded-2xl p-5 opacity-60 cursor-not-allowed">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-400 shrink-0 text-lg">
            🔒
          </div>
          <div>
            <h3 className="font-semibold text-gray-700">{lesson.title}</h3>
            <p className="text-xs text-gray-400 mt-0.5">{duration} · Pass previous lesson to unlock</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <Link
      href={`/${subjectSlug}/${topicSlug}/${lesson.id}`}
      className="group block bg-white border border-gray-100 hover:border-gray-200 rounded-2xl p-5 transition-all hover:shadow-sm"
    >
      <div className="flex items-center gap-4">
        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shrink-0 ${
            quizPassed
              ? 'bg-emerald-100 text-emerald-600'
              : 'bg-indigo-50 text-indigo-600'
          }`}
        >
          {quizPassed ? '✓' : number}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2">
            <h3 className="font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors truncate">
              {lesson.title}
            </h3>
            <div className="flex items-center gap-2 shrink-0">
              {quizPassed ? (
                <span className="text-xs bg-emerald-50 text-emerald-600 border border-emerald-200 px-2 py-0.5 rounded-full font-medium">
                  Passed
                </span>
              ) : watchPct > 0 ? (
                <span className="text-xs text-gray-400">{watchPct}% watched</span>
              ) : null}
              <span className="text-xs text-gray-400">{duration}</span>
            </div>
          </div>
          {lesson.description && (
            <p className="text-gray-500 text-sm truncate mt-0.5">{lesson.description}</p>
          )}
          {!quizPassed && watchPct > 0 && (
            <div className="mt-2 h-1 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-indigo-300 rounded-full"
                style={{ width: `${watchPct}%` }}
              />
            </div>
          )}
        </div>
        <span className="text-gray-300 group-hover:text-indigo-400 transition-colors shrink-0">▶</span>
      </div>
    </Link>
  )
}
