# MNPR: notes for Claude

MNPR (Manual Number Plate Recognition) is a phone-first web game for the number plate game: spot plates showing 1, then 2, then 3, and so on, log where you saw each one, earn XP and unlock pixel cars. Owner: Lyle (a designer, new to git). Explain steps plainly.

## The rules of the game
- You count up in order. A plate counts only when you see it; you can't save one for later.
- The plate's digits must be exactly your number. Leading zeros are fine (007 counts for 7, 17 doesn't).
- Your number stays with you and only moves when you log the right plate.

## Code
- Edit `src/page.html`, then run `python3 build.py`. That writes `index.html` (the full page) and `preview.html` (for the claude.ai artifact preview). Never edit `index.html` by hand.
- Data, each made by a script in `tools/` and credited on the map:
  - `src/uk.json`: coastline, `tools/outlines.py`, Natural Earth 1:10m.
  - `src/towns.json`: every official UK city, Ireland's cities and Douglas, then large towns (60,000+ people, e.g. Crawley), `tools/cities.py`, positions from GeoNames (CC BY 4.0). Lyle wants cities and major towns only, not small towns. Towns label from 1.5x zoom.
  - `src/roads.json`: motorways and A roads in Great Britain, `tools/roads.py`, OS Open Roads (OGL: "Contains OS data © Crown copyright and database right"). Motorways show at every zoom, primary A roads from 1.5x, other A roads from 3x; signs use real UK sign colours.
- Preview artifact: https://claude.ai/artifact/A64fx9Ko2u7jyXYv9pgtgr (publish `preview.html` to that URL).

## Design
- Look: 16-bit pixel art after Krillion (krillion.io): pixel sky and road scene, dark navy deck, cyan double-framed panels, pink accent, yellow number plate, VT323 font, CRT scanlines. Cars have eyes. Keep it fun and animated.
- Use the Impeccable skill (`.claude/skills/impeccable`, from github.com/pbakaus/impeccable) for design work and checks. After UI changes run `.claude/skills/impeccable/scripts/impeccable detect --json index.html`. The cyan glow and the scanlines are the chosen look, so its `dark-glow` and `repeating-stripes-gradient` findings stay.
- Icons are pixel sprites drawn in code (`ICONS` in `src/page.html`), never text characters or emoji.

## Privacy
- Plates are never saved. Pins are exact; friends' positions on the map are rounded to about 1 km.
