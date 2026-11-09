import { createServerSupabaseClient } from '@/lib/supabase'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function AdminPage() {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('is_admin, full_name').eq('id', user.id).single()
  if (!profile?.is_admin) redirect('/')

  // Stats
  const [
    { count: subjectCount },
    { count: topicCount },
    { count: lessonCount },
    { count: questionCount },
    { count: studentCount },
    { data: subjects },
  ] = await Promise.all([
    supabase.from('subjects').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('topics').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('lessons').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('questions').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('subjects').select('*, topics(id, title, slug)').order('sort_order'),
  ])

  const stats = [
    { label: 'Active subjects', value: subjectCount ?? 0, icon: '📚' },
    { label: 'Topics', value: topicCount ?? 0, icon: '📋' },
    { label: 'Video lessons', value: lessonCount ?? 0, icon: '🎬' },
    { label: 'Quiz questions', value: questionCount ?? 0, icon: '❓' },
    { label: 'Students', value: studentCount ?? 0, icon: '👨‍🎓' },
  ]

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Admin nav */}
      <nav className="bg-slate-900 text-white px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link href="/" className="text-white/60 hover:text-white text-sm transition-colors">
              ← Preps233 Learn
            </Link>
            <span className="text-white/20">/</span>
            <span className="font-semibold">Admin Panel</span>
          </div>
          <span className="text-white/50 text-sm">{profile.full_name ?? user.email}</span>
        </div>
      </nav>

      <div className="max-w-6xl mx-auto px-6 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6" style={{ fontFamily: 'Sora, sans-serif' }}>
          Dashboard
        </h1>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4 mb-10">
          {stats.map(s => (
            <div key={s.label} className="bg-white border border-gray-100 rounded-xl p-4 shadow-sm">
              <div className="text-2xl mb-1">{s.icon}</div>
              <div className="text-2xl font-bold text-gray-900" style={{ fontFamily: 'Sora, sans-serif' }}>{s.value}</div>
              <div className="text-xs text-gray-400 mt-0.5">{s.label}</div>
            </div>
          ))}
        </div>

        {/* Subjects */}
        <h2 className="text-lg font-semibold text-gray-900 mb-4" style={{ fontFamily: 'Sora, sans-serif' }}>
          Subjects
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {subjects?.map((s: any) => (
            <Link
              key={s.id}
              href={`/admin/${s.slug}`}
              className="group bg-white border border-gray-100 hover:border-gray-200 rounded-2xl p-5 transition-all hover:shadow-sm"
            >
              <div className="flex items-center gap-3 mb-3">
                <span className="text-3xl">{s.icon}</span>
                <div>
                  <h3 className="font-semibold text-gray-900 group-hover:text-indigo-600 transition-colors">
                    {s.name}
                  </h3>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${
                    s.is_active
                      ? 'bg-emerald-50 text-emerald-600 border border-emerald-200'
                      : 'bg-gray-100 text-gray-500'
                  }`}>
                    {s.is_active ? 'Active' : 'Hidden'}
                  </span>
                </div>
              </div>
              <p className="text-xs text-gray-400">{(s.topics ?? []).length} topics</p>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
