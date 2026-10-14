# Quick settings sheet

## Summary

A sheet, not a bar (direction doc "Quick settings"): brightness and warmth as outlined bars with minus
and plus, then a grid of toggles and actions (Wi‑Fi, Night, Rotation lock, Sync books, Screenshot,
Sleep), the on state filled in ink. KOReader's own top menu keeps the top edge.

## Behavior

- Opens from the entry point the owner decides in Q-irxgmk; until answered this feature is blocked.
- Brightness and warmth read and write the device's frontlight through KOReader's device API, in
  steps; holding minus goes to zero.
- Toggles reflect the real state on open and act immediately: Wi‑Fi, night mode (which repaints the
  home through `home/night-mode`), rotation lock; Sync books runs the configured sync plugin if present
  and is greyed otherwise; Screenshot and Sleep dispatch KOReader's actions.
- Drawn with the sheet component in both looks; goldens on the Colorsoft profile.

## Notes

Which KOReader device calls set brightness and warmth on the Colorsoft, and whether the Paperwhite's
warm light uses the same, is a specify-time spike with citations.
