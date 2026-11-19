# MNPR

The number plate game, logged.

## The game

- Spot a plate with 1 on it, then 2, then 3, and so on.
- It only counts when you see it. You can't save a plate for later.
- The plate's digits must be exactly the number you need. Leading zeros are fine: `AB07 CDE` counts for 7, `AB17 CDE` doesn't.

## The app

`index.html` is the whole app in one file. Open it in a browser to play.

To change it, edit `src/page.html` (the map outlines live in `src/uk.json`), then run `python3 build.py`. That rebuilds `index.html`, plus `preview.html` for publishing as a claude.ai artifact.

The look is 16-bit pixel art: a sky-and-road scene with your car, ten unlockable cars, XP for every plate you log (more for pins and place names), and a pixel heat map.

- **Play**: shows the number you need next. Type a plate to check it, tap **Spotted**, then drop a pin on the map to log where you were. **Log another number** adds any other number you've seen to the map for other players, without changing your run.
- **Map**: a pixel heat map of sightings. Zoom and drag to explore. **Find a number** shows exactly where that number has been seen. Friends appear as their car with the number they're on, roughly where they last logged a plate.
- **Garage**: pick your car and paint. New cars unlock as you level up.
- **Top**: who has reached the highest number.

Privacy: plates are never saved. Pins are exact (about 10 m) and visible to everyone with access; friends' positions are shown to about 1 km.

City and town positions come from [GeoNames](https://www.geonames.org/) (CC BY 4.0). Motorways and A roads come from OS Open Roads: contains OS data © Crown copyright and database right 2026 (Open Government Licence); they appear as you zoom in, with UK-style road number signs.

Design checks use [Impeccable](https://github.com/pbakaus/impeccable) (Apache 2.0), kept in `.claude/skills/impeccable`.

## Where the data lives

- Opened as a plain web page, progress is saved in that browser only.
- Run as a claude.ai artifact, sightings go to a shared store, so everyone with access shares one map and leaderboard.
- To open it up to anyone (friends without a Claude account, or nationally), the next step is to host the page and give it a small shared database.

Map outlines: [Natural Earth](https://www.naturalearthdata.com/) (public domain).
