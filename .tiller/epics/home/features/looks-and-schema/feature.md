# Schema, settings, looks, icon registry and the swatch screen

## Summary

The contract everything else reads from: the settings schema as pure data, the settings store that
enforces it, the two looks (Editorial, Diner) with their grey and night palettes, the icon registry, and
a swatch screen that renders every token so the owner can push it to the Colorsoft once and fix the
colours (design §5 Schema, Settings, Looks, Icons; direction doc "The two looks", "Icons").

## Behavior

- `schema.lua` is pure data: the ten keys the direction doc lists ("Schema consequences"), each with
  type, default, label and group, plus the layout section. A LuaJIT one-liner dumps it to JSON; a test
  asserts the dump is deterministic.
- `settings.lua` reads through KOReader's `LuaSettings` at `settings/kopanda/settings.lua`, falls back
  to the schema default, refuses a write to a key the schema doesn't define, and carries a schema
  version with a migration step (design §1b).
- `looks/editorial.lua` and `looks/diner.lua` hold the token tables from the direction doc, each with a
  grey variant and a night palette. A test proves every token the widgets will read exists in both.
  Diner is the default.
- `icons.lua` is a registry: id, label, places used, default SVG path under `icons/`. A test proves every
  SVG file has an entry and every entry a file. Nothing draws an SVG by file name.
- Fonts ship as static instances at the weights used, under the plugin folder, and a spec proves each
  loads by path (design §1b; assumption to verify first).
- A swatch screen, reachable from the Tools menu, renders both palettes, both night palettes and both
  greys with their names, so one hand push to the Kindle settles the values.

## Notes

The swatch result may change token values; the direction doc's table is updated from the panel, not
the other way round. Fonts: all four faces are OFL. Specify-time: the exact schema type set and how the
JSON dump is invoked by the studio.
