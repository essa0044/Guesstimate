-- Guesstimate database setup: daily leaderboard + player accounts
-- Run this in your Supabase project: SQL Editor > New query > paste everything > Run.
-- It is safe to run again, and it upgrades a project that already ran the older leaderboard.sql.
--
-- How it works
-- * A "day" is the player's own local date (2026-10-27 for everyone playing No. 13), so each
--   day's board stays open until midnight in the last time zone on Earth.
-- * Guests post under a random id kept in their browser and pick a name each time they post.
-- * Accounts (Supabase Auth) get a profile with a reserved name. Their scores are saved under
--   the account, so their streak and today's result follow them to every device.
-- * Browsers never touch the tables directly. They call the functions below, which check
--   every score. Player ids and emails are never sent back out.

-- ---------- tables ----------

create table if not exists public.daily_scores (
  day        date        not null,
  player_id  uuid        not null,
  name       text        not null,
  rounds     smallint[]  not null,
  total      smallint    not null,
  created_at timestamptz not null default now(),
  primary key (day, player_id),
  constraint name_ok   check (char_length(name) between 2 and 16 and name !~ '[[:cntrl:]]' and btrim(name) = name),
  constraint rounds_ok check (array_length(rounds, 1) = 5),
  constraint total_ok  check (total between 0 and 500)
);
alter table public.daily_scores add column if not exists detail jsonb;
alter table public.daily_scores add column if not exists is_account boolean not null default false;
create index if not exists daily_scores_by_day on public.daily_scores (day, total desc);
create index if not exists daily_scores_by_player on public.daily_scores (player_id, day);

create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text,
  created_at timestamptz not null default now(),
  constraint username_ok check (username is null or (char_length(username) between 2 and 16
                                and username !~ '[[:cntrl:]]' and btrim(username) = username))
);
create unique index if not exists profiles_username_lower on public.profiles (lower(username));

-- Lock both tables: with row level security on and no policies, the public key can't read or
-- change rows directly. Only the functions below can.
alter table public.daily_scores enable row level security;
alter table public.profiles enable row level security;
revoke all on table public.daily_scores from anon, authenticated;
revoke all on table public.profiles from anon, authenticated;

-- ---------- new accounts get a profile ----------

-- Uses the name chosen at sign-up when it's free. Otherwise the player picks one after signing in.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', ''), '\s+', ' ', 'g'));
begin
  begin
    if char_length(v_name) between 2 and 16 and v_name !~ '[[:cntrl:]]'
       and not exists (select 1 from public.profiles where lower(username) = lower(v_name)) then
      insert into public.profiles (id, username) values (new.id, v_name) on conflict (id) do nothing;
    else
      insert into public.profiles (id, username) values (new.id, null) on conflict (id) do nothing;
    end if;
  exception when unique_violation then
    insert into public.profiles (id, username) values (new.id, null) on conflict (id) do nothing;
  end;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Accounts created before this file ran get an empty profile too.
insert into public.profiles (id) select id from auth.users on conflict (id) do nothing;

-- ---------- leaderboard ----------

-- The board for one day: player count, the top scores, and the asking player's own rank.
-- Ties share a rank (two players on 400 are both #3).
create or replace function public.day_board(p_day date, p_player uuid default null, p_limit int default 10)
returns json
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with ranked as (
    select name, total, player_id, created_at, is_account,
           rank() over (order by total desc) as rank
    from daily_scores
    where day = p_day
  ), shown as (
    select * from ranked order by rank, created_at limit least(greatest(coalesce(p_limit, 10), 1), 50)
  )
  select json_build_object(
    'day',     p_day,
    'players', (select count(*) from ranked),
    'top',     coalesce((select json_agg(json_build_object(
                           'rank', rank, 'name', name, 'total', total, 'account', is_account,
                           'me', coalesce(player_id = coalesce(auth.uid(), p_player), false))
                         order by rank, created_at) from shown), '[]'::json),
    'me',      (select json_build_object('rank', rank, 'name', name, 'total', total)
                from ranked where player_id = coalesce(auth.uid(), p_player))
  );
$$;

-- Save a score, then return the board. A signed-in player posts under their account name;
-- a guest posts under the name they typed. The first score of the day counts.
drop function if exists public.submit_score(date, uuid, text, int[]);
create or replace function public.submit_score(p_day date, p_player uuid, p_name text, p_rounds int[], p_detail jsonb default null)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    uuid  := auth.uid();
  v_player uuid  := coalesce(auth.uid(), p_player);
  v_name   text;
  v_detail jsonb := p_detail;
begin
  -- Only days that are "today" somewhere on Earth (UTC-12 to UTC+14) are open.
  if p_day is null
     or p_day < (now() at time zone 'Etc/GMT+12')::date
     or p_day > (now() at time zone 'Etc/GMT-14')::date then
    raise exception 'This day''s board is closed. Check the date on your device.' using errcode = 'P0001';
  end if;
  if v_player is null then
    raise exception 'Missing player id.' using errcode = 'P0001';
  end if;

  if v_uid is not null then
    select username into v_name from profiles where id = v_uid;
    if v_name is null then
      raise exception 'Choose a name for your account first.' using errcode = 'P0001';
    end if;
  else
    if exists (select 1 from profiles where id = p_player) then
      raise exception 'Sign in to post with that account.' using errcode = 'P0001';
    end if;
    v_name := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
    if char_length(v_name) not between 2 and 16 or v_name ~ '[[:cntrl:]]' then
      raise exception 'Use a name of 2 to 16 characters.' using errcode = 'P0001';
    end if;
    if exists (select 1 from profiles where lower(username) = lower(v_name)) then
      raise exception 'That name belongs to an account. Pick another, or sign in if it''s yours.' using errcode = 'P0001';
    end if;
  end if;

  if coalesce(array_length(p_rounds, 1), 0) <> 5
     or exists (select 1 from unnest(p_rounds) as r(v) where v is null or v < 0 or v > 100) then
    raise exception 'A score is five rounds of 0 to 100 points.' using errcode = 'P0001';
  end if;
  -- The per-round details only let a player see today's result on another device. Keep them small.
  if v_detail is not null and (jsonb_typeof(v_detail) <> 'array' or octet_length(v_detail::text) > 4000) then
    v_detail := null;
  end if;

  insert into daily_scores (day, player_id, name, rounds, total, detail, is_account)
  values (p_day, v_player, v_name, p_rounds::smallint[], (select sum(v) from unnest(p_rounds) as r(v)),
          v_detail, v_uid is not null)
  on conflict (day, player_id) do nothing;

  return day_board(p_day, v_player);
end;
$$;

-- ---------- accounts ----------

-- Is a name already reserved by an account? Used before sign-up.
create or replace function public.name_taken(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from profiles
                 where lower(username) = lower(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'))));
$$;

-- The signed-in player's name and stats: games played, current streak, best day, and today's result.
create or replace function public.my_profile(p_today date default null)
returns json
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with mine as (
    select day, total, rounds, detail from daily_scores
    where auth.uid() is not null and player_id = auth.uid()
  ), grouped as (
    select day, day - (row_number() over (order by day))::int as grp from mine
  ), runs as (
    select max(day) as last_day, count(*) as len from grouped group by grp
  )
  select case when auth.uid() is null then null else json_build_object(
    'username', (select username from profiles where id = auth.uid()),
    'played',   (select count(*) from mine),
    'best',     (select max(total) from mine),
    'streak',   coalesce((select len from runs where p_today is not null and last_day >= p_today - 1
                          order by last_day desc limit 1), 0),
    'today',    (select json_build_object('total', total, 'rounds', rounds, 'detail', detail)
                 from mine where day = p_today)
  ) end;
$$;

-- Choose or change the account's name. Past scores show the new name too.
create or replace function public.set_username(p_name text)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid  uuid := auth.uid();
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if v_uid is null then
    raise exception 'Sign in first.' using errcode = 'P0001';
  end if;
  if char_length(v_name) not between 2 and 16 or v_name ~ '[[:cntrl:]]' then
    raise exception 'Use a name of 2 to 16 characters.' using errcode = 'P0001';
  end if;
  if exists (select 1 from profiles where lower(username) = lower(v_name) and id <> v_uid) then
    raise exception 'That name is taken. Try another.' using errcode = 'P0001';
  end if;
  insert into profiles (id, username) values (v_uid, v_name)
  on conflict (id) do update set username = excluded.username;
  update daily_scores set name = v_name where player_id = v_uid;
  return json_build_object('username', v_name);
exception when unique_violation then
  raise exception 'That name is taken. Try another.' using errcode = 'P0001';
end;
$$;

-- When a guest signs in, move the scores they posted as a guest on this device into the account,
-- so their streak carries over. Days the account already has keep the account's score.
create or replace function public.claim_guest(p_player uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_name  text;
  v_moved int;
begin
  if v_uid is null or p_player is null or p_player = v_uid then
    return 0;
  end if;
  if exists (select 1 from profiles where id = p_player) then
    return 0; -- never take over another account
  end if;
  select username into v_name from profiles where id = v_uid;
  update daily_scores g
     set player_id = v_uid, is_account = true, name = coalesce(v_name, g.name)
   where g.player_id = p_player
     and not exists (select 1 from daily_scores a where a.player_id = v_uid and a.day = g.day);
  get diagnostics v_moved = row_count;
  delete from daily_scores where player_id = p_player;
  return v_moved;
end;
$$;

-- ---------- who may call what ----------

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.day_board(date, uuid, int) from public;
revoke all on function public.submit_score(date, uuid, text, int[], jsonb) from public;
revoke all on function public.name_taken(text) from public;
revoke all on function public.my_profile(date) from public;
revoke all on function public.set_username(text) from public;
revoke all on function public.claim_guest(uuid) from public;
grant execute on function public.day_board(date, uuid, int) to anon, authenticated;
grant execute on function public.submit_score(date, uuid, text, int[], jsonb) to anon, authenticated;
grant execute on function public.name_taken(text) to anon, authenticated;
grant execute on function public.my_profile(date) to authenticated;
grant execute on function public.set_username(text) to authenticated;
grant execute on function public.claim_guest(uuid) to authenticated;

-- Moderating: to remove a name from a board, open Table Editor > daily_scores and delete the
-- row, or run for example:
--   delete from public.daily_scores where day = '2026-10-27' and name = 'Bad name';
-- To rename an account, edit its row in Table Editor > profiles.
