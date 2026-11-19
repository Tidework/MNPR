-- MNPR database: players, sightings and friends.
--
-- Rules the database enforces, whatever the app sends:
-- * Your run number only moves through log_sighting / log_confirmed, one step at a time.
-- * A confirmed sighting can only be written by the confirm-plate edge function (service role),
--   after it has checked the plate. Plates are never stored: only a keyed hash, so the same
--   plate can't earn you XP twice.
-- * Other people only ever see sightings rounded to about 1 km, with no names attached.
--   Exact pins are yours alone. Accepted friends see your number and your last position, rounded.

-- ---------- Tables ----------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  n integer not null default 1 check (n between 1 and 9999),
  car text not null default 'runabout' check (char_length(car) <= 20),
  paint text not null default 'red' check (char_length(paint) <= 20),
  created_at timestamptz not null default now()
);
create unique index profiles_username_key on public.profiles (lower(username));

create table public.sightings (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  n integer not null check (n between 1 and 9999),
  kind text not null check (kind in ('run', 'spot')),
  checked_by text check (checked_by in ('dvla', 'format')),
  plate_hash text,
  lat double precision check (lat between 49 and 61.5),
  lng double precision check (lng between -11 and 2.5),
  place text check (char_length(place) <= 60),
  created_at timestamptz not null default now(),
  check ((lat is null) = (lng is null)),
  check ((checked_by is null) = (plate_hash is null)),
  unique (user_id, plate_hash)
);
create index sightings_user_created on public.sightings (user_id, created_at desc);
create index sightings_n on public.sightings (n);

create table public.friendships (
  requester uuid not null references public.profiles (id) on delete cascade,
  addressee uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);
create index friendships_addressee on public.friendships (addressee);

-- ---------- Access ----------

alter table public.profiles enable row level security;
alter table public.sightings enable row level security;
alter table public.friendships enable row level security;

revoke all on public.profiles, public.sightings, public.friendships from anon, authenticated;

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester = a and f.addressee = b) or (f.requester = b and f.addressee = a))
  );
$$;

-- Profiles: you read and edit your own (car and paint only; the number moves through the functions below).
grant select, insert (id, username, car, paint), update (car, paint) on public.profiles to authenticated;
create policy "own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "friends' profiles" on public.profiles for select to authenticated using (public.are_friends(id, (select auth.uid())));
create policy "create own profile" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "edit own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Sightings: only your own (friends get your number and rough last position from my_friends()).
-- You can remove your own "logged for others" ones.
grant select, delete on public.sightings to authenticated;
create policy "own sightings" on public.sightings for select to authenticated using (user_id = (select auth.uid()));
create policy "remove own spots" on public.sightings for delete to authenticated using (user_id = (select auth.uid()) and kind = 'spot');

-- Friendships: you see the ones you're in; changes go through the functions below.
grant select on public.friendships to authenticated;
create policy "own friendships" on public.friendships for select to authenticated
  using ((select auth.uid()) in (requester, addressee));

-- ---------- XP ----------
-- Must match xpOf() in src/page.html.
-- Run: 10 confirmed, 4 unconfirmed. For others: 5 confirmed, 2 unconfirmed.
-- +3 for a pin, +2 for a place name, +20 on every tenth number of a run.

create or replace function public.sighting_xp(kind text, n integer, confirmed boolean, has_pin boolean, has_place boolean)
returns integer language sql immutable as $$
  select case when kind = 'run' then (case when confirmed then 10 else 4 end) + (case when n % 10 = 0 then 20 else 0 end)
              else (case when confirmed then 5 else 2 end) end
         + (case when has_pin then 3 else 0 end) + (case when has_place then 2 else 0 end);
$$;

create or replace function public.xp_of(uid uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(public.sighting_xp(kind, n, checked_by is not null, lat is not null, place is not null)), 0)::integer
  from public.sightings where user_id = uid;
$$;

-- ---------- Logging ----------

create or replace function public.too_many_recent(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) >= 120 from public.sightings where user_id = uid and created_at > now() - interval '1 hour';
$$;

-- An unconfirmed sighting: just the number. For a run, the number is always your current one.
create or replace function public.log_sighting(p_kind text, p_n integer default null,
  p_lat double precision default null, p_lng double precision default null, p_place text default null)
returns public.sightings
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  cur integer;
  row public.sightings;
begin
  if uid is null then raise exception 'Sign in to log a plate.'; end if;
  select n into cur from public.profiles where id = uid for update;
  if cur is null then raise exception 'Choose a username first.'; end if;
  if public.too_many_recent(uid) then raise exception 'That is a lot of plates in an hour. Try again later.'; end if;
  if p_kind = 'run' then
    insert into public.sightings (user_id, n, kind, lat, lng, place)
    values (uid, cur, 'run', round(p_lat::numeric, 4), round(p_lng::numeric, 4), nullif(trim(p_place), ''))
    returning * into row;
    update public.profiles set n = cur + 1 where id = uid;
  elsif p_kind = 'spot' then
    if p_n is null or p_n < 1 then raise exception 'Enter the number you saw.'; end if;
    insert into public.sightings (user_id, n, kind, lat, lng, place)
    values (uid, p_n, 'spot', round(p_lat::numeric, 4), round(p_lng::numeric, 4), nullif(trim(p_place), ''))
    returning * into row;
  else
    raise exception 'Unknown kind of sighting.';
  end if;
  return row;
end;
$$;

-- A confirmed sighting. Only the confirm-plate edge function may call this, after checking the plate.
create or replace function public.log_confirmed(p_user uuid, p_kind text, p_n integer, p_plate_hash text, p_checked_by text,
  p_lat double precision default null, p_lng double precision default null, p_place text default null)
returns public.sightings
language plpgsql security definer set search_path = '' as $$
declare
  cur integer;
  row public.sightings;
begin
  select n into cur from public.profiles where id = p_user for update;
  if cur is null then raise exception 'Choose a username first.'; end if;
  if public.too_many_recent(p_user) then raise exception 'That is a lot of plates in an hour. Try again later.'; end if;
  if exists (select 1 from public.sightings where user_id = p_user and plate_hash = p_plate_hash) then
    raise exception 'You have already logged that plate.';
  end if;
  if p_kind = 'run' then
    if p_n <> cur then raise exception 'That plate is not your number. You need %.', cur; end if;
    insert into public.sightings (user_id, n, kind, checked_by, plate_hash, lat, lng, place)
    values (p_user, cur, 'run', p_checked_by, p_plate_hash, round(p_lat::numeric, 4), round(p_lng::numeric, 4), nullif(trim(p_place), ''))
    returning * into row;
    update public.profiles set n = cur + 1 where id = p_user;
  else
    insert into public.sightings (user_id, n, kind, checked_by, plate_hash, lat, lng, place)
    values (p_user, p_n, 'spot', p_checked_by, p_plate_hash, round(p_lat::numeric, 4), round(p_lng::numeric, 4), nullif(trim(p_place), ''))
    returning * into row;
  end if;
  return row;
end;
$$;

create or replace function public.undo_last_run() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  last public.sightings;
begin
  select * into last from public.sightings where user_id = uid and kind = 'run' order by created_at desc, id desc limit 1;
  if last.id is null then return (select n from public.profiles where id = uid); end if;
  delete from public.sightings where id = last.id;
  update public.profiles set n = last.n where id = uid;
  return last.n;
end;
$$;

create or replace function public.start_again() returns void
language sql security definer set search_path = '' as $$
  update public.profiles set n = 1 where id = auth.uid();
$$;

-- ---------- Friends ----------

create or replace function public.request_friend(p_username text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  other uuid;
begin
  select id into other from public.profiles where lower(username) = lower(trim(p_username));
  if other is null then raise exception 'No player called %.', p_username; end if;
  if other = uid then raise exception 'That is you.'; end if;
  -- If they already asked you, this accepts.
  update public.friendships set status = 'accepted' where requester = other and addressee = uid;
  if found then return 'accepted'; end if;
  insert into public.friendships (requester, addressee) values (uid, other) on conflict do nothing;
  return 'requested';
end;
$$;

create or replace function public.respond_friend(p_requester uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_accept then
    update public.friendships set status = 'accepted' where requester = p_requester and addressee = auth.uid();
  else
    delete from public.friendships where requester = p_requester and addressee = auth.uid();
  end if;
end;
$$;

create or replace function public.remove_friend(p_other uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.friendships
  where (requester = auth.uid() and addressee = p_other) or (requester = p_other and addressee = auth.uid());
$$;

-- Your friends and pending requests, each with their number, car, XP and last position (to about 1 km).
create or replace function public.my_friends()
returns table (id uuid, username text, n integer, car text, paint text, xp integer, status text, incoming boolean,
  last_lat double precision, last_lng double precision, last_place text, last_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id, p.username,
         case when f.status = 'accepted' then p.n end,
         p.car, p.paint,
         case when f.status = 'accepted' then public.xp_of(p.id) end,
         f.status, f.addressee = auth.uid(),
         round(s.lat::numeric, 2)::double precision, round(s.lng::numeric, 2)::double precision, s.place, s.created_at
  from public.friendships f
  join public.profiles p on p.id = case when f.requester = auth.uid() then f.addressee else f.requester end
  left join lateral (
    select lat, lng, place, created_at from public.sightings
    where user_id = p.id and lat is not null and f.status = 'accepted'
    order by created_at desc limit 1
  ) s on true
  where auth.uid() in (f.requester, f.addressee);
$$;

-- ---------- Public views of the map ----------

-- Every sighting with a pin, rounded to about 1 km, with its day and no names. Optionally one number only.
create or replace function public.heat(p_n integer default null)
returns table (lat double precision, lng double precision, n integer, day date)
language sql stable security definer set search_path = '' as $$
  select round(lat::numeric, 2)::double precision, round(lng::numeric, 2)::double precision, n, created_at::date
  from public.sightings
  where lat is not null and (p_n is null or n = p_n)
  order by created_at desc
  limit 20000;
$$;

create or replace function public.leaderboard()
returns table (username text, car text, paint text, best integer, xp integer)
language sql stable security definer set search_path = '' as $$
  select p.username, p.car, p.paint, coalesce(max(s.n) filter (where s.kind = 'run'), 0), public.xp_of(p.id)
  from public.profiles p left join public.sightings s on s.user_id = p.id
  group by p.id
  having count(s.*) filter (where s.kind = 'run') > 0
  order by 4 desc, 5 desc
  limit 100;
$$;

create or replace function public.stats()
returns table (sightings bigint, players bigint, highest integer)
language sql stable security definer set search_path = '' as $$
  select (select count(*) from public.sightings),
         (select count(distinct user_id) from public.sightings),
         coalesce((select max(n) from public.sightings where kind = 'run'), 0);
$$;

-- ---------- Your account ----------

create or replace function public.delete_account() returns void
language sql security definer set search_path = '' as $$
  delete from auth.users where id = auth.uid();
$$;

-- ---------- Who may call what ----------

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.heat(integer), public.leaderboard(), public.stats() to anon, authenticated;
grant execute on function public.log_sighting(text, integer, double precision, double precision, text),
  public.undo_last_run(), public.start_again(), public.request_friend(text), public.respond_friend(uuid, boolean),
  public.remove_friend(uuid), public.my_friends(), public.delete_account(), public.xp_of(uuid),
  public.are_friends(uuid, uuid), public.sighting_xp(text, integer, boolean, boolean, boolean) to authenticated;
grant execute on function public.log_confirmed(uuid, text, integer, text, text, double precision, double precision, text) to service_role;
