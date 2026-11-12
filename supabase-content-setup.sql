-- BSA content-management tables for standings and news.
-- Run in the Supabase SQL Editor for the project used by the BSA website.
-- Admin writes are restricted to users listed in public.admin_users via is_bsa_admin().

create table if not exists public.news_posts (
  id bigint generated always as identity primary key,
  title text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.standings (
  id bigint generated always as identity primary key,
  team_name text not null unique,
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  updated_at timestamptz not null default now()
);

-- Seed the current BSA teams once. Existing records and scores are left untouched.
insert into public.standings (team_name) values
  ('CCE'),
  ('Kings of Mid'),
  ('Phoenix Core'),
  ('Iron Division'),
  ('Crimson Rush'),
  ('Stormbreak'),
  ('Void Hunters'),
  ('Skyfall')
on conflict (team_name) do nothing;

alter table public.news_posts enable row level security;
alter table public.standings enable row level security;

grant select on public.news_posts, public.standings to anon, authenticated;
grant insert, update, delete on public.news_posts, public.standings to authenticated;
grant usage, select on sequence public.news_posts_id_seq, public.standings_id_seq to authenticated;

drop policy if exists "Public can read news posts" on public.news_posts;
drop policy if exists "BSA admins manage news posts" on public.news_posts;
drop policy if exists "Public can read standings" on public.standings;
drop policy if exists "BSA admins manage standings" on public.standings;

create policy "Public can read news posts"
on public.news_posts for select to anon, authenticated
using (true);

create policy "BSA admins manage news posts"
on public.news_posts for all to authenticated
using ((select public.is_bsa_admin()))
with check ((select public.is_bsa_admin()));

create policy "Public can read standings"
on public.standings for select to anon, authenticated
using (true);

create policy "BSA admins manage standings"
on public.standings for all to authenticated
using ((select public.is_bsa_admin()))
with check ((select public.is_bsa_admin()));

notify pgrst, 'reload schema';
