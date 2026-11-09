# Preps233 Learn

Interactive video learning platform for WASSCE preparation.
Deployed at **preps233.com/learn**

## Stack

| Layer | Technology | Cost |
|-------|-----------|------|
| Frontend + Backend | Next.js 14 (App Router) | Free (Vercel) |
| Database + Auth | Supabase | Free tier |
| Video hosting (now) | Google Drive | Free |
| Video hosting (scale) | Bunny.net Stream or Cloudflare Stream | ~$10–20/mo |
| Domain | preps233.com (you own it) | Yours |

## Quick Start

### 1. Set up Supabase

1. Create a free project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** → **New query** → paste contents of `supabase/schema.sql` → Run
3. Copy your project URL and anon key from **Settings → API**

### 2. Configure environment

```bash
cp .env.example .env.local
# Edit .env.local and fill in your Supabase values
```

### 3. Run locally

```bash
npm install
npm run dev
# Open http://localhost:3000/learn
```

### 4. Grant yourself admin access

After signing up for the first time:
1. Go to Supabase Dashboard → **Table Editor** → **profiles**
2. Find your row and set `is_admin = true`
3. Or run in SQL Editor:
   ```sql
   update profiles set is_admin = true
   where id = (select id from auth.users where email = 'your@email.com');
   ```

## Deploy to Vercel + preps233.com/learn

### Option A — Subdirectory at preps233.com/learn (recommended)

1. Push this repo to GitHub
2. Create a new Vercel project → Import your repo
3. Add environment variables in Vercel project settings
4. In your DNS provider, add:
   - Type: `A` record pointing `preps233.com` to Vercel's IP (76.76.21.21)
   - Or a `CNAME` for `www` → `cname.vercel-dns.com`
5. Add `preps233.com` as a custom domain in your Vercel project
6. Because `basePath: '/learn'` is set in `next.config.js`, the app automatically serves at `/learn`

### Option B — Subdomain (simpler)

If you want `learn.preps233.com` instead:
1. Remove `basePath: '/learn'` from `next.config.js`
2. Add a `CNAME` record: `learn` → `cname.vercel-dns.com`
3. Add `learn.preps233.com` as a custom domain in Vercel

## Adding Content

### Upload videos to Google Drive

1. Upload your `.mp4` files to Google Drive
2. Right-click each file → **Share** → **Anyone with the link can view**
3. Copy the File ID from the URL:
   `https://drive.google.com/file/d/`**`1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms`**`/view`
4. Paste the File ID into the admin panel when adding a lesson

### Add quiz questions

1. Go to `preps233.com/learn/admin`
2. Navigate to your subject → topic → lesson
3. Click **Add Question** and fill in the form
4. The correct answer is stored server-side only — never exposed to students

## Video Hosting Migration Path

When Google Drive starts throttling (happens around 50+ students/day on a single video):

**Bunny.net Stream (recommended):**
1. Sign up at bunny.net, create a video library
2. Upload your videos
3. In admin panel, change **Video Provider** to `bunny` and paste the video ID
4. ~$10/month for a school-sized library

**Cloudflare R2 + Stream:**
- R2: $0.015/GB/month storage, **FREE egress** via Cloudflare
- Best value at scale; requires more setup

## Subjects

| Subject | Status | Slug |
|---------|--------|------|
| Elective Mathematics | ✅ Active | `math` |
| Physics | 🔒 Coming soon | `physics` |
| Chemistry | 🔒 Coming soon | `chemistry` |
| Biology | 🔒 Coming soon | `biology` |
| Electrical Engineering | 🔒 Coming soon | `electrical-engineering` |

Enable more subjects in the admin panel under each subject's settings.

## Security

- Correct quiz answers are stored server-side only (Supabase, behind RLS)
- Answers are scored by a Server Action — never sent to the browser
- Video watermarks display the student's email at multiple positions
- Tab-switch detection pauses watch timer and shows warning overlay
- 80% pass mark required to proceed to next lesson
- Topics unlock sequentially (must complete all lessons in topic N before topic N+1)
