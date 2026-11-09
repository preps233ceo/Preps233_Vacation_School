'use client'

import Link from 'next/link'
import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'

interface AuthNavProps {
  user: { email: string } | null
}

export default function AuthNav({ user }: AuthNavProps) {
  const router = useRouter()
  const supabase = createClient()

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/')
    router.refresh()
  }

  if (!user) {
    return (
      <Link
        href="/login"
        className="bg-indigo-500 hover:bg-indigo-400 text-white text-sm px-4 py-2 rounded-lg transition-colors font-medium"
      >
        Sign in
      </Link>
    )
  }

  return (
    <div className="flex items-center gap-3">
      <span className="text-white/50 text-sm hidden sm:block">{user.email}</span>
      <button
        onClick={handleSignOut}
        className="bg-white/10 hover:bg-white/20 text-white text-sm px-4 py-2 rounded-lg transition-colors"
      >
        Sign out
      </button>
    </div>
  )
}
