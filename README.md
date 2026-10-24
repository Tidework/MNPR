# MNPR

The number plate game, logged.

## The game

- Spot a plate with 1 on it, then 2, then 3, and so on.
- It only counts when you see it. You can't save a plate for later.
- The plate's digits must be exactly the number you need. Leading zeros are fine: `AB07 CDE` counts for 7, `AB17 CDE` doesn't.

## The app

`index.html` is the whole app: one file, no build step. Open it in a browser to play.

- **Play**: shows the number you need next. Type a plate to check it, tap **Spotted**, then drop a pin on the map to log where you were. **Log another number** adds any other number you've seen to the map for other players, without changing your run.
- **Map**: a road-atlas style heat map of sightings. Zoom and drag to explore. **Find a number** shows exactly where that number has been seen. Friends appear as plates showing the number they're on, roughly where they last logged a plate.
- **Top**: who has reached the highest number.

Privacy: plates are never saved. Pins are exact (about 10 m) and visible to everyone with access; friends' positions are shown to about 1 km.

Road lines on the map are a stylised sketch through the main towns, not surveyed routes.

## Where the data lives

- Opened as a plain web page, progress is saved in that browser only.
- Run as a claude.ai artifact, sightings go to a shared store, so everyone with access shares one map and leaderboard.
- To open it up to anyone (friends without a Claude account, or nationally), the next step is to host the page and give it a small shared database.

Map outlines: [Natural Earth](https://www.naturalearthdata.com/) (public domain).
