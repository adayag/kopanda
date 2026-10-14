# Rows and columns with date, clock, weather, quote and stats

## Summary

The home screen's layout engine and its text widgets. Rows of one to three columns, laid out at runtime
from the screen's size through `Screen:scaleBySize` (direction doc "Screens"), drawing every visual value
from the active look. The widgets that need no book: date, clock, weather, quote, reading stats.

## Behavior

- The layout section of the settings (rows, each with slots and width shares) becomes a vertical stack
  of rows filling the screen width; a row's columns take their shares. A row that would not fit the
  height budget is refused at edit time, never paged (design §1b).
- Widgets are tables with `id`, `build(width, ctx)`, `height(ctx)` and a settings prefix.
- Date and clock follow the look's display face; clock honours the 24-hour key.
- Weather shows the cached line and its age; it fetches once per KOReader session when online and on
  tap, from Open-Meteo, with the location stored as coordinates (design §1b); with nothing cached it
  shows "Weather needs Wi‑Fi" (direction doc "First run and failures").
- Quote draws from a shipped public-domain file; "My highlights" is a later source.
- Reading stats reads KOReader's Statistics database for streak, minutes today and books this month;
  with the plugin disabled it says so; with nothing read it shows the empty wording.
- Goldens for both looks on both profiles; a paint-time budget asserted from `dev-loop`'s measurement.
- The screen redraws only on input.

## Notes

The featured book and the launcher are separate features and plug into the same row engine. Which
Statistics tables hold streak and minutes is a specify-time spike with citations. Weather units and the
geocoding call are specify-time detail; the owner's place is a question for that spec.
