# Editorial and Diner token tables with night and grey variants

## Approach

1. `kopanda.koplugin/looks/editorial.lua` and `looks/diner.lua`, pure data, values typed from the
   direction doc ("The two looks", the night palettes, "Greys for the Paperwhite"). Every size is in
   board pixels, the canvas's half-size unit: lengths are scaled at draw time by `Screen:scaleBySize`
   (about px × short edge / 600, `base/ffi/framebuffer.lua:414-425`) and font sizes by `Font:getFace`,
   which scales its size argument itself (`frontend/ui/font.lua:276`), so a font size is never
   pre-scaled. Board px × 2.1 at 1264 px lands within a few percent of the doc's device sizes:
   - `faces = { display, text, accent }`, each `{ file = "fonts/<family>/<file>.ttf", label = "Newsreader 500" }`
     or `false` (Editorial's accent).
   - `palettes = { day = {...}, night = {...}, grey = {...} }`, the same roles in all three and in
     both looks: at least `paper`, `ink`, `muted`, `text`, `hairline`, `hairline_light`, `teal`,
     `pink`, `mustard`, `outline`, `shadow`. A role the doc gives no value for in a variant takes the
     value the doc implies (Editorial's day `text` is its ink; Diner's night `outline` and `shadow`
     are its night ink, "outlines and hard shadows turn cream"); a role the look doesn't have is
     `false` (Editorial's accents, Diner's hairlines). Final role names are the task's; the rule is
     identical paths everywhere.
   - `grey` maps each role to one of the direction doc's Paperwhite greys, explicit and neutral,
     chosen so roles that differ in colour stay distinct in grey (KOReader greys by luminance,
     `base/ffi/blitbuffer.lua:464-467`). Diner's `progress.fill_grey = "hatch_135"`, Editorial's `false`.
   - `stroke`, `shadow` (offsets in board px, colour as a palette role name), `radius`, and `tile`,
     `progress`, `sheet`, `chip`, `label` styles as small tables of numbers, palette role names, booleans
     and the `hatch_135` marker, with the same paths in both looks. Only palette values are colours.
2. `kopanda.koplugin/looks.lua`: `Looks.get(id)` (one of the two tables), `Looks.active()` (the table
   for `Settings.get("look")`), `Looks.ids()` (`{ "editorial", "diner" }`, the swatch's column order),
   `Looks.variant()` returning `"grey"` when `Screen:isColorEnabled()` is false, else `"day"`.
   `isColorEnabled` honours the user's `color_rendering` setting before the panel's capability
   (`frontend/device/generic/device.lua:264-271`), so the emulator's paperwhite profile gets grey.
   `Looks.color(hex)` calls `Blitbuffer.colorFromString` in a pcall and returns nil on failure: it
   returns nil only for a wrong length and raises on non-hex characters or a non-string
   (`base/ffi/blitbuffer.lua:2653-2683`).
3. `main.lua` requires `looks`, `looks/editorial`, `looks/diner` at load time. `HOOKS.md`: `device`
   `isColorEnabled`, `ffi/blitbuffer` `colorFromString`.

## Surfaces

`kopanda.koplugin/looks.lua`, `looks/editorial.lua`, `looks/diner.lua`, `main.lua` (requires only),
`HOOKS.md`, `spec/unit/looks_spec.lua`, `spec/unit/fonts_spec.lua` (one added case).

## Tests

Written first, failing before the tables exist.

- `looks_spec.lua` (C5): collect every key path in each look (recursively, a path ending at a non-table
  value) and assert the two sets are equal; within each look assert `day`, `night` and `grey` have
  the same role set; every palette value is `false` or matches `^#%x%x%x%x%x%x$` (checked before
  calling it) and gives a non-nil `colorFromString`; every non-palette style value that names a colour
  names a palette role; every `grey` value has equal R, G and B; the look files load by `dofile` with no
  `require`; `Looks.active()` is Diner with no settings file and Editorial after
  `Settings.set("look", "editorial")`; `Looks.variant()` with `color_rendering` set false and true in
  `G_reader_settings`.
- `fonts_spec.lua` gains (C6): every non-false `faces.*.file` in either look exists and loads through
  `Fonts.face`.

## Edge cases

- The direction doc names a value only for one variant: the task records each implied value in a
  comment on that line, so the panel check can find it.
- `colorFromString` also accepts `#vv` and `#rrggbbaa`; the spec holds tokens to `#rrggbb` so the
  studio's form can treat them uniformly later.
