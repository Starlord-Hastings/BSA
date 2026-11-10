-- BSA admin setup
-- This script creates/updates request tables and grants the configured BSA admin access.
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

-- Add fields to existing tables created by earlier setup versions.
alter table public.team_requests add column if not exists statistician text;
alter table public.team_requests add column if not exists availability text;
alter table public.team_requests add column if not exists home_state text;
alter table public.team_requests add column if not exists team_colors text;
alter table public.team_requests add column if not exists team_anthem text;
alter table public.team_requests add column if not exists fan_interactive text;
alter table public.team_requests add column if not exists notes text;

-- The league_requests table may predate the current website form. Add its expected fields.
alter table public.league_requests add column if not exists league_name text;
alter table public.league_requests add column if not exists game text;
alter table public.league_requests add column if not exists organizer text;
alter table public.league_requests add column if not exists contact_email text;
alter table public.league_requests add column if not exists details text;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- The one admin email. Change this only if your Supabase Auth login uses a different email.
insert into public.admin_users (user_id)
select id from auth.users where lower(email) = lower('starlord_@tutamail.com')
on conflict (user_id) do nothing;

alter table public.team_requests enable row level security;
alter table public.league_requests enable row level security;
alter table public.admin_users enable row level security;

revoke all on table public.admin_users from anon, authenticated;
grant insert on table public.team_requests, public.league_requests to anon, authenticated;
grant select, update, delete on table public.team_requests, public.league_requests to authenticated;

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
drop policy if exists "BSA admins update team requests" on public.team_requests;
drop policy if exists "BSA admins update league requests" on public.league_requests;
drop policy if exists "BSA admins delete team requests" on public.team_requests;
drop policy if exists "BSA admins delete league requests" on public.league_requests;

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

create policy "BSA admins update team requests"
on public.team_requests for update to authenticated
using ((select public.is_bsa_admin()))
with check ((select public.is_bsa_admin()));

create policy "BSA admins update league requests"
on public.league_requests for update to authenticated
using ((select public.is_bsa_admin()))
with check ((select public.is_bsa_admin()));

create policy "BSA admins delete team requests"
on public.team_requests for delete to authenticated
using ((select public.is_bsa_admin()));

create policy "BSA admins delete league requests"
on public.league_requests for delete to authenticated
using ((select public.is_bsa_admin()));

-- Ask PostgREST to refresh its API schema cache after these migrations.
notify pgrst, 'reload schema';
