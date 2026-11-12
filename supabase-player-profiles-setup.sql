-- Public BSA player profiles with owner-managed profile fields and public statistics.
-- Safe to run again after future schema changes; existing profiles are preserved.

create table if not exists public.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  team text not null default '',
  league text not null default 'BLC',
  favorite_league text not null default '',
  good_at text not null default '',
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

-- Migrate installations that already have the first version of profiles.
alter table public.player_profiles add column if not exists favorite_league text not null default '';
alter table public.player_profiles add column if not exists good_at text not null default '';

alter table public.player_profiles enable row level security;

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
-- Public users may view profiles; signed-in owners can edit only profile details.
-- Official stats, achievements, and history remain staff-managed and are not granted here.
grant insert (user_id, display_name, team, league, favorite_league, good_at, role, joined_season, state, status, favorite_team, favorite_player, favorite_anthem)
on public.player_profiles to authenticated;
grant update (display_name, team, league, favorite_league, good_at, role, joined_season, state, status, favorite_team, favorite_player, favorite_anthem, updated_at)
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
