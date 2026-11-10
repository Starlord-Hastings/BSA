-- BSA admin setup
-- First create the admin account in Supabase Dashboard > Authentication > Users.
-- Then replace YOUR_ADMIN_EMAIL below with that account's exact email address and run this whole script.
-- This is safe to rerun. Do not put an account password or service-role key in this file.

create table if not exists public.team_requests (
  id bigint generated always as identity primary key,
  team_name text not null,
  captain_name text not null,
  league text not null,
  players text,
  created_at timestamptz not null default now()
);

create table if not exists public.league_requests (
  id bigint generated always as identity primary key,
  league_name text not null,
  game text not null,
  organizer text not null,
  contact_email text not null,
  details text,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Add the Auth user as an admin by email (not by a guessed/hard-coded user ID).
insert into public.admin_users (user_id)
select id from auth.users where lower(email) = lower('starlord_@tutamail.com')
on conflict (user_id) do nothing;

-- If the previous statement inserted no row, verify the email exactly matches an existing Auth user.
-- You can check the admin mapping with:
-- select u.email from public.admin_users a join auth.users u on u.id = a.user_id;

alter table public.team_requests enable row level security;
alter table public.league_requests enable row level security;
alter table public.admin_users enable row level security;

-- Admin membership is never directly readable or writable from the public website.
revoke all on table public.admin_users from anon, authenticated;

-- The public website may submit requests; only an approved signed-in admin may read them.
grant insert on table public.team_requests, public.league_requests to anon, authenticated;
grant select on table public.team_requests, public.league_requests to authenticated;

-- SECURITY DEFINER lets this narrowly-scoped membership check inspect the admin list
-- without exposing the list or causing an RLS recursion problem.
create or replace function public.is_bsa_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_bsa_admin() from public, anon;
grant execute on function public.is_bsa_admin() to authenticated;

-- Remove known earlier policy names so this script can be safely rerun.
drop policy if exists "Anyone can submit a team request" on public.team_requests;
drop policy if exists "Anyone can submit a league request" on public.league_requests;
drop policy if exists "admin can read all team requests" on public.team_requests;
drop policy if exists "admin can read all league requests" on public.league_requests;
drop policy if exists "admin can delete team requests" on public.team_requests;
drop policy if exists "admin can delete league requests" on public.league_requests;
drop policy if exists "BSA public team submissions" on public.team_requests;
drop policy if exists "BSA public league submissions" on public.league_requests;
drop policy if exists "BSA admins read team requests" on public.team_requests;
drop policy if exists "BSA admins read league requests" on public.league_requests;

create policy "BSA public team submissions"
on public.team_requests for insert to anon, authenticated
with check (true);

create policy "BSA public league submissions"
on public.league_requests for insert to anon, authenticated
with check (true);

create policy "BSA admins read team requests"
on public.team_requests for select to authenticated
using ((select public.is_bsa_admin()));

create policy "BSA admins read league requests"
on public.league_requests for select to authenticated
using ((select public.is_bsa_admin()));
