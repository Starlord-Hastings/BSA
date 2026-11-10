-- BSA admin setup
-- Create your admin user first in Supabase Dashboard > Authentication > Users.
-- Replace the email below with that exact account email, then run this whole script.
-- Safe to rerun. Do not put an account password or service-role key here.

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

-- Add optional registration fields to tables created by an earlier version.
alter table public.team_requests add column if not exists statistician text;
alter table public.team_requests add column if not exists availability text;
alter table public.team_requests add column if not exists home_state text;
alter table public.team_requests add column if not exists team_colors text;
alter table public.team_requests add column if not exists team_anthem text;
alter table public.team_requests add column if not exists fan_interactive text;
alter table public.team_requests add column if not exists notes text;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- This project admin email is the one configured for BSA. Change only if needed.
insert into public.admin_users (user_id)
select id from auth.users where lower(email) = lower('starlord_@tutamail.com')
on conflict (user_id) do nothing;

alter table public.team_requests enable row level security;
alter table public.league_requests enable row level security;
alter table public.admin_users enable row level security;

revoke all on table public.admin_users from anon, authenticated;
grant insert on table public.team_requests, public.league_requests to anon, authenticated;
grant select on table public.team_requests, public.league_requests to authenticated;

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
