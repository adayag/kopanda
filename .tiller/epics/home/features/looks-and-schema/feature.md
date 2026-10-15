# Schema, settings, looks, icon registry and the swatch screen

## Summary

The contract everything else reads from: the settings schema as pure data, the settings store that
enforces it, the two looks (Editorial, Diner) with their grey and night palettes, the icon registry, and
a swatch screen that renders every token so the owner can push it to the Colorsoft once and fix the
colours (design §5 Schema, Settings, Looks, Icons; direction doc "The two looks", "Icons").

## Behavior

### Schema

- `kopanda.koplugin/schema.lua` is pure data: no `require`, no functions, loadable by a plain `dofile`
  on the device's or the emulator's LuaJIT. It returns `{ version = 1, keys = { ... } }`, where `keys`
  is an ordered list (the order the device menus and the studio form will show) of entries
  `{ id, type, default, label, group }` plus the fields the entry's type needs.
- This feature ships one key, `look`: type `choice`, choices Diner (`diner`) and Editorial
  (`editorial`), each with its label, default `diner`, group `appearance`. The direction doc's other
  keys ("Schema consequences") enter the schema with the feature that reads them, each justified there;
  `layout.rows` arrives with `home-layout`. The schema's ten keys are therefore the epic's sum, not this
  feature's.
- The type set is the types some key uses, held in `settings.lua` as one validator per type (the
  schema stays data). This feature defines `choice` only: `choices` is an ordered
  list of `{ value, label }` and the default is one of the values. A later feature that adds a key of a
  new type (boolean, string, path, list) adds the type, its validation and its tests with it.
- `bin/schema-json` prints the schema as JSON on stdout: the emulator's LuaJIT `dofile`s `schema.lua`
  and encodes it with KOReader's bundled `rapidjson` with sorted keys, so two runs are byte-identical.
  The studio (stage 2) runs this command at build time; it needs `KOPANDA_EMULATOR` as `bin/check`
  does and refuses with exit 2 without it. It never depends on Tiller.

### Settings

- `kopanda.koplugin/settings.lua` opens `settings/kopanda/settings.lua` under KOReader's settings
  directory through `LuaSettings`. `Settings.get(key)` returns the stored value when it is valid for the
  key's type and the schema default otherwise (missing file, corrupt file, a value the schema doesn't
  allow, such as a look that no longer exists). A corrupt file falls back to KOReader's `.old` backup
  when one is usable, as `LuaSettings` does, and to the defaults otherwise. `Settings.get` of a key the schema doesn't define logs
  and returns nil.
- `Settings.set(key, value)` refuses, without touching the file, a key the schema doesn't define and a
  value the key's type doesn't allow, returning false and the reason. An accepted write is flushed at
  once, creating `settings/kopanda/` if needed, and survives a reopen.
- The file carries `schema_version`, a reserved field beside the keys and not a setting. A file with no
  version is version 1. On open, a file older than the schema runs the migration steps in
  `kopanda.koplugin/migrations.lua` in order, one per version, then is stamped and written. A file newer
  than the schema (written by a newer plugin or studio) is read with the same per-key fallback, and
  every write to it is refused, so an older plugin never clobbers it. Version 1 has no steps. The
  version is bumped only when stored values must change shape (a key renamed, retyped or removed);
  adding a key with a default needs no bump.

### Looks

- `kopanda.koplugin/looks/diner.lua` and `looks/editorial.lua` are pure data, each holding the direction
  doc's tokens ("The two looks", the night palettes, the Paperwhite greys): faces by role (display, text,
  accent), three palettes by role (`day`, `night`, `grey`), stroke weights, shadow offsets,
  corner radii, and the tile, progress, sheet, chip and label styles. The palettes are the only colour
  tokens, `#rrggbb` strings; every other style token names a colour by its palette role. Sizes are in
  board pixels (the canvas's half-size units), which KOReader scales to the screen through
  `Screen:scaleBySize` and `Font:getFace`. A role a look doesn't have (Editorial's accent face and accent
  colours, Diner's hairline) is present with the value `false`, so both looks declare the same token
  paths and a widget can ask either look for any token.
- The `grey` palette maps every colour role to an explicit grey (equal red, green and blue) from the
  direction doc's Paperwhite list, because KOReader greys a colour by luminance and two hues can land on
  the same grey. Diner's grey progress fill is marked as a 135° hatch of ink on paper.
- `kopanda.koplugin/looks.lua` returns a look's table by id, the active look from `Settings.get("look")`,
  and the palette variant to draw with: `grey` when `Screen:isColorEnabled()` is false, `day`
  otherwise. Choosing the night palette under KOReader's night mode is `night-mode`'s work.

### Fonts

- Fonts ship as static instances (no variable-font tables) under `kopanda.koplugin/fonts/<family>/`,
  each family with its `OFL.txt`, at the weights the looks use: Newsreader 16pt Medium and Medium
  Italic; IBM Plex Sans Regular and Medium; Bricolage Grotesque Medium, Bold and ExtraBold; Caveat
  Regular. `fonts/SOURCES.md` names each file's upstream repository, commit and path.
- `kopanda.koplugin/fonts.lua` turns a face token into a KOReader face through `Font:getFace` with the
  file's path, made absolute or `./`-relative so KOReader treats it as a path and not a name under its
  own fonts folder. A file that won't load is logged and returns nil, never an error.

### Icons

- `kopanda.koplugin/icons.lua` is a registry: one entry per icon with a stable `id`, a human
  `label`, `used_in` (the places it appears, by the canvas board or widget), and its default stroke SVG
  `file` under `kopanda.koplugin/icons/`. The default set is every distinct icon the canvas
  (`2026-10-13-kopanda-screens/`) draws: launcher, weather, nav, sheet, quick-settings and empty-state
  icons. The canvas strokes with `currentColor`, which NanoSVG renders as mid-grey, so every file is
  normalised to black ink.
- Every SVG file under `icons/` has an entry and every entry a file. Plugin code reaches an icon only by
  id through the registry; no other module names an SVG file.

### Swatch screen

- Tools › KoPanda › Swatches opens a full-screen swatch screen in the file manager and the reader. A tap
  closes it. It is a test pattern, not part of the shell: it stays reachable while another shell plugin
  is enabled, when Tools › KoPanda holds Swatches alone, because the owner's Kindle runs SimpleUI until
  the studio exists. Everything else the coexistence guard turns off stays off.
- The screen shows six panels, Editorial and Diner across, day, night and grey down. Each panel is
  filled with its palette's paper colour and shows every colour role as a chip labelled with the role's
  name and hex value in that palette's ink, and a line in each of the look's faces naming the face and
  weight. Below the panels, every registered icon is drawn in ink with its id.
- With KOReader's night mode on, the screen says above the panels that KOReader inverts these colours
  and night mode should be off to judge them.
- After its first paint it announces itself with the dev-loop settled signal (`KoPandaSettled`,
  `screen = "swatch"`). A failure in its build, paint or gestures is logged, closes it, and leaves
  the file manager or the reader it was opened from on top.

### Settling the values on the panel

- The owner pushes the plugin to the Colorsoft by hand (handoff §4) and reads the swatch screen there.
  Any value the panel changes is changed in the look files and in the direction doc's tables together,
  and the swatch goldens are regenerated; the direction doc follows the panel, not the other way round.

## Notes

Fonts: all four faces are OFL-1.1. Bricolage Grotesque's unlabelled static set (`fonts/ttf/`) is the
one shipped; its optical size is inferred as 14pt, not documented upstream. Newsreader ships static
instances only at 6pt, 16pt and 72pt; 16pt is used for every Editorial size.

The swatch's coexistence exception changes one line of `plugin-shell`'s accepted behaviour (its C11
said no Tools entry under refusal); the home, tab, action and pre-build stay refused, and this
feature's contract carries that as a preserve criterion.

Out of this feature: generating menus from the schema (`device-menus`), drawing the night palette under
KOReader's inversion (`night-mode`), reading any key but `look`.
