# The folder sheet from a launcher folder tap

## Approach

A tap on a launcher folder entry opens a sheet of its entries in place of today's note. Paths into
KOReader are relative to `~/Projects/kodev/koreader/` at `e1fe1ac`; repo lines are on `main` at
`f2ef10b`. This task starts after `home/sheets/sheet`. It needs no hold routing: the folder opens on a tap,
which already reaches `LauncherEntries.run` through the launcher widget's `tap`
(`widgets/launcher.lua:267-280`; `launcher_entries.lua:151-155`).

1. **`kopanda.koplugin/folder_sheet.lua`**, `FolderSheet.open(entry, ctx, opts)`, with `entry` a `folder`
   entry (`launcher/feature.md` "Entries": `label`, `entries`, none of them a folder), passing `opts` on to
   `Sheet.show(spec, ctx, opts)`:
   - `name = "folder"`, `band = "folder"`, header `{ heading = entry.label, aside = "Folder · " .. n,
     aside_beside = true }` (FolderOpen:35-39);
   - one row per child, in order, from `local view = LauncherEntries.resolve(child)`
     (`launcher_entries.lua:82-107`):
     - `icon = view.icon` and `label = view.label`;
     - `detail`: `view.suffix` when the state is `off` or `unavailable`, else the kind's label from a
       local table, `{ kopanda = "KoPanda", koreader = "KOReader", plugin = "Plugin", action = "Action",
       directory = "Folder on disk" }`, plain;
     - `muted = view.state == "unavailable"`;
     - `run = function() LauncherEntries.run(child, ctx) end`.
2. **`LauncherEntries.run`'s folder branch** (`launcher_entries.lua:161-166`) becomes
   `require("folder_sheet").open(entry, ctx, { started = time.monotonic() })`, the tap's start that the
   sheet's `paint_ms` runs from (the feature's "The settled signal"), with `folder_sheet` required at call
   time: it requires `launcher_entries`. The header comment (`:1-3`) says the folder sheet reuses `resolve` and `run`, and the
   `run` comment (`:151-155`) drops "ctx is unused today; a folder sheet passes its own": the folder sheet
   passes the home's ctx through.
3. **`main.lua`** requires `folder_sheet` (`main.lua:22-46`).
4. **HOOKS.md** gains nothing from KOReader here. The entry for `launcher_entries` notes that a folder
   tap opens the sheet.

## Surfaces

`kopanda.koplugin/folder_sheet.lua` (new), `launcher_entries.lua`, `main.lua`, `HOOKS.md`. Specs:
`spec/unit/folder_sheet_spec.lua` (new), `spec/unit/launcher_entries_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `launcher_entries_spec.lua` (C8): the folder note case (`launcher_entries_spec.lua:368-374`, "Tools
  holds 3 entries; …" and "1 entry") becomes: running a folder entry shows a sheet named `folder` whose
  heading is the folder's label and aside "Folder · 3" (and "Folder · 1"), and shows no `InfoMessage`.
  Every other case passes unchanged.
- `folder_sheet_spec.lua` (C8), on a shown home over a real file manager, with a folder of five:
  - a `plugin` entry for a loaded plugin with a registered action;
  - an `action` entry;
  - a `directory` entry for a real temporary folder;
  - the `koreader` Wi‑Fi target;
  - a `plugin` entry naming `kopanda_absent`.

  The plugin and action are stubbed and registered as `launcher_entries_spec.lua` does, removed in
  `finally`. Cases:
  - **Rows:** five, in order, with the resolved labels and icons. The details read Plugin, Action, Folder
    on disk, then "off" (fake Wi‑Fi off, `spec/plugin_harness.lua:71`) with the `wifi_off` icon, then
    "plugin missing", muted, with the `plugin_missing` icon.
  - **Taps:**
    - the action row closes the sheet and sends its action's event once;
    - the directory row closes the sheet and the home and leaves `fm.file_chooser.path` at the folder's
      realpath;
    - the Wi‑Fi row calls `NetworkListener:onToggleWifi` once;
    - the missing plugin's row shows the note "Terminal: the kopanda_absent plugin isn't loaded."
      (`launcher_entries.lua:142-143`) over the home, with no sheet left.
  - **Through the real launcher:** with `launcher.entries` stored as the folder alone, a tap on its tile
    shows the folder sheet.
  - **A long folder:** a folder of 30 action entries shows the rows that fit on the Colorsoft, logs once,
    and raises nothing.
  - **Where `paint_ms` starts:** with `Sheet.show` and `LauncherEntries.resolve` spied, the folder tap
    passes `opts.started`, a number no later than the `time.monotonic()` recorded on the first child's
    `resolve`.
  - **Never writes:** the settings file is byte-identical after every case.
- `hooks_doc_spec.lua` (C14) passes: `launcher_entries.lua`'s new `ui/time` require is named in
  `HOOKS.md` already, and `folder_sheet` collides with no KOReader module path.

## Edge cases

- A folder entry's `entries` are validated non-empty (`launcher/feature.md` "The validator"), so a sheet
  never opens with no rows.
- A child that has gone since the home was built (a deleted directory) resolves when the sheet opens, and
  `run` re-checks at tap time (`launcher_entries.lua:167-175`), so it gives its note rather than a climb.
- The launcher widget resolved its own views at build. The sheet resolves the children afresh, so a
  plugin loaded since shows ready here.
- Diner's folder band is teal, with no board. At night, dark `on_accent` text on the night teal has low
  contrast (feature Notes); the owner decides at approval.
