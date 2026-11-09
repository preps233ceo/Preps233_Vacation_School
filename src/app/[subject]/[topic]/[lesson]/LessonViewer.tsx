'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import Link from 'next/link'
import { submitQuiz, updateWatchProgress } from '@/app/actions'
import { formatDuration } from '@/lib/supabase'
import type { Lesson, QuestionForClient, LessonProgress, QuizResult } from '@/lib/types'

interface Props {
  lesson: Lesson
  questions: QuestionForClient[]
  initialProgress: LessonProgress | null
  videoUrl: string
  userEmail: string
  prevLessonHref: string | null
  nextLessonHref: string | null
  subjectSlug: string
  topicSlug: string
}

const UNLOCK_THRESHOLD = 0.7  // 70% watch time to unlock quiz
const SAVE_INTERVAL = 15      // save progress every 15 seconds

export default function LessonViewer({
  lesson, questions, initialProgress, videoUrl,
  userEmail, prevLessonHref, nextLessonHref,
}: Props) {
  const [watchSeconds, setWatchSeconds] = useState(initialProgress?.watch_seconds ?? 0)
  const [tabBlocked, setTabBlocked] = useState(false)
  const [quizResult, setQuizResult] = useState<QuizResult | null>(null)
  const [answers, setAnswers] = useState<Record<number, number>>({})
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  const isActiveRef = useRef(true)
  const watchRef = useRef(watchSeconds)
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  watchRef.current = watchSeconds

  const unlockAt = Math.floor(lesson.duration_seconds * UNLOCK_THRESHOLD)
  const quizUnlocked =
    watchSeconds >= unlockAt ||
    (initialProgress?.video_completed ?? false) ||
    (initialProgress?.quiz_passed ?? false)
  const alreadyPassed = initialProgress?.quiz_passed ?? false

  // ── Watch timer ──────────────────────────────────────────────────────────────
  useEffect(() => {
    const handleVisibility = () => {
      const hidden = document.hidden
      isActiveRef.current = !hidden
      if (hidden) setTabBlocked(true)
      else setTabBlocked(false)
    }
    document.addEventListener('visibilitychange', handleVisibility)

    const tick = setInterval(() => {
      if (!isActiveRef.current) return
      setWatchSeconds(prev => {
        const next = Math.min(prev + 1, lesson.duration_seconds)
        return next
      })
    }, 1000)

    return () => {
      clearInterval(tick)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [lesson.duration_seconds])

  // ── Auto-save progress every SAVE_INTERVAL seconds ───────────────────────────
  const saveProgress = useCallback(() => {
    const ws = watchRef.current
    updateWatchProgress(lesson.id, ws, ws >= lesson.duration_seconds)
  }, [lesson.id, lesson.duration_seconds])

  useEffect(() => {
    const interval = setInterval(saveProgress, SAVE_INTERVAL * 1000)
    return () => {
      clearInterval(interval)
      saveProgress() // save on unmount
    }
  }, [saveProgress])

  // ── Context-menu block ───────────────────────────────────────────────────────
  useEffect(() => {
    const block = (e: MouseEvent) => e.preventDefault()
    document.addEventListener('contextmenu', block)
    return () => document.removeEventListener('contextmenu', block)
  }, [])

  // ── Quiz submission ───────────────────────────────────────────────────────────
  const handleSubmit = async () => {
    if (submitting) return
    if (Object.keys(answers).length < questions.length) {
      alert('Please answer all questions before submitting.')
      return
    }
    setSubmitting(true)
    try {
      const answerArray = questions.map((_, i) => answers[i] ?? -1)
      const result = await submitQuiz(lesson.id, answerArray)
      setQuizResult(result)
      setSubmitted(true)
    } catch (err) {
      alert('Failed to submit quiz. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleRetake = () => {
    setAnswers({})
    setQuizResult(null)
    setSubmitted(false)
  }

  const watchPct = lesson.duration_seconds > 0
    ? Math.min(100, Math.round((watchSeconds / lesson.duration_seconds) * 100))
    : 0

  return (
    <div>
      {/* ── Video section ─────────────────────────────────────────────────────── */}
      <div className="bg-black rounded-2xl overflow-hidden relative shadow-xl mb-6">
        {/* Watermark overlay — renders email at multiple positions */}
        <div className="absolute inset-0 pointer-events-none z-10 select-none" aria-hidden>
          {[
            'top-4 left-4', 'top-4 right-4',
            'bottom-4 left-4', 'bottom-4 right-4',
            'top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2',
          ].map((pos, i) => (
            <span
              key={i}
              className={`absolute ${pos} text-white/20 text-xs font-mono select-none`}
              style={{ transform: pos.includes('translate') ? 'translate(-50%,-50%) rotate(-25deg)' : 'rotate(-25deg)' }}
            >
              {userEmail}
            </span>
          ))}
        </div>

        {/* Tab-switch warning */}
        {tabBlocked && (
          <div className="absolute inset-0 z-20 bg-black/95 flex flex-col items-center justify-center gap-4">
            <div className="text-5xl">⚠️</div>
            <h3 className="text-white text-xl font-bold" style={{ fontFamily: 'Sora, sans-serif' }}>
              Video paused
            </h3>
            <p className="text-white/60 text-sm text-center max-w-xs">
              The watch timer stopped because you switched tabs.<br />
              Return to this tab to continue.
            </p>
          </div>
        )}

        {/* Video iframe */}
        <div className="relative w-full" style={{ paddingBottom: '56.25%' }}>
          <iframe
            src={videoUrl}
            className="absolute inset-0 w-full h-full"
            allow="autoplay"
            frameBorder="0"
            allowFullScreen
          />
        </div>
      </div>

      {/* ── Watch progress bar ────────────────────────────────────────────────── */}
      <div className="bg-white border border-gray-100 rounded-xl px-5 py-4 mb-6">
        <div className="flex items-center justify-between text-sm mb-2">
          <span className="text-gray-600 font-medium">{lesson.title}</span>
          <span className="text-gray-400">
            {formatDuration(watchSeconds)} / {formatDuration(lesson.duration_seconds)}
          </span>
        </div>
        <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all"
            style={{
              width: `${watchPct}%`,
              backgroundColor: quizUnlocked ? '#10b981' : '#6366f1',
            }}
          />
        </div>
        <div className="flex items-center justify-between mt-2">
          <p className="text-xs text-gray-400">
            {quizUnlocked
              ? '✓ You have unlocked the quiz'
              : `Watch ${Math.max(0, unlockAt - watchSeconds)}s more to unlock quiz`}
          </p>
          <span className="text-xs text-gray-400">{watchPct}%</span>
        </div>
      </div>

      {/* ── Quiz section ─────────────────────────────────────────────────────── */}
      <div className={`rounded-2xl border transition-all ${
        quizUnlocked
          ? 'bg-white border-gray-100 shadow-sm'
          : 'bg-gray-50 border-gray-100 opacity-60'
      }`}>
        <div className="px-6 py-5 border-b border-gray-100">
          <div className="flex items-center justify-between">
            <h2 className="font-semibold text-gray-900" style={{ fontFamily: 'Sora, sans-serif' }}>
              Quiz — {questions.length} question{questions.length !== 1 ? 's' : ''}
            </h2>
            {!quizUnlocked && (
              <span className="text-xs bg-gray-100 text-gray-500 px-3 py-1 rounded-full">
                🔒 Watch 70% to unlock
              </span>
            )}
            {alreadyPassed && (
              <span className="text-xs bg-emerald-50 text-emerald-600 border border-emerald-200 px-3 py-1 rounded-full font-medium">
                ✓ Passed
              </span>
            )}
          </div>
        </div>

        {!quizUnlocked ? (
          <div className="px-6 py-10 text-center text-gray-400">
            <p className="text-3xl mb-2">🎬</p>
            <p className="text-sm">Complete at least 70% of the video to unlock the quiz.</p>
          </div>
        ) : questions.length === 0 ? (
          <div className="px-6 py-10 text-center text-gray-400">
            <p className="text-sm">No quiz questions added for this lesson yet.</p>
          </div>
        ) : submitted && quizResult ? (
          /* ── Results view ── */
          <div className="px-6 py-6">
            {/* Score card */}
            <div className={`rounded-xl p-6 text-center mb-6 ${
              quizResult.passed
                ? 'bg-emerald-50 border border-emerald-200'
                : 'bg-red-50 border border-red-200'
            }`}>
              <div className="text-5xl mb-2">{quizResult.passed ? '🎉' : '😔'}</div>
              <div className="text-4xl font-bold mb-1" style={{
                fontFamily: 'Sora, sans-serif',
                color: quizResult.passed ? '#059669' : '#dc2626'
              }}>
                {quizResult.score}%
              </div>
              <p className={`font-semibold text-lg mb-1 ${quizResult.passed ? 'text-emerald-700' : 'text-red-700'}`}>
                {quizResult.passed ? 'Congratulations! You passed.' : 'Not quite — keep going!'}
              </p>
              <p className="text-sm text-gray-500">
                {quizResult.passed
                  ? 'You may proceed to the next lesson.'
                  : 'You need 80% to pass. Review your answers and try again.'}
              </p>
            </div>

            {/* Per-question feedback */}
            <div className="space-y-4 mb-6">
              {questions.map((q, i) => {
                const r = quizResult.results[i]
                return (
                  <div
                    key={q.id}
                    className={`rounded-xl p-4 border ${r.correct ? 'bg-emerald-50 border-emerald-200' : 'bg-red-50 border-red-200'}`}
                  >
                    <div className="flex items-start gap-2">
                      <span className="shrink-0 mt-0.5">{r.correct ? '✅' : '❌'}</span>
                      <div>
                        <p className="font-medium text-gray-900 text-sm mb-1">{q.question}</p>
                        <p className="text-sm">
                          <span className="text-gray-500">Your answer: </span>
                          <span className={r.correct ? 'text-emerald-700 font-medium' : 'text-red-700 font-medium'}>
                            {q.options[answers[i]] ?? '—'}
                          </span>
                        </p>
                        {!r.correct && (
                          <p className="text-sm text-gray-500 mt-0.5">
                            Correct: <span className="text-emerald-700 font-medium">{q.options[/* correct_answer not available */0] ?? '—'}</span>
                          </p>
                        )}
                        {r.explanation && (
                          <p className="text-sm text-gray-600 mt-2 bg-white/60 rounded-lg px-3 py-2">
                            💡 {r.explanation}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>

            {/* Actions */}
            <div className="flex gap-3">
              {!quizResult.passed && (
                <button
                  onClick={handleRetake}
                  className="flex-1 bg-indigo-500 hover:bg-indigo-600 text-white py-3 rounded-xl font-semibold text-sm transition-colors"
                >
                  Retake Quiz
                </button>
              )}
              {nextLessonHref && quizResult.passed && (
                <Link
                  href={nextLessonHref}
                  className="flex-1 bg-emerald-500 hover:bg-emerald-600 text-white py-3 rounded-xl font-semibold text-sm transition-colors text-center"
                >
                  Next Lesson →
                </Link>
              )}
            </div>
          </div>
        ) : (
          /* ── Quiz questions ── */
          <div className="px-6 py-5">
            {alreadyPassed && (
              <div className="bg-emerald-50 border border-emerald-200 rounded-xl px-4 py-3 mb-5 text-sm text-emerald-700">
                ✓ You already passed this quiz. You can retake it to review.
              </div>
            )}
            {initialProgress && (initialProgress.quiz_attempts ?? 0) > 0 && !alreadyPassed && (
              <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 mb-5 text-sm text-amber-700">
                Previous attempt: {initialProgress.quiz_score ?? 0}% — keep trying!
              </div>
            )}

            <div className="space-y-6">
              {questions.map((q, qi) => (
                <div key={q.id}>
                  <p className="font-medium text-gray-900 mb-3">
                    <span className="text-indigo-500 font-bold mr-1">{qi + 1}.</span>
                    {q.question}
                  </p>
                  {q.source && (
                    <p className="text-xs text-gray-400 mb-2">📖 {q.source}</p>
                  )}
                  <div className="space-y-2">
                    {(q.options as string[]).map((opt, oi) => (
                      <label
                        key={oi}
                        className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                          answers[qi] === oi
                            ? 'bg-indigo-50 border-indigo-300'
                            : 'bg-gray-50 border-gray-100 hover:bg-indigo-50 hover:border-indigo-200'
                        }`}
                      >
                        <input
                          type="radio"
                          name={`q-${qi}`}
                          value={oi}
                          checked={answers[qi] === oi}
                          onChange={() => setAnswers(prev => ({ ...prev, [qi]: oi }))}
                          className="accent-indigo-500"
                        />
                        <span className="text-sm text-gray-700">{opt}</span>
                      </label>
                    ))}
                  </div>
                </div>
              ))}
            </div>

            <button
              onClick={handleSubmit}
              disabled={submitting || Object.keys(answers).length < questions.length}
              className="mt-6 w-full bg-indigo-500 hover:bg-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed text-white py-3.5 rounded-xl font-semibold text-sm transition-colors"
            >
              {submitting ? 'Submitting…' : `Submit Quiz (${Object.keys(answers).length}/${questions.length} answered)`}
            </button>
          </div>
        )}
      </div>

      {/* ── Navigation ───────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between mt-6">
        {prevLessonHref ? (
          <Link
            href={prevLessonHref}
            className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors bg-white border border-gray-100 px-4 py-2.5 rounded-xl hover:shadow-sm"
          >
            ← Previous lesson
          </Link>
        ) : <div />}
        {nextLessonHref ? (
          <Link
            href={nextLessonHref}
            className={`flex items-center gap-2 text-sm px-4 py-2.5 rounded-xl transition-all border ${
              (quizResult?.passed ?? alreadyPassed)
                ? 'bg-emerald-500 hover:bg-emerald-600 text-white border-emerald-500 shadow-sm'
                : 'text-gray-400 bg-gray-50 border-gray-100 cursor-not-allowed opacity-50 pointer-events-none'
            }`}
          >
            Next lesson →
          </Link>
        ) : <div />}
      </div>
    </div>
  )
}
