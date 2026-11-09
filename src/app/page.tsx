import { createServerSupabaseClient } from '@/lib/supabase'
import Link from 'next/link'
import type { Subject } from '@/lib/types'
import AuthNav from './AuthNav'

export const dynamic = 'force-dynamic'

export default async function HomePage() {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: subjects } = await supabase
    .from('subjects')
    .select('*')
    .order('sort_order')

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(135deg, #0f172a 0%, #1e1b4b 50%, #0f172a 100%)' }}>
      {/* Nav */}
      <nav className="border-b border-white/10 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-indigo-500 rounded-xl flex items-center justify-center text-white font-bold text-base shadow-lg shadow-indigo-500/30">
              P
            </div>
            <span className="text-white font-bold text-xl" style={{ fontFamily: 'Sora, sans-serif' }}>
              Preps233 Learn
            </span>
          </div>
          <AuthNav user={user ? { email: user.email ?? '' } : null} />
        </div>
      </nav>

      {/* Hero */}
      <div className="max-w-6xl mx-auto px-6 pt-20 pb-14 text-center">
        <div className="inline-flex items-center gap-2 bg-indigo-500/20 border border-indigo-500/30 text-indigo-300 text-sm px-4 py-2 rounded-full mb-8">
          <span>🎓</span>
          <span>WASSCE Preparation Platform</span>
        </div>
        <h1 className="text-5xl sm:text-6xl font-bold text-white mb-5 leading-tight" style={{ fontFamily: 'Sora, sans-serif' }}>
          Learn at your own pace.<br />
          <span className="text-indigo-400">Pass with confidence.</span>
        </h1>
        <p className="text-white/60 text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
          Watch expert video lessons, complete quizzes, and unlock each topic as you go.
          Score 80% to advance.
        </p>
        {!user && (
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Link
              href="/login"
              className="inline-flex items-center justify-center gap-2 bg-indigo-500 hover:bg-indigo-400 text-white px-8 py-4 rounded-xl font-semibold text-base transition-colors shadow-lg shadow-indigo-500/30"
            >
              Get started free →
            </Link>
            <Link
              href="/login"
              className="inline-flex items-center justify-center gap-2 bg-white/10 hover:bg-white/15 text-white px-8 py-4 rounded-xl font-semibold text-base transition-colors border border-white/20"
            >
              Sign in
            </Link>
          </div>
        )}
      </div>

      {/* Subjects grid */}
      <div className="max-w-6xl mx-auto px-6 pb-24">
        <p className="text-white/40 text-xs font-semibold uppercase tracking-widest mb-5">
          Available subjects
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {subjects?.map(subject => (
            <SubjectCard key={subject.id} subject={subject} />
          ))}
        </div>
      </div>

      {/* Footer */}
      <div className="border-t border-white/10 px-6 py-6 text-center text-white/30 text-sm">
        © {new Date().getFullYear()} Preps233. All rights reserved.
      </div>
    </div>
  )
}

function SubjectCard({ subject }: { subject: Subject }) {
  if (!subject.is_active) {
    return (
      <div className="relative bg-white/5 border border-white/10 rounded-2xl p-6 opacity-50 cursor-not-allowed select-none">
        <div className="flex items-start justify-between mb-4">
          <span className="text-4xl">{subject.icon}</span>
          <span className="text-xs bg-white/10 text-white/50 px-2.5 py-1 rounded-full font-medium">
            Coming soon
          </span>
        </div>
        <h3 className="text-white font-semibold text-lg mb-2" style={{ fontFamily: 'Sora, sans-serif' }}>
          {subject.name}
        </h3>
        <p className="text-white/40 text-sm leading-relaxed line-clamp-2">{subject.description}</p>
      </div>
    )
  }

  return (
    <Link
      href={`/${subject.slug}`}
      className="group relative bg-white/5 hover:bg-white/10 border border-white/10 hover:border-white/20 rounded-2xl p-6 transition-all duration-200"
    >
      <div className="flex items-start justify-between mb-4">
        <span className="text-4xl">{subject.icon}</span>
        <span
          className="text-xs px-2.5 py-1 rounded-full font-medium"
          style={{ backgroundColor: `${subject.color}20`, color: subject.color }}
        >
          Active
        </span>
      </div>
      <h3
        className="text-white font-semibold text-lg mb-2"
        style={{ fontFamily: 'Sora, sans-serif' }}
      >
        {subject.name}
      </h3>
      <p className="text-white/50 text-sm leading-relaxed line-clamp-2 mb-4">{subject.description}</p>
      <div
        className="flex items-center gap-1 text-sm font-medium transition-transform group-hover:translate-x-1"
        style={{ color: subject.color }}
      >
        Start learning <span>→</span>
      </div>
    </Link>
  )
}
