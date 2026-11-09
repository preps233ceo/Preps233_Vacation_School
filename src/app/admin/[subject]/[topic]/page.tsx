import { createServerSupabaseClient } from '@/lib/supabase'
import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { addLesson, deleteLesson, addQuestion, deleteQuestion } from '@/app/actions'

export const dynamic = 'force-dynamic'

interface Props { params: { subject: string; topic: string } }

export default async function AdminTopicPage({ params }: Props) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) redirect('/')

  const { data: subject } = await supabase.from('subjects').select('*').eq('slug', params.subject).single()
  if (!subject) notFound()

  const { data: topic } = await supabase.from('topics').select('*').eq('subject_id', subject.id).eq('slug', params.topic).single()
  if (!topic) notFound()

  const { data: lessons } = await supabase
    .from('lessons')
    .select('*, questions(id, question, options, correct_answer, explanation, source, sort_order)')
    .eq('topic_id', topic.id)
    .order('sort_order')

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-slate-900 text-white px-6 py-4">
        <div className="max-w-5xl mx-auto flex items-center gap-2 text-sm flex-wrap">
          <Link href="/admin" className="text-white/40 hover:text-white transition-colors">Admin</Link>
          <span className="text-white/20">/</span>
          <Link href={`/admin/${subject.slug}`} className="text-white/60 hover:text-white transition-colors">{subject.name}</Link>
          <span className="text-white/20">/</span>
          <span className="text-white font-medium">{topic.title}</span>
        </div>
      </nav>

      <div className="max-w-5xl mx-auto px-6 py-8">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-xl font-bold text-gray-900" style={{ fontFamily: 'Sora, sans-serif' }}>{topic.title}</h1>
          <span className="text-sm text-gray-400">{lessons?.length ?? 0} lessons</span>
        </div>

        {/* Add lesson form */}
        <section className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm mb-8">
          <h2 className="text-base font-semibold text-gray-900 mb-4" style={{ fontFamily: 'Sora, sans-serif' }}>Add Lesson</h2>
          <form action={async (formData: FormData) => {
            'use server'
            formData.append('subject_slug', subject.slug)
            formData.append('topic_slug', topic.slug)
            await addLesson(topic.id, formData)
          }} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Lesson title *</label>
              <input name="title" required placeholder="e.g. Introduction to Quadratics"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Video provider</label>
              <select name="video_provider"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                <option value="google_drive">Google Drive</option>
                <option value="youtube">YouTube</option>
                <option value="vimeo">Vimeo</option>
                <option value="cloudflare_stream">Cloudflare Stream</option>
                <option value="bunny">Bunny.net</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">
                Video File ID *
                <span className="text-gray-400 ml-1 font-normal">(from Drive URL: /d/<strong>FILE_ID</strong>/view)</span>
              </label>
              <input name="video_id" required placeholder="1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Duration (minutes) *</label>
              <input name="duration_minutes" type="number" step="0.5" min="0.5" required defaultValue="10"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs font-medium text-gray-500 mb-1">Description (optional)</label>
              <input name="description" placeholder="Short description of what this lesson covers"
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <button type="submit"
                className="bg-indigo-500 hover:bg-indigo-600 text-white px-6 py-2.5 rounded-xl text-sm font-semibold transition-colors">
                + Add Lesson
              </button>
            </div>
          </form>
        </section>

        {/* Lessons + questions */}
        <div className="space-y-6">
          {(!lessons || lessons.length === 0) && (
            <div className="text-center py-10 text-gray-400 bg-white border border-gray-100 rounded-2xl">
              <p className="text-3xl mb-2">🎬</p>
              <p className="text-sm">No lessons yet. Add your first lesson above.</p>
            </div>
          )}

          {lessons?.map((lesson: any, li: number) => (
            <div key={lesson.id} className="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden">
              {/* Lesson header */}
              <div className="flex items-center justify-between px-5 py-4 border-b border-gray-50 bg-gray-50/50">
                <div className="flex items-center gap-3">
                  <span className="w-7 h-7 bg-indigo-100 text-indigo-600 rounded-full flex items-center justify-center text-xs font-bold">{li + 1}</span>
                  <div>
                    <h3 className="font-semibold text-gray-900 text-sm">{lesson.title}</h3>
                    <p className="text-xs text-gray-400">{Math.round(lesson.duration_seconds / 60)} min · {lesson.video_provider} · {(lesson.questions ?? []).length} questions</p>
                  </div>
                </div>
                <form action={async () => {
                  'use server'
                  await deleteLesson(lesson.id, subject.slug, topic.slug)
                }}>
                  <button type="submit" className="text-xs text-red-400 hover:text-red-600 transition-colors px-3 py-1.5 rounded-lg hover:bg-red-50">
                    Delete lesson
                  </button>
                </form>
              </div>

              {/* Questions for this lesson */}
              <div className="px-5 py-4">
                {(lesson.questions ?? []).length > 0 && (
                  <div className="space-y-2 mb-5">
                    {lesson.questions.sort((a: any, b: any) => a.sort_order - b.sort_order).map((q: any, qi: number) => (
                      <div key={q.id} className="flex items-start gap-3 bg-gray-50 rounded-xl p-3 border border-gray-100">
                        <span className="text-xs text-gray-400 font-mono mt-0.5 w-4 shrink-0">{qi + 1}</span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-800 mb-1">{q.question}</p>
                          <div className="flex flex-wrap gap-2">
                            {(q.options as string[]).map((opt: string, oi: number) => (
                              <span key={oi} className={`text-xs px-2 py-0.5 rounded-full border ${
                                oi === q.correct_answer
                                  ? 'bg-emerald-50 border-emerald-300 text-emerald-700 font-semibold'
                                  : 'bg-white border-gray-200 text-gray-500'
                              }`}>
                                {oi === q.correct_answer ? '✓ ' : ''}{opt}
                              </span>
                            ))}
                          </div>
                          {q.explanation && <p className="text-xs text-gray-400 mt-1 italic">{q.explanation}</p>}
                          {q.source && <p className="text-xs text-indigo-400 mt-0.5">📖 {q.source}</p>}
                        </div>
                        <form action={async () => {
                          'use server'
                          await deleteQuestion(q.id, subject.slug, topic.slug)
                        }}>
                          <button type="submit" className="text-xs text-red-400 hover:text-red-600 transition-colors shrink-0 px-2 py-1 rounded hover:bg-red-50">
                            ×
                          </button>
                        </form>
                      </div>
                    ))}
                  </div>
                )}

                {/* Add question form */}
                <details className="group">
                  <summary className="text-sm font-medium text-indigo-600 hover:text-indigo-700 cursor-pointer list-none flex items-center gap-1.5 select-none">
                    <span className="text-lg leading-none group-open:rotate-45 transition-transform inline-block">+</span>
                    Add question
                  </summary>
                  <form action={async (formData: FormData) => {
                    'use server'
                    formData.append('subject_slug', subject.slug)
                    formData.append('topic_slug', topic.slug)
                    await addQuestion(lesson.id, formData)
                  }} className="mt-4 space-y-3 bg-indigo-50/50 border border-indigo-100 rounded-xl p-4">
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Question *</label>
                      <textarea name="question" required rows={2} placeholder="What is the derivative of x²?"
                        className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none bg-white" />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      {(['A', 'B', 'C', 'D'] as const).map((letter, i) => (
                        <div key={letter}>
                          <label className="block text-xs font-medium text-gray-500 mb-1">Option {letter} *</label>
                          <input name={`option_${letter.toLowerCase()}`} required placeholder={`Option ${letter}`}
                            className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
                        </div>
                      ))}
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-medium text-gray-500 mb-1">Correct answer *</label>
                        <select name="correct_answer" required
                          className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                          <option value="0">A</option>
                          <option value="1">B</option>
                          <option value="2">C</option>
                          <option value="3">D</option>
                        </select>
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-500 mb-1">Source (optional)</label>
                        <input name="source" placeholder="e.g. WASSCE 2019 Q3"
                          className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-500 mb-1">Explanation (optional)</label>
                      <input name="explanation" placeholder="Why is this the correct answer?"
                        className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
                    </div>
                    <button type="submit"
                      className="bg-indigo-500 hover:bg-indigo-600 text-white px-5 py-2.5 rounded-xl text-sm font-semibold transition-colors">
                      Save question
                    </button>
                  </form>
                </details>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
