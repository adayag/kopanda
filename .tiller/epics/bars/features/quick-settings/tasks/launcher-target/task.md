# Quick settings as a KoPanda launcher target with its registry icon, schema and studio catalog

## Approach

The owner can place "Quick settings" on the home's launcher or in a launcher folder, from the device's entry
picker or the studio. Starts after `bars/quick-settings/panel` (it opens `QuickSettings.open`); independent of
`controls`. Repo lines on `main` at `e6f2912`. The feature's "The launcher target" and D9 are the spec.

1. **The icon.** Lucide's `sliders-horizontal` (ISC, `icons/LICENSE-lucide.txt`) as
   `kopanda.koplugin/icons/quick_settings.svg`, stroke 2 and inked black like its siblings
   (`spec/unit/icons_spec.lua:88-130`), with the Lucide comment the others carry (`icons.lua:56-61`), and a
   registry entry `{ id = "quick_settings", label = "Quick settings", used_in = { "launcher" }, file =
   "icons/quick_settings.svg" }`. `wifi_off` gains `"quick settings"` in `used_in` (`icons.lua:25`); `power`
   already has it (`:51`).
2. **The target.** `LauncherEntries.KOPANDA.quick_settings = { label = "Quick settings", icon =
   "quick_settings" }` (`launcher_entries.lua:18-23`) and `KOPANDA_RUN.quick_settings` (`:122-139`):
   `require("quick_settings").open{ started = time.monotonic() }`, required at call time since
   `quick_settings` requires `launcher_entries`, as `folder_sheet` is (`:164-170`).
3. **The schema.** `schema.lua`'s `launcher.entries.targets.kopanda` (`:104-107`) gains `"quick_settings"`
   last; the default six (`:108-115`) and the version (`:7`) don't change; the comment over the key
   (`:98-100`) still holds.
4. **Regenerated:** `npm run schema` and `npm run catalog` in `studio/` (`studio/package.json:18-19`) rewrite
   `studio/src/schema.json` and `studio/src/catalog.json`; `KOPANDA_UPDATE_GOLDENS=1 bin/check
   spec/emulator/swatch_golden_spec.lua` regenerates the two swatch goldens; open each PNG (`open <png>`) and
   check only the new cell differs. Then `npm --prefix studio run check`.

## Surfaces

`kopanda.koplugin/icons.lua`, `kopanda.koplugin/icons/quick_settings.svg` (new),
`kopanda.koplugin/launcher_entries.lua`, `kopanda.koplugin/schema.lua`, `studio/src/schema.json` and
`studio/src/catalog.json` (regenerated), `spec/goldens/swatch-colorsoft.{png,json}`,
`spec/goldens/swatch-paperwhite.{png,json}` (regenerated). Specs: `spec/unit/launcher_entries_spec.lua`,
`spec/unit/schema_spec.lua`, `spec/unit/entry_picker_spec.lua`, `spec/unit/icons_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `schema_spec.lua` (C7): the expected schema (`spec/unit/schema_spec.lua:121-127`) lists `quick_settings`
  among the kopanda targets; version 1 and the keys unchanged.
- `launcher_entries_spec.lua` (C7): "hold exactly the schema's kopanda and koreader targets" (`:143-147`)
  passes with both updated; a new case: `resolve{ kind = "kopanda", target = "quick_settings" }` is
  "Quick settings" with icon `quick_settings`, ready; `run` of it over a shown home shows the quick-settings
  sheet over the home (the top window a sheet named `quick_settings`) with `paint_ms` counted from the run.
- `entry_picker_spec.lua` (C7): the KoPanda-screen case (`spec/unit/entry_picker_spec.lua:169`) lists Quick settings with its icon, and picking it
  stores `{ kind = "kopanda", target = "quick_settings" }`.
- `icons_spec.lua` (C7): the registered-ids list (`:37-49`) gains `quick_settings`; the stroke, colour and
  render cases (`:88-130`) cover the new file.
- `studio_schema_spec.lua`, `studio_catalog_spec.lua` (C7) pass on the regenerated files; `swatch_spec.lua`
  and `swatch_golden_spec.lua` (C13) pass with the new cell; the studio's own tests pass, its icon picker
  counting by the catalog (`studio/test/ui/launcher-editor.test.tsx:226`).

## Edge cases

- The default launcher is full (`max_entries = 6`, `schema.lua:103`): placing the target means swapping one
  out or using a folder; nothing here changes the default.
- "Quick settings" is longer than the other labels: the tile's label is cut by `Typeset.line`'s `max_width`
  if it can't fit; the swatch and the launcher goldens are unaffected since the default six don't include it.
- If `bars/title-bar` lands first with its `plus` icon, both regenerate the swatch goldens and catalog; the
  second to merge regenerates again on its own tree.
