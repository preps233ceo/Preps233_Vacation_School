-- Preps233 Learn – Database Schema
-- Run this in your Supabase SQL editor (Dashboard > SQL Editor > New query)

-- ─────────────────────────────────────────────────────────────
-- TABLES
-- ─────────────────────────────────────────────────────────────

create table if not exists subjects (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  slug text unique not null,
  description text,
  icon text not null default '📚',
  color text not null default '#6366f1',
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists topics (
  id uuid default gen_random_uuid() primary key,
  subject_id uuid not null references subjects(id) on delete cascade,
  title text not null,
  slug text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint topics_subject_slug_unique unique (subject_id, slug)
);

create table if not exists lessons (
  id uuid default gen_random_uuid() primary key,
  topic_id uuid not null references topics(id) on delete cascade,
  title text not null,
  description text,
  video_provider text not null default 'google_drive'
    check (video_provider in ('google_drive', 'youtube', 'vimeo', 'cloudflare_stream', 'bunny')),
  video_id text not null,
  duration_seconds integer not null default 300,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists questions (
  id uuid default gen_random_uuid() primary key,
  lesson_id uuid not null references lessons(id) on delete cascade,
  question text not null,
  options jsonb not null,  -- text array e.g. ["A) ...", "B) ...", "C) ...", "D) ..."]
  correct_answer integer not null,  -- 0-indexed (0=A, 1=B, 2=C, 3=D)
  explanation text,
  source text,  -- e.g. "WASSCE 2019 Q3"
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists lesson_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references lessons(id) on delete cascade,
  watch_seconds integer not null default 0,
  video_completed boolean not null default false,
  quiz_score integer,
  quiz_passed boolean not null default false,
  quiz_attempts integer not null default 0,
  passed_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint lesson_progress_user_lesson_unique unique (user_id, lesson_id)
);

-- ─────────────────────────────────────────────────────────────
-- ROW-LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────

alter table subjects enable row level security;
alter table topics enable row level security;
alter table lessons enable row level security;
alter table questions enable row level security;
alter table profiles enable row level security;
alter table lesson_progress enable row level security;

-- Helper function: is the current user an admin?
create or replace function is_admin()
returns boolean
language sql security definer
as $$
  select coalesce(
    (select is_admin from profiles where id = auth.uid()),
    false
  )
$$;

-- Subjects
create policy "Public can view active subjects" on subjects
  for select using (is_active = true);
create policy "Admins manage subjects" on subjects
  for all using (is_admin());

-- Topics
create policy "Public can view active topics" on topics
  for select using (is_active = true);
create policy "Admins manage topics" on topics
  for all using (is_admin());

-- Lessons
create policy "Authenticated users view active lessons" on lessons
  for select to authenticated using (is_active = true);
create policy "Admins manage lessons" on lessons
  for all using (is_admin());

-- Questions (correct_answer hidden in app logic, not at DB level)
create policy "Authenticated users view questions" on questions
  for select to authenticated using (true);
create policy "Admins manage questions" on questions
  for all using (is_admin());

-- Profiles
create policy "Authenticated users view profiles" on profiles
  for select to authenticated using (true);
create policy "Users manage own profile" on profiles
  for insert to authenticated with check (id = auth.uid());
create policy "Users update own profile" on profiles
  for update to authenticated using (id = auth.uid());

-- Lesson progress
create policy "Users view own progress" on lesson_progress
  for select to authenticated using (user_id = auth.uid());
create policy "Users insert own progress" on lesson_progress
  for insert to authenticated with check (user_id = auth.uid());
create policy "Users update own progress" on lesson_progress
  for update to authenticated using (user_id = auth.uid());
create policy "Admins view all progress" on lesson_progress
  for select using (is_admin());

-- ─────────────────────────────────────────────────────────────
-- TRIGGER: auto-create profile on signup
-- ─────────────────────────────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- SEED: 5 subjects (only Elective Maths active initially)
-- ─────────────────────────────────────────────────────────────

insert into subjects (name, slug, description, icon, color, sort_order, is_active)
values
  ('Elective Mathematics', 'math',
   'Advanced mathematics covering calculus, statistics, vectors and mechanics for WASSCE',
   '📐', '#6366f1', 1, true),
  ('Physics', 'physics',
   'Classical mechanics, electromagnetism, waves, optics, and modern physics',
   '⚡', '#3b82f6', 2, false),
  ('Chemistry', 'chemistry',
   'Organic, inorganic and physical chemistry with stoichiometry and lab techniques',
   '🧪', '#f59e0b', 3, false),
  ('Biology', 'biology',
   'Cell biology, genetics, ecology, evolution and human physiology',
   '🧬', '#10b981', 4, false),
  ('Electrical Engineering', 'electrical-engineering',
   'Circuit analysis, digital electronics, power systems and instrumentation',
   '🔌', '#f97316', 5, false)
on conflict (slug) do nothing;

-- ─────────────────────────────────────────────────────────────
-- AFTER SETUP: Grant yourself admin
-- Run this after you sign up (replace with your actual email):
-- ─────────────────────────────────────────────────────────────
-- update profiles
-- set is_admin = true
-- where id = (select id from auth.users where email = 'your@email.com');
