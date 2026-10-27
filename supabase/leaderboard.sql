-- Guesstimate daily leaderboard
-- Run this once in your Supabase project: SQL Editor > New query > paste > Run.
-- It is safe to run again; it updates the functions without touching saved scores.
--
-- How it works
-- * A "day" is the player's own local date (2026-10-27 for everyone playing No. 13),
--   so each board stays open until midnight in the last time zone on Earth.
-- * Browsers never touch the table directly. They call two functions:
--     submit_score  saves a player's first score of the day and returns the board
--     day_board     returns the top scores, the player count and the player's own rank
-- * Player ids are random ids stored in each browser. They are never sent back out.

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

create index if not exists daily_scores_by_day on public.daily_scores (day, total desc);

-- Lock the table. With row level security on and no policies, the public key can't read
-- or change rows directly; only the two functions below can.
alter table public.daily_scores enable row level security;
revoke all on table public.daily_scores from anon, authenticated;

-- The board for one day: player count, the top scores, and the asking player's rank.
-- Ties share a rank (two players on 400 are both #3).
create or replace function public.day_board(p_day date, p_player uuid default null, p_limit int default 10)
returns json
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with ranked as (
    select name, total, player_id, created_at,
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
                           'rank', rank, 'name', name, 'total', total,
                           'me', coalesce(player_id = p_player, false))
                         order by rank, created_at) from shown), '[]'::json),
    'me',      (select json_build_object('rank', rank, 'name', name, 'total', total)
                from ranked where player_id = p_player)
  );
$$;

-- Save a score, then return the board. The first score a player posts for a day counts;
-- posting again that day changes nothing.
create or replace function public.submit_score(p_day date, p_player uuid, p_name text, p_rounds int[])
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  -- Only days that are "today" somewhere on Earth (UTC-12 to UTC+14) are open.
  if p_day is null
     or p_day < (now() at time zone 'Etc/GMT+12')::date
     or p_day > (now() at time zone 'Etc/GMT-14')::date then
    raise exception 'This day''s board is closed. Check the date on your device.' using errcode = 'P0001';
  end if;
  if p_player is null then
    raise exception 'Missing player id.' using errcode = 'P0001';
  end if;
  if char_length(v_name) not between 2 and 16 or v_name ~ '[[:cntrl:]]' then
    raise exception 'Use a name of 2 to 16 characters.' using errcode = 'P0001';
  end if;
  if coalesce(array_length(p_rounds, 1), 0) <> 5
     or exists (select 1 from unnest(p_rounds) as r(v) where v is null or v < 0 or v > 100) then
    raise exception 'A score is five rounds of 0 to 100 points.' using errcode = 'P0001';
  end if;

  insert into daily_scores (day, player_id, name, rounds, total)
  values (p_day, p_player, v_name, p_rounds::smallint[], (select sum(v) from unnest(p_rounds) as r(v)))
  on conflict (day, player_id) do nothing;

  return day_board(p_day, p_player);
end;
$$;

revoke all on function public.day_board(date, uuid, int) from public;
revoke all on function public.submit_score(date, uuid, text, int[]) from public;
grant execute on function public.day_board(date, uuid, int) to anon, authenticated;
grant execute on function public.submit_score(date, uuid, text, int[]) to anon, authenticated;

-- Moderating: to remove a name, open Table Editor > daily_scores and delete the row,
-- or run for example:
--   delete from public.daily_scores where day = '2026-10-27' and name = 'Bad name';
