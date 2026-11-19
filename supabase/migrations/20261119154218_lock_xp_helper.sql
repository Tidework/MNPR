-- Supabase's security advisor: give sighting_xp a fixed search_path, and keep it internal
-- (only xp_of, which runs as its owner, needs it).
alter function public.sighting_xp(text, integer, boolean, boolean, boolean) set search_path = '';
revoke execute on function public.sighting_xp(text, integer, boolean, boolean, boolean) from authenticated;
