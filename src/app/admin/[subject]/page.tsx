import { createServerSupabaseClient } from '@/lib/supabase'
import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { addTopic, deleteTopic, updateSubject } from '@/app/actions'

export const dynamic = 'force-dynamic'

interface Props { params: { subject: string } }

export default async function AdminSubjectPage({ params }: Props) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('is_admin').eq('id', user.id).single()
  if (!profile?.is_admin) redirect('/')

  const { data: subject } = await supabase.from('subjects').select('*').eq('slug', params.subject).single()
  if (!subject) notFound()

  const { data: topics } = await supabase
    .from('topics')
    .select('*, lessons(id)')
    .eq('subject_id', subject.id)
    .order('sort_order')

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-slate-900 text-white px-6 py-4">
        <div className="max-w-5xl mx-auto flex items-center gap-2 text-sm">
          <Link href="/" className="text-white/40 hover:text-white transition-colors">Home</Link>
          <span className="text-white/20">/</span>
          <Link href="/admin" className="text-white/60 hover:text-white transition-colors">Admin</Link>
          <span className="text-white/20">/</span>
          <span className="text-white font-medium">{subject.name}</span>
        </div>
      </nav>

      <div className="max-w-5xl mx-auto px-6 py-8 space-y-8">
        {/* Subject settings */}
        <section className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-900 mb-5" style={{ fontFamily: 'Sora, sans-serif' }}>
            Subject Settings
          </h2>
          <form action={async (formData: FormData) => {
            'use server'
            await updateSubject(subject.id, formData)
          }} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <input type="hidden" name="slug" value={subject.slug} />
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Name</label>
              <input name="name" defaultValue={subject.name} required
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Icon (emoji)</label>
              <input name="icon" defaultValue={subject.icon} required
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Accent color (hex)</label>
              <input name="color" defaultValue={subject.color} required
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Visible to students</label>
              <select name="is_active" defaultValue={subject.is_active ? 'true' : 'false'}
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                <option value="true">Yes — active</option>
                <option value="false">No — hidden</option>
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="block text-xs font-medium text-gray-500 mb-1">Description</label>
              <textarea name="description" defaultValue={subject.description ?? ''} rows={2}
                className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none" />
            </div>
            <div className="sm:col-span-2">
              <button type="submit"
                className="bg-indigo-500 hover:bg-indigo-600 text-white px-5 py-2.5 rounded-xl text-sm font-semibold transition-colors">
                Save changes
              </button>
            </div>
          </form>
        </section>

        {/* Topics */}
        <section className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-900 mb-5" style={{ fontFamily: 'Sora, sans-serif' }}>
            Topics ({topics?.length ?? 0})
          </h2>

          {/* Topics list */}
          {topics && topics.length > 0 && (
            <div className="space-y-2 mb-6">
              {topics.map((topic: any, i: number) => (
                <div key={topic.id} className="flex items-center gap-3 bg-gray-50 rounded-xl px-4 py-3 border border-gray-100">
                  <span className="text-sm text-gray-400 w-5 shrink-0 font-mono">{i + 1}</span>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-gray-900 text-sm">{topic.title}</p>
                    <p className="text-xs text-gray-400">{(topic.lessons ?? []).length} lesson{(topic.lessons ?? []).length !== 1 ? 's' : ''}</p>
                  </div>
                  <Link
                    href={`/admin/${subject.slug}/${topic.slug}`}
                    className="text-xs bg-indigo-50 text-indigo-600 hover:bg-indigo-100 px-3 py-1.5 rounded-lg transition-colors font-medium"
                  >
                    Manage →
                  </Link>
                  <form action={async () => {
                    'use server'
                    await deleteTopic(topic.id, subject.slug)
                  }}>
                    <button type="submit"
                      className="text-xs bg-red-50 text-red-500 hover:bg-red-100 px-3 py-1.5 rounded-lg transition-colors font-medium"
                      onClick={() => { /* confirmation via browser */ }}>
                      Delete
                    </button>
                  </form>
                </div>
              ))}
            </div>
          )}

          {/* Add topic form */}
          <div className="border-t border-gray-100 pt-5">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">Add Topic</h3>
            <form action={async (formData: FormData) => {
              'use server'
              formData.append('subject_slug', subject.slug)
              await addTopic(subject.id, formData)
            }} className="flex flex-col sm:flex-row gap-3">
              <input name="title" required placeholder="Topic title (e.g. Algebra)"
                className="flex-1 border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input name="description" placeholder="Short description (optional)"
                className="flex-1 border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <button type="submit"
                className="bg-emerald-500 hover:bg-emerald-600 text-white px-5 py-2.5 rounded-xl text-sm font-semibold transition-colors shrink-0">
                + Add
              </button>
            </form>
          </div>
        </section>
      </div>
    </div>
  )
}
