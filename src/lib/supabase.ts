import { createBrowserClient, createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import type { Database, VideoProvider } from './types'

// ── Browser client (use in 'use client' components) ──────────────────────────
export const createClient = () =>
  createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )

// ── Server client (use in Server Components + Server Actions) ─────────────────
export const createServerSupabaseClient = async () => {
  const cookieStore = await cookies()
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {}
        },
      },
    }
  )
}

// ── Video embed URL helper ────────────────────────────────────────────────────
export function getVideoEmbedUrl(provider: VideoProvider, videoId: string): string {
  switch (provider) {
    case 'google_drive':
      return `https://drive.google.com/file/d/${videoId}/preview`
    case 'youtube':
      return `https://www.youtube.com/embed/${videoId}?rel=0&modestbranding=1`
    case 'vimeo':
      return `https://player.vimeo.com/video/${videoId}?dnt=1`
    case 'cloudflare_stream':
      return `https://iframe.cloudflarestream.com/${videoId}`
    case 'bunny':
      return `https://iframe.mediadelivery.net/embed/${videoId}`
    default:
      return `https://drive.google.com/file/d/${videoId}/preview`
  }
}

// ── Slugify helper ────────────────────────────────────────────────────────────
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '')
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

// ── Format duration ───────────────────────────────────────────────────────────
export function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${s.toString().padStart(2, '0')}`
}
