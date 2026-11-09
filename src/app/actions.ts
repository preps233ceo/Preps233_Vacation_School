'use server'

import { createServerSupabaseClient } from '@/lib/supabase'
import { revalidatePath } from 'next/cache'
import { slugify } from '@/lib/supabase'
import type { QuizResult } from '@/lib/types'

// ── Quiz scoring ──────────────────────────────────────────────────────────────
// Correct answers are fetched here (server only) and never sent to the client.
export async function submitQuiz(lessonId: string, answers: number[]): Promise<QuizResult> {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const { data: questions, error } = await supabase
    .from('questions')
    .select('id, correct_answer, explanation')
    .eq('lesson_id', lessonId)
    .order('sort_order')

  if (error || !questions) throw new Error('Failed to load questions')

  const results = questions.map((q, i) => ({
    correct: answers[i] === q.correct_answer,
    explanation: q.explanation,
  }))

  const correctCount = results.filter(r => r.correct).length
  const score = questions.length > 0 ? Math.round((correctCount / questions.length) * 100) : 0
  const passed = score >= 80

  // Load existing progress to preserve best state
  const { data: existing } = await supabase
    .from('lesson_progress')
    .select('quiz_attempts, quiz_passed, quiz_score')
    .eq('user_id', user.id)
    .eq('lesson_id', lessonId)
    .maybeSingle()

  const prevPassed = existing?.quiz_passed ?? false
  const prevBestScore = existing?.quiz_score ?? 0
  const attempts = (existing?.quiz_attempts ?? 0) + 1

  await supabase.from('lesson_progress').upsert(
    {
      user_id: user.id,
      lesson_id: lessonId,
      quiz_score: Math.max(score, prevBestScore),
      quiz_passed: passed || prevPassed,
      quiz_attempts: attempts,
      passed_at: passed && !prevPassed ? new Date().toISOString() : undefined,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,lesson_id' }
  )

  return { score, passed, results }
}

// ── Video watch progress ──────────────────────────────────────────────────────
export async function updateWatchProgress(
  lessonId: string,
  watchSeconds: number,
  videoCompleted: boolean
): Promise<void> {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  await supabase.from('lesson_progress').upsert(
    {
      user_id: user.id,
      lesson_id: lessonId,
      watch_seconds: watchSeconds,
      video_completed: videoCompleted,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,lesson_id' }
  )
}

// ── Admin: Subject management ─────────────────────────────────────────────────
export async function updateSubject(subjectId: string, formData: FormData) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  await supabase.from('subjects').update({
    name: formData.get('name') as string,
    description: formData.get('description') as string,
    icon: formData.get('icon') as string,
    color: formData.get('color') as string,
    is_active: formData.get('is_active') === 'true',
  }).eq('id', subjectId)

  revalidatePath('/admin')
  revalidatePath(`/admin/${formData.get('slug')}`)
}

// ── Admin: Topic management ───────────────────────────────────────────────────
export async function addTopic(subjectId: string, formData: FormData) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  const title = formData.get('title') as string
  const slug = slugify(title)

  const { data: existing } = await supabase
    .from('topics')
    .select('sort_order')
    .eq('subject_id', subjectId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle()

  await supabase.from('topics').insert({
    subject_id: subjectId,
    title,
    slug,
    description: formData.get('description') as string || null,
    sort_order: (existing?.sort_order ?? 0) + 1,
  })

  revalidatePath(`/admin/${formData.get('subject_slug')}`)
}

export async function deleteTopic(topicId: string, subjectSlug: string) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  await supabase.from('topics').delete().eq('id', topicId)
  revalidatePath(`/admin/${subjectSlug}`)
}

// ── Admin: Lesson management ──────────────────────────────────────────────────
export async function addLesson(topicId: string, formData: FormData) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  const title = formData.get('title') as string
  const durationMinutes = parseFloat(formData.get('duration_minutes') as string) || 5
  const durationSeconds = Math.round(durationMinutes * 60)

  const { data: existing } = await supabase
    .from('lessons')
    .select('sort_order')
    .eq('topic_id', topicId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle()

  await supabase.from('lessons').insert({
    topic_id: topicId,
    title,
    description: formData.get('description') as string || null,
    video_provider: (formData.get('video_provider') as string) || 'google_drive',
    video_id: formData.get('video_id') as string,
    duration_seconds: durationSeconds,
    sort_order: (existing?.sort_order ?? 0) + 1,
  })

  revalidatePath(`/admin/${formData.get('subject_slug')}/${formData.get('topic_slug')}`)
}

export async function deleteLesson(lessonId: string, subjectSlug: string, topicSlug: string) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  await supabase.from('lessons').delete().eq('id', lessonId)
  revalidatePath(`/admin/${subjectSlug}/${topicSlug}`)
}

// ── Admin: Question management ────────────────────────────────────────────────
export async function addQuestion(lessonId: string, formData: FormData) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  const options = [
    formData.get('option_a') as string,
    formData.get('option_b') as string,
    formData.get('option_c') as string,
    formData.get('option_d') as string,
  ].filter(Boolean)

  const { data: existing } = await supabase
    .from('questions')
    .select('sort_order')
    .eq('lesson_id', lessonId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle()

  await supabase.from('questions').insert({
    lesson_id: lessonId,
    question: formData.get('question') as string,
    options,
    correct_answer: parseInt(formData.get('correct_answer') as string, 10),
    explanation: formData.get('explanation') as string || null,
    source: formData.get('source') as string || null,
    sort_order: (existing?.sort_order ?? 0) + 1,
  })

  revalidatePath(`/admin/${formData.get('subject_slug')}/${formData.get('topic_slug')}`)
}

export async function deleteQuestion(
  questionId: string,
  subjectSlug: string,
  topicSlug: string
) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const profile = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile.data?.is_admin) throw new Error('Not authorized')

  await supabase.from('questions').delete().eq('id', questionId)
  revalidatePath(`/admin/${subjectSlug}/${topicSlug}`)
}
