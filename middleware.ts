import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })
  const { pathname } = request.nextUrl

  // Skip static files
  if (
    pathname.startsWith('/_next') ||
    pathname.startsWith('/learn/_next') ||
    pathname === '/favicon.ico'
  ) {
    return response
  }

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()

  // Determine protection level
  // pathname includes basePath (/learn), so paths look like /learn/admin, /learn/math/algebra/lesson-1
  const isAdminPath = pathname.startsWith('/learn/admin')

  // Lesson pages: /learn/[subject]/[topic]/[lesson] = 4 segments starting with 'learn'
  // e.g. /learn/math/algebra/intro-to-algebra → ['learn','math','algebra','intro-to-algebra'] = 4 parts
  const parts = pathname.split('/').filter(Boolean)
  const isLessonPage =
    parts.length >= 4 &&
    parts[0] === 'learn' &&
    parts[1] !== 'admin' &&
    parts[1] !== 'login' &&
    parts[1] !== 'logout'

  if ((isAdminPath || isLessonPage) && !user) {
    const loginUrl = new URL('/learn/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Admin-only check
  if (isAdminPath && user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return NextResponse.redirect(new URL('/learn', request.url))
    }
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon\\.ico).*)'],
}
