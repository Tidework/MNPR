# MNPR: notes for Claude

MNPR (Manual Number Plate Recognition) is a phone-first web game for the number plate game: spot plates showing 1, then 2, then 3, and so on, log where you saw each one, earn XP and unlock pixel cars. Owner: Lyle (a designer, new to git). Explain steps plainly.

## The rules of the game
- You count up in order. A plate counts only when you see it; you can't save one for later.
- The plate's digits must be exactly your number. Leading zeros are fine (007 counts for 7, 17 doesn't).
- Your number stays with you and only moves when you log the right plate.
- Confirmed sighting: the full plate, checked (UK format, right number, DVLA when the key is set): full XP. Unconfirmed: just the number: less XP.

## Code
- Edit `src/page.html`, then run `python3 build.py`. That writes `index.html` (the full page) and `preview.html` (for the claude.ai artifact preview). Never edit `index.html` by hand.
- Data, each made by a script in `tools/` and credited on the map:
  - `src/uk.json`: coastline, `tools/outlines.py`, Natural Earth 1:10m.
  - `src/towns.json`: every official UK city, Ireland's cities and Douglas, then large towns (60,000+ people, e.g. Crawley), `tools/cities.py`, positions from GeoNames (CC BY 4.0). Lyle wants cities and major towns only, not small towns. Towns label from 1.5x zoom.
  - `src/roads.json`: motorways and A roads in Great Britain, `tools/roads.py`, OS Open Roads (OGL: "Contains OS data © Crown copyright and database right"). Motorways show at every zoom, primary A roads from 1.5x, other A roads from 3x; signs use real UK sign colours.
- Preview artifact: https://claude.ai/artifact/A64fx9Ko2u7jyXYv9pgtgr (publish `preview.html` to that URL). The preview plays on one device only.
- Online version: GitHub Pages (`index.html`) with Supabase (`src/config.json` holds the public URL and key; empty means device-only). See `SETUP.md`.
  - Database: `supabase/migrations/`. Test every change on plain Postgres with `supabase/tests/run.sh` before applying it. XP rules live in both `sighting_xp()` and `sightingXp()` in `src/page.html`: change them together.
  - Plate checker: `supabase/functions/confirm-plate/` (DVLA lookup when the `DVLA_API_KEY` secret is set). `plates.js` there is the single source of the UK plate rules; `build.py` inlines it into the page. Test with `node supabase/tests/plates_test.mjs`.
  - MNPR is separate from Tidework: its own Supabase account, never the Tidework Club project. The claude.ai Supabase connector points at Tidework, so don't use it here.
  - Live project `pkzkkawhfdbvqdzhymzy`. Reach it through the Supabase Management API (`https://api.supabase.com/v1/projects/pkzkkawhfdbvqdzhymzy/...`): the access token is a network secret on the MNPR environment, so plain curl works; Node needs `NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt`. Apply migrations with `POST .../database/migrations` and keep local file names matching the versions it records. Deploy the function with `POST .../functions/deploy?slug=confirm-plate` (index.ts and plates.js). After changes run `supabase/tests/live_test.mjs`.

## Design
- Look: 16-bit pixel art after Krillion (krillion.io): pixel sky and road scene, dark navy deck, cyan double-framed panels, pink accent, yellow number plate, VT323 font, CRT scanlines. Cars have eyes. Keep it fun and animated.
- Use the Impeccable skill (`.claude/skills/impeccable`, from github.com/pbakaus/impeccable) for design work and checks. After UI changes run `.claude/skills/impeccable/scripts/impeccable detect --json index.html`. The cyan glow and the scanlines are the chosen look, so its `dark-glow` and `repeating-stripes-gradient` findings stay.
- Icons are pixel sprites drawn in code (`ICONS` in `src/page.html`), never text characters or emoji.

## Privacy
- Plates are never saved; confirmed sightings keep only a keyed hash so a plate can't earn XP twice.
- Everyone sees the map rounded to about 1 km with no names. Exact pins are yours alone; accepted friends see your number and roughly (1 km) where you last logged.
