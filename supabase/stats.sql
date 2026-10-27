-- Guesstimate player numbers
-- Paste one query at a time into Supabase: SQL Editor > New query > Run.
-- These count everyone who posted a daily score: every account, and every guest who
-- entered a name once (guests post automatically after that). Practice runs aren't counted.

-- 1. Players per day, split into new and returning (last 30 days)
select day,
       count(*)                                        as players,
       count(*) filter (where first_day = day)         as new_players,
       count(*) filter (where first_day < day)         as returning_players,
       count(*) filter (where is_account)              as with_account,
       round(avg(total))                               as average_score
from (
  select day, total, is_account, min(day) over (partition by player_id) as first_day
  from public.daily_scores
) s
group by day
order by day desc
limit 30;

-- 2. Do new players come back? For each day's new players: how many played again
--    the next day, and how many played again at any point in the following 7 days.
--    The most recent week's numbers keep growing until those 7 days have passed.
with firsts as (
  select player_id, min(day) as first_day from public.daily_scores group by player_id
)
select f.first_day,
       count(*) as new_players,
       round(100.0 * count(*) filter (where exists (
         select 1 from public.daily_scores d where d.player_id = f.player_id and d.day = f.first_day + 1
       )) / count(*)) as back_next_day_pct,
       round(100.0 * count(*) filter (where exists (
         select 1 from public.daily_scores d where d.player_id = f.player_id and d.day between f.first_day + 1 and f.first_day + 7
       )) / count(*)) as back_within_week_pct
from firsts f
group by f.first_day
order by f.first_day desc
limit 30;

-- 3. Accounts so far, and how many signed up in the last 7 days
select count(*) as accounts,
       count(*) filter (where created_at > now() - interval '7 days') as new_this_week
from public.profiles;
