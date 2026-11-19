-- Checks the database rules. Run with supabase/tests/run.sh; any failed check stops with an error.
\set ON_ERROR_STOP on
insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com');
grant all on all tables in schema public to service_role;

create function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  execute 'set role authenticated';
end $$;
create function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;

-- A signs up and logs two unconfirmed plates of their run, one with a pin.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into public.profiles (id, username) values ('00000000-0000-0000-0000-00000000000a', 'alice');
select public.log_sighting('run', null, 50.4712345, -4.7203987, 'A30 near Bodmin');
select public.log_sighting('run');
select pg_temp.check((select n from public.profiles where id = auth.uid()) = 3, 'run moves A on to 3');
select pg_temp.check((select lat from public.sightings where n = 1 and user_id = auth.uid()) = 50.4712, 'pins kept to 4 decimal places');
select pg_temp.check(public.xp_of(auth.uid()) = 4 + 3 + 2 + 4, 'unconfirmed run XP with pin and place');

-- A cannot set their own number, nor write sightings directly.
do $$ begin
  update public.profiles set n = 99 where id = auth.uid();
  raise exception 'FAILED: A changed their own number';
exception when insufficient_privilege then raise notice 'ok: number cannot be edited directly'; end $$;
do $$ begin
  insert into public.sightings (user_id, n, kind) values (auth.uid(), 3, 'run');
  raise exception 'FAILED: A wrote a sighting directly';
exception when insufficient_privilege then raise notice 'ok: sightings only through the functions'; end $$;
do $$ begin
  perform public.log_confirmed(auth.uid(), 'run', 3, 'h1', 'format');
  raise exception 'FAILED: A confirmed their own plate';
exception when insufficient_privilege then raise notice 'ok: only the edge function can confirm'; end $$;
update public.profiles set car = 'camper' where id = auth.uid();
select pg_temp.check((select car from public.profiles where id = auth.uid()) = 'camper', 'A can change their car');

-- B signs up. Before being friends, B sees none of A's data, only the rounded public map.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
insert into public.profiles (id, username) values ('00000000-0000-0000-0000-00000000000b', 'bob');
select pg_temp.check((select count(*) from public.sightings) = 0, 'B cannot see A''s sightings');
select pg_temp.check((select count(*) from public.profiles) = 1, 'B sees only their own profile');
select pg_temp.check((select lat from public.heat() limit 1) = 50.47, 'public map is rounded to about 1 km');
select pg_temp.check((select count(*) from public.my_friends()) = 0, 'B has no friends yet');
do $$ begin
  insert into public.profiles (id, username) values ('00000000-0000-0000-0000-00000000000c', 'mallory');
  raise exception 'FAILED: B created a profile for someone else';
exception when insufficient_privilege then raise notice 'ok: profiles only for yourself'; end $$;
do $$ begin
  insert into public.profiles (id, username) values ('00000000-0000-0000-0000-00000000000b', 'ALICE');
  raise exception 'FAILED: duplicate username';
exception when unique_violation then raise notice 'ok: usernames are unique ignoring case'; end $$;

-- B asks A to be friends; until A accepts, B sees nothing more.
select public.request_friend('Alice');
select pg_temp.check((select status from public.my_friends()) = 'pending', 'request is pending');
select pg_temp.check((select n from public.my_friends()) is null, 'pending friend shows no number');
select pg_temp.check((select count(*) from public.sightings) = 0, 'still no sightings while pending');

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check((select incoming from public.my_friends()), 'A sees an incoming request');
select public.respond_friend('00000000-0000-0000-0000-00000000000b', true);

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.check((select n from public.my_friends()) = 3, 'friend B sees A is on 3');
select pg_temp.check((select last_lat from public.my_friends()) = 50.47, 'friend position rounded');
select pg_temp.check((select count(*) from public.sightings) = 0, 'even friends never see A''s exact pins');
delete from public.sightings where user_id <> auth.uid();
reset role;
select pg_temp.check((select count(*) from public.sightings where user_id = '00000000-0000-0000-0000-00000000000a') = 2, 'B cannot delete A''s sightings');

-- The edge function (service role) confirms plates for B.
reset role;
set role service_role;
select public.log_confirmed('00000000-0000-0000-0000-00000000000b', 'run', 1, 'hash-ab01', 'dvla', 51.5, -0.12, null);
do $$ begin
  perform public.log_confirmed('00000000-0000-0000-0000-00000000000b', 'run', 5, 'hash-x', 'dvla');
  raise exception 'FAILED: confirmed the wrong number';
exception when raise_exception then raise notice 'ok: confirmed run must be your current number'; end $$;
do $$ begin
  perform public.log_confirmed('00000000-0000-0000-0000-00000000000b', 'spot', 7, 'hash-ab01', 'dvla');
  raise exception 'FAILED: same plate twice';
exception when raise_exception then raise notice 'ok: the same plate cannot earn XP twice'; end $$;
select pg_temp.check(public.xp_of('00000000-0000-0000-0000-00000000000b') = 10 + 3, 'confirmed run XP with pin');
select pg_temp.check((select n from public.profiles where id = '00000000-0000-0000-0000-00000000000b') = 2, 'confirmed run moves B on');

-- Spots, removing them, undo and start again.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select public.log_sighting('spot', 23, 52.48, -1.9);
select pg_temp.check(public.xp_of(auth.uid()) = 13 + 2 + 3, 'unconfirmed spot XP');
delete from public.sightings where kind = 'spot' and user_id = auth.uid();
select pg_temp.check((select count(*) from public.sightings where user_id = auth.uid() and kind = 'spot') = 0, 'B removed their spot');
select pg_temp.check(public.undo_last_run() = 1, 'undo puts B back to 1');
select public.log_sighting('run');
select public.start_again();
select pg_temp.check((select n from public.profiles where id = auth.uid()) = 1, 'start again sets 1');

-- Signed-out visitors: map, leaderboard and totals only.
reset role;
set role anon;
select pg_temp.check((select count(*) from public.heat()) >= 1, 'anyone can see the heat map');
select pg_temp.check((select count(*) from public.leaderboard()) = 2, 'anyone can see the leaderboard');
select pg_temp.check((select players from public.stats()) = 2, 'anyone can see totals');
do $$ begin
  perform * from public.profiles;
  raise exception 'FAILED: anon read profiles';
exception when insufficient_privilege then raise notice 'ok: visitors cannot read profiles'; end $$;
do $$ begin
  perform public.log_sighting('run');
  raise exception 'FAILED: anon logged a plate';
exception when insufficient_privilege then raise notice 'ok: visitors cannot log plates'; end $$;

-- Deleting an account removes everything of theirs.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
reset role;
-- delete_account runs as its owner (postgres here, supabase_admin on Supabase).
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select public.delete_account();
select pg_temp.check((select count(*) from public.sightings where user_id = '00000000-0000-0000-0000-00000000000a') = 0, 'deleting an account removes its sightings');
select pg_temp.check((select count(*) from public.friendships) = 0, 'and its friendships');
\echo ALL CHECKS PASSED
