-- AnimeNova production schema v2
create extension if not exists pgcrypto;

alter table public.anime add column if not exists rating numeric(3,1);
alter table public.anime add column if not exists featured boolean not null default false;
alter table public.anime add column if not exists published boolean not null default true;
alter table public.episodes add column if not exists published boolean not null default true;
alter table public.watch_history add column if not exists completed boolean not null default false;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text,
 role text not null default 'user' check(role in('user','admin')),
 created_at timestamptz not null default now()
);

create schema if not exists private;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path=public,private as $$
begin
 insert into public.profiles(id,username,role)
 values(new.id,coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),
 case when not exists(select 1 from public.profiles) then 'admin' else 'user' end)
 on conflict(id) do nothing;
 return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure private.handle_new_user();

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path=public,private as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin')
$$;

alter table public.anime enable row level security;
alter table public.seasons enable row level security;
alter table public.episodes enable row level security;
alter table public.favorites enable row level security;
alter table public.watch_history enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "public read published anime" on public.anime;
drop policy if exists "admin manage anime" on public.anime;
drop policy if exists "public read seasons" on public.seasons;
drop policy if exists "admin manage seasons" on public.seasons;
drop policy if exists "public read published episodes" on public.episodes;
drop policy if exists "admin manage episodes" on public.episodes;
drop policy if exists "own favorites" on public.favorites;
drop policy if exists "own watch history" on public.watch_history;
drop policy if exists "own profile read" on public.profiles;

create policy "public read published anime" on public.anime for select to anon,authenticated using(published=true or private.is_admin());
create policy "admin manage anime" on public.anime for all to authenticated using(private.is_admin()) with check(private.is_admin());

create policy "public read seasons" on public.seasons for select to anon,authenticated using(true);
create policy "admin manage seasons" on public.seasons for all to authenticated using(private.is_admin()) with check(private.is_admin());

create policy "public read published episodes" on public.episodes for select to anon,authenticated using(published=true or private.is_admin());
create policy "admin manage episodes" on public.episodes for all to authenticated using(private.is_admin()) with check(private.is_admin());

create policy "own favorites" on public.favorites for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "own watch history" on public.watch_history for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "own profile read" on public.profiles for select to authenticated using(auth.uid()=id or private.is_admin());

grant select on public.anime,public.seasons,public.episodes to anon,authenticated;
grant select,insert,update,delete on public.anime,public.seasons,public.episodes to authenticated;
grant select,insert,update,delete on public.favorites,public.watch_history to authenticated;
grant select on public.profiles to authenticated;

revoke all on function private.handle_new_user() from public,anon,authenticated;
revoke all on function private.is_admin() from public,anon;
grant execute on function private.is_admin() to authenticated;
