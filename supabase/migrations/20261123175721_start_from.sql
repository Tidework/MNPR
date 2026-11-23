-- Players already playing in real life can say, once, which number they're on.
-- Skipped numbers earn no XP (XP only comes from sightings). The leaderboard counts them
-- as reached and shows where the player started.

alter table public.profiles
  add column started_at integer not null default 1 check (started_at between 1 and 9999),
  add column start_set boolean not null default false;

create or replace function public.set_start(p_n integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if p_n is null or p_n < 1 or p_n > 9999 then raise exception 'Enter a number from 1 to 9999.'; end if;
  update public.profiles set n = p_n, started_at = p_n, start_set = true
  where id = uid and not start_set;
  if not found then raise exception 'Your starting number is already set.'; end if;
  return p_n;
end;
$$;
revoke execute on function public.set_start(integer) from public, anon, authenticated;
grant execute on function public.set_start(integer) to authenticated;

-- Leaderboard: highest number reached counts the numbers a player started past.
drop function public.leaderboard();
create function public.leaderboard()
returns table (username text, car text, paint text, best integer, xp integer, started_at integer)
language sql stable security definer set search_path = '' as $$
  select p.username, p.car, p.paint,
         greatest(coalesce(max(s.n) filter (where s.kind = 'run'), 0), p.started_at - 1),
         public.xp_of(p.id), p.started_at
  from public.profiles p left join public.sightings s on s.user_id = p.id
  group by p.id
  having count(s.*) filter (where s.kind = 'run') > 0 or p.started_at > 1
  order by 4 desc, 5 desc
  limit 100;
$$;
revoke execute on function public.leaderboard() from public;
grant execute on function public.leaderboard() to anon, authenticated;
