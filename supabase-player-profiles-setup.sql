-- Public BSA player profiles with owner-managed profile fields and public statistics.
-- Run this once in the Supabase SQL Editor for the BSA project.

create table if not exists public.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  team text not null default '',
  league text not null default 'BLC',
  role text not null default 'Player' check (role in ('Captain','Player','Coach','Statistician','Commentator','League Official')),
  joined_season text not null default 'Season 1',
  state text not null default '',
  status text not null default 'Active' check (status in ('Active','Inactive')),
  favorite_team text not null default '',
  favorite_player text not null default '',
  favorite_anthem text not null default '',
  kills integer not null default 0 check (kills >= 0),
  beds_broken integer not null default 0 check (beds_broken >= 0),
  void_eliminations integer not null default 0 check (void_eliminations >= 0),
  clutches integer not null default 0 check (clutches >= 0),
  championships integer not null default 0 check (championships >= 0),
  mvp_awards integer not null default 0 check (mvp_awards >= 0),
  achievements text[] not null default '{}',
  team_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_profiles enable row level security;

-- Everyone can view published profiles. Logged-in owners may create and edit their own.
drop policy if exists "Anyone can view player profiles" on public.player_profiles;
drop policy if exists "Players create their own profile" on public.player_profiles;
drop policy if exists "Players update their own profile" on public.player_profiles;
create policy "Anyone can view player profiles"
on public.player_profiles for select to anon, authenticated
using (true);
create policy "Players create their own profile"
on public.player_profiles for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Players update their own profile"
on public.player_profiles for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select on public.player_profiles to anon, authenticated;
revoke insert, update, delete on public.player_profiles from anon, authenticated;
-- Players can edit identity, team/role, location, status and fan preferences.
-- Stats, achievements and team history are deliberately not writable from the public website.
grant insert (user_id, display_name, team, league, role, joined_season, state, status, favorite_team, favorite_player, favorite_anthem)
on public.player_profiles to authenticated;
grant update (display_name, team, league, role, joined_season, state, status, favorite_team, favorite_player, favorite_anthem, updated_at)
on public.player_profiles to authenticated;

create or replace function public.touch_player_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists player_profiles_updated_at on public.player_profiles;
create trigger player_profiles_updated_at
before update on public.player_profiles
for each row execute function public.touch_player_profile_updated_at();

notify pgrst, 'reload schema';
