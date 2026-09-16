-- AnimeNova production schema
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

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,username,role) values(new.id,coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),case when not exists(select 1 from public.profiles) then 'admin' else 'user' end) on conflict(id) do nothing;
 return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;

alter table public.anime enable row level security;
alter table public.seasons enable row level security;
alter table public.episodes enable row level security;
alter table public.favorites enable row level security;
alter table public.watch_history enable row level security;
alter table public.profiles enable row level security;

-- Recreate policies as needed from the SQL applied to Supabase.
