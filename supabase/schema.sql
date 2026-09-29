-- ENIGMA Supabase database setup
-- Run this entire file in Supabase Dashboard -> SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.discussions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'Student',
  title text not null check (char_length(title) between 3 and 120),
  topic text not null check (char_length(topic) between 1 and 60),
  message text not null check (char_length(message) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id text not null,
  event_name text not null,
  created_at timestamptz not null default now(),
  unique(user_id, event_id)
);

create table if not exists public.join_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  year text not null,
  interest text not null,
  reason text not null default '',
  status text not null default 'Pending' check (status in ('Pending','Approved','Rejected')),
  created_at timestamptz not null default now(),
  unique(user_id)
);

create table if not exists public.resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  url text not null,
  description text default '',
  created_at timestamptz not null default now()
);

create index if not exists discussions_created_at_idx on public.discussions(created_at desc);
create index if not exists registrations_user_id_idx on public.event_registrations(user_id);
create index if not exists applications_user_id_idx on public.join_applications(user_id);

-- Automatically create/update a profile when a Supabase Auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Keep profile email/name synchronized when Auth metadata changes.
create or replace function public.handle_user_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
  set full_name = coalesce(new.raw_user_meta_data ->> 'full_name', full_name),
      email = coalesce(new.email, email)
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row execute procedure public.handle_user_update();

-- RLS: every exposed table is protected.
alter table public.profiles enable row level security;
alter table public.discussions enable row level security;
alter table public.event_registrations enable row level security;
alter table public.join_applications enable row level security;
alter table public.resources enable row level security;

-- Profiles: a student can read/update only their own profile.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated using ((select auth.uid()) = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);

-- Discussions: everyone can read; signed-in users can create; authors can delete their own.
drop policy if exists "discussions_read" on public.discussions;
create policy "discussions_read" on public.discussions for select to anon, authenticated using (true);
drop policy if exists "discussions_insert_own" on public.discussions;
create policy "discussions_insert_own" on public.discussions for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "discussions_delete_own" on public.discussions;
create policy "discussions_delete_own" on public.discussions for delete to authenticated using ((select auth.uid()) = user_id);

-- Event registrations: students can see/create their own registrations.
drop policy if exists "registrations_select_own" on public.event_registrations;
create policy "registrations_select_own" on public.event_registrations for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "registrations_insert_own" on public.event_registrations;
create policy "registrations_insert_own" on public.event_registrations for insert to authenticated with check ((select auth.uid()) = user_id);

-- Join applications: students can see/create their own application.
drop policy if exists "applications_select_own" on public.join_applications;
create policy "applications_select_own" on public.join_applications for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "applications_insert_own" on public.join_applications;
create policy "applications_insert_own" on public.join_applications for insert to authenticated with check ((select auth.uid()) = user_id);

-- Resources: public read access, but no client-side writes.
drop policy if exists "resources_read" on public.resources;
create policy "resources_read" on public.resources for select to anon, authenticated using (true);

-- Sample resources. Safe to run more than once because duplicates are avoided by title/url checks.
insert into public.resources (title, category, url, description)
select * from (values
  ('MDN Web Docs', 'Web', 'https://developer.mozilla.org/', 'HTML, CSS and JavaScript reference.'),
  ('Python Official Docs', 'Python', 'https://docs.python.org/3/', 'Official Python documentation.'),
  ('GitHub Skills', 'Git', 'https://skills.github.com/', 'Interactive GitHub learning resources.')
) as v(title, category, url, description)
where not exists (select 1 from public.resources r where r.url = v.url);
