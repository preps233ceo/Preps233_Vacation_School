import { createServerSupabaseClient } from '@/lib/supabase'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import type { Topic } from '@/lib/types'

export const dynamic = 'force-dynamic'

interface Props {
  params: { subject: string }
}

export default async function SubjectPage({ params }: Props) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: subject } = await supabase
    .from('subjects')
    .select('*')
    .eq('slug', params.subject)
    .eq('is_active', true)
    .single()

  if (!subject) notFound()

  // Topics with lesson count
  const { data: topicsRaw } = await supabase
    .from('topics')
    .select('*, lessons(id)')
    .eq('subject_id', subject.id)
    .eq('is_active', true)
    .order('sort_order')

  const topics = topicsRaw ?? []

  // User's progress: how many lessons passed per topic
  let passedMap: Record<string, number> = {}
  if (user) {
    const allLessonIds = topics.flatMap((t: any) => (t.lessons ?? []).map((l: any) => l.id))
    if (allLessonIds.length > 0) {
      const { data: prog } = await supabase
        .from('lesson_progress')
        .select('lesson_id, quiz_passed')
        .eq('user_id', user.id)
        .in('lesson_id', allLessonIds)

      const passedLessonIds = new Set((prog ?? []).filter(p => p.quiz_passed).map(p => p.lesson_id))

      topics.forEach((topic: any) => {
        const count = (topic.lessons ?? []).filter((l: any) => passedLessonIds.has(l.id)).length
        passedMap[topic.id] = count
      })
    }
  }

  // Sequential unlock: topic i is unlocked if all lessons in topic i-1 are passed
  const isTopicUnlocked = (index: number): boolean => {
    if (index === 0) return true
    const prev = topics[index - 1] as any
    const prevTotal = (prev.lessons ?? []).length
    if (prevTotal === 0) return true
    return (passedMap[prev.id] ?? 0) >= prevTotal
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Subject header */}
      <div style={{ backgroundColor: subject.color }} className="relative overflow-hidden">
        <div className="absolute inset-0 opacity-10" style={{ background: 'radial-gradient(circle at 70% 50%, white, transparent)' }} />
        <div className="relative max-w-4xl mx-auto px-6 py-12">
          <Link href="/" className="inline-flex items-center gap-1.5 text-white/70 hover:text-white text-sm mb-6 transition-colors">
            ← Back to subjects
          </Link>
          <div className="flex items-center gap-5">
            <span className="text-6xl drop-shadow-lg">{subject.icon}</span>
            <div>
              <h1 className="text-3xl font-bold text-white mb-1" style={{ fontFamily: 'Sora, sans-serif' }}>
                {subject.name}
              </h1>
              <p className="text-white/80 text-base">{subject.description}</p>
            </div>
          </div>
          <div className="mt-6 flex gap-6 text-white/70 text-sm">
            <span>{topics.length} topic{topics.length !== 1 ? 's' : ''}</span>
            <span>{topics.reduce((acc: number, t: any) => acc + (t.lessons?.length ?? 0), 0)} lessons total</span>
          </div>
        </div>
      </div>

      {/* Topics */}
      <div className="max-w-4xl mx-auto px-6 py-10">
        {!user && (
          <div className="bg-indigo-50 border border-indigo-200 rounded-xl px-5 py-4 mb-6 flex items-center justify-between">
            <p className="text-indigo-800 text-sm">
              <strong>Sign in to track your progress</strong> — unlock topics as you complete lessons.
            </p>
            <Link href="/login" className="bg-indigo-500 hover:bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg transition-colors font-medium shrink-0 ml-4">
              Sign in
            </Link>
          </div>
        )}

        <h2 className="text-lg font-semibold text-gray-900 mb-4" style={{ fontFamily: 'Sora, sans-serif' }}>
          Topics
        </h2>

        {topics.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <p className="text-4xl mb-3">📚</p>
            <p className="font-medium">No topics added yet</p>
            <p className="text-sm mt-1">Check back soon!</p>
          </div>
        ) : (
          <div className="space-y-3">
            {topics.map((topic: any, i: number) => {
              const totalLessons = (topic.lessons ?? []).length
              const passedLessons = passedMap[topic.id] ?? 0
              const isComplete = totalLessons > 0 && passedLessons >= totalLessons
              const isUnlocked = isTopicUnlocked(i)
              const progress = totalLessons > 0 ? (passedLessons / totalLessons) * 100 : 0

              return (
                <TopicCard
                  key={topic.id}
                  topic={topic}
                  subjectSlug={subject.slug}
                  totalLessons={totalLessons}
                  passedLessons={passedLessons}
                  progress={progress}
                  isComplete={isComplete}
                  isUnlocked={isUnlocked}
                  number={i + 1}
                />
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

interface TopicCardProps {
  topic: Topic
  subjectSlug: string
  totalLessons: number
  passedLessons: number
  progress: number
  isComplete: boolean
  isUnlocked: boolean
  number: number
}

function TopicCard({
  topic, subjectSlug, totalLessons, passedLessons,
  progress, isComplete, isUnlocked, number
}: TopicCardProps) {
  if (!isUnlocked) {
    return (
      <div className="bg-white border border-gray-100 rounded-2xl p-5 opacity-60 cursor-not-allowed">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-400 font-bold text-sm shrink-0">
            🔒
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <h3 className="font-semibold text-gray-700">{topic.title}</h3>
            </div>
            {topic.description && (
              <p className="text-gray-400 text-sm mt-0.5 truncate">{topic.description}</p>
            )}
          </div>
          <span className="text-xs text-gray-400 shrink-0">Complete previous topic first</span>
        </div>
      </div>
    )
  }

  return (
    <Link
      href={`/${subjectSlug}/${topic.slug}`}
      className="group block bg-white border border-gray-100 hover:border-gray-200 rounded-2xl p-5 transition-all hover:shadow-sm"
    >
      <div className="flex items-center gap-4">
        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shrink-0 ${
            isComplete
              ? 'bg-emerald-100 text-emerald-600'
              : 'bg-indigo-50 text-indigo-600'
          }`}
        >
          {isComplete ? '✓' : number}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2 mb-1">
            <h3 className="font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors">
              {topic.title}
            </h3>
            {totalLessons > 0 && (
              <span className="text-xs text-gray-400 shrink-0">
                {passedLessons}/{totalLessons} passed
              </span>
            )}
          </div>
          {topic.description && (
            <p className="text-gray-500 text-sm truncate mb-2">{topic.description}</p>
          )}
          {totalLessons > 0 && (
            <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full transition-all ${isComplete ? 'bg-emerald-400' : 'bg-indigo-400'}`}
                style={{ width: `${progress}%` }}
              />
            </div>
          )}
        </div>
        <span className="text-gray-300 group-hover:text-indigo-400 transition-colors shrink-0">→</span>
      </div>
    </Link>
  )
}
