# Launcher management: the list operations, the screen and its ways in

## Approach

The pure operations on `launcher.entries` (decision D3 included), the screen in the editor frame, and its
two ways in from the home: a hold on the launcher and "Hold to edit" on a folder's sheet. Repo lines on
`main` at `ca26783`; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Starts after
`home/device-menus/editor-frame` and `home/device-menus/entry-picker`. `sheet.lua`, `folder_sheet.lua` and
the hold step are `sheets`'; read them as built first, and record in the PR any line that differs from
`sheets/feature.md`.

1. **`kopanda.koplugin/entries_edit.lua`**, pure, on deep copies (`util.tableDeepCopy`). A position is
   `{ i }` at the top level or `{ f, i }` inside folder `f`. The entry is the schema's `launcher.entries`
   (`schema.lua:97-118`).
   - `move(entries, pos, delta)`: within its list; `nil` past an end.
   - `remove(entries, pos)`: a top-level entry, a folder with its entries, or a folder's entry; a
     folder's only entry removes the folder (`settings.lua:119-123`), and the result says so
     (`folder_removed = true`) so the screen can return to the top level.
   - `add(entries, entry, f)`: with `f`, at the end of folder `f`; else, under `max_entries`
     (`schema.lua:103`), at the end; else at the end of the first top-level folder; else
     `entries[max] = { kind = "folder", label = "More", entries = { entries[max], entry } }` (D3).
     A folder is never added (the picker can't make one).
   - `count(entries)`: the top level's length.
   - `kind_line(entry)`: "KoPanda · <target>", "KOReader · <target>", "Plugin · <plugin>", "Action ·
     <action>", "Folder on disk · <path>", "Folder · N entries ›" ("1 entry"); the kind names are the folder
     sheet's (`sheets/feature.md:391-393`).
2. **`kopanda.koplugin/launcher_manage.lua`**, `LauncherManage.open(opts)`, `opts.folder` (a top-level
   index to open that folder's list) and `opts.started`:
   - the screen's entries: a deep copy of `Settings.get("launcher.entries")`;
   - **top level:** `Editor.show{ screen = "launcher", aside = "<N> of <max> on the home screen", title =
     "Launcher", body, foot }` (LauncherManage:19-25);
   - **a folder's list:** aside "Folder · N", title the folder's label (FolderOpen:35-38);
   - **body:** a row per entry (LauncherManage:29-93): `LauncherEntries.resolve(entry)`'s icon and label
     (`launcher_entries.lua:82-107`), greyed when `unavailable`; the kind line (`editor_kind`), with the
     resolved suffix in place of the detail when `off` or `unavailable`; then up (`chevron_up`), down
     (`chevron_down`) and remove (`close`) controls, the ends' arrows greyed; then "Add an entry"
     (`editor_caption`), `EntryPicker.KINDS` as buttons two to a row (`kind_columns`), and on the top
     level the note "The seventh entry and beyond go into a folder." (LauncherManage:95-104);
   - **taps:** an arrow moves; remove removes, through `ConfirmBox`
     (`frontend/ui/widget/confirmbox.lua:48-51`, `ok_text = "Remove"`) for a folder: "Remove <label> and its
     N entries?"; a folder's row (outside its controls) opens its list; a kind button runs
     `EntryPicker.pick(kind, ctx, function(entry) apply(add(...)) end)`;
   - **room:** before a kind button runs, when the list already fills the body (the frame left a row
     out, or one more row wouldn't fit), the note "There's no room for another entry here." and no
     picker. The D3 overflow into a folder checks that folder's list the same way;
   - **applying** a result: `Settings.set("launcher.entries", new)`; on `false`, log, "Couldn't save the
     launcher.", nothing changes; on `true`, take `new`, `Home.shown:refresh()` when shown, then
     `Editor:refresh()`, or switch to the top level when a folder was removed;
   - **Done:** on a folder's list opened from the top level, back to the top level; otherwise close.
3. **The launcher's hold:** `widgets/launcher.lua` gains `Launcher.hold(ctx, ges, built)`, the optional
   contract `sheets` adds (`sheets/feature.md:89-91`), which calls
   `LauncherManage.open{ started = time.monotonic() }` and returns nothing, consuming the hold. The
   comment in `widgets.lua:1-15` already lists `hold` once `sheets` lands.
4. **"Hold to edit"** on the folder sheet (FolderOpen:40):
   - `sheet.lua`: a heading header's optional `hint`, drawn at the header's right in `sheet_aside`
     (`sheets/feature.md:112`, `:176-177`), and a spec's optional `hold`, a function: a `hold` inside the
     panel closes the sheet, then runs it. A spec without `hold` registers no hold, as now
     (`sheets/feature.md:227`).
   - `folder_sheet.lua`: `header.hint = "Hold to edit"` and
     `hold = function() LauncherManage.open{ folder = <its index>, started = … } end`. The folder sheet
     gets the folder entry, not its index; `LauncherEntries.run` passes the index too, or the sheet finds
     the first top-level folder equal to it. Which is cleaner depends on the built code; record it.
5. **`main.lua`** requires `entries_edit` and `launcher_manage`; `launcher_manage` is required at call
   time from `widgets/launcher.lua` and `folder_sheet.lua` if a load-time require cycles
   (`launcher_entries.lua:5` requires `home`).
6. **HOOKS.md:** `ConfirmBox` (`confirmbox.lua:48-51`, `:62`).

## Surfaces

`kopanda.koplugin/entries_edit.lua` (new), `launcher_manage.lua` (new), `widgets/launcher.lua`,
`sheet.lua`, `folder_sheet.lua`, `launcher_entries.lua` (only if the folder index is passed), `main.lua`,
`HOOKS.md`. Specs: `spec/unit/entries_edit_spec.lua` (new), `spec/unit/launcher_manage_spec.lua` (new),
`spec/unit/launcher_widget_spec.lua`, `spec/unit/folder_sheet_spec.lua`, `spec/unit/sheet_spec.lua`,
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `entries_edit_spec.lua` (C8), every result checked with `Settings.validators.launcher` and every input
  deep-compared to a copy taken first:
  - `move` within the top level and within a folder; `nil` past each end;
  - `remove` of a top-level entry, of a folder (its entries gone), of a folder's entry, and of a folder's
    only entry (the folder gone, `folder_removed`);
  - `add`: into a folder (at its end, past six inside it); top level of 5 (sixth at the end); top level of
    6 with a folder at 3 and another at 5 (into the one at 3, at its end); top level of 6 with no folder
    (slot 6 becomes `{ kind = "folder", label = "More", entries = { <old sixth>, <new> } }`);
  - `kind_line` for each kind, "1 entry" and "3 entries ›".
- `launcher_manage_spec.lua` (C9), over a shown home with a real settings file holding the board's six
  (Library, Series, Authors, History, a "Tools" folder of three, Settings):
  - **Header** "6 of 6 on the home screen"; rows with the resolved labels and kind lines; Library's up
    and Settings' down disabled; an entry for `kopanda_absent` greyed with "plugin missing".
  - **Move, remove:** each writes once, refreshes the home once (spied) and repaints once.
  - **Folder removal** shows a `ConfirmBox`; its OK writes, its Cancel leaves the file byte-identical.
  - **Folder list:** a tap on Tools' row shows "Folder · 3" over "Tools"; removing all three, one at a
    time, ends with the folder gone and the top level shown; Done returns to the top level.
  - **Adds** (with `EntryPicker.pick` stubbed to hand back an action entry): at 6 with Tools, the entry
    lands at Tools' end; after removing Tools, a seventh makes "More" in slot 6; inside a folder's list,
    into that folder.
  - **Room:** a folder filled until the body leaves a row out: a kind button shows the no-room note and
    `pick` isn't called.
  - **Refused write:** `Settings.set` stubbed false shows "Couldn't save the launcher." and the bytes
    don't change.
- `launcher_widget_spec.lua` (C9): `Launcher.hold` opens the editor named `launcher` and returns nil;
  through the home's hold step, a hold on the launcher slot does the same and opens no settings menu.
- `folder_sheet_spec.lua` (C9): the header carries "Hold to edit" at its right; a hold in the sheet closes
  it and opens the folder's list, headed with its label.
- `sheet_spec.lua` (C9): a spec with `hold` runs it once on a hold inside the panel, after closing; the
  existing case that a hold does nothing passes for a spec without one; `hint` is drawn right of the
  heading.
- `failsafe_spec.lua` (C15): `LauncherEntries.resolve` raising for every row still draws (it logs and
  reads as unavailable, `launcher_entries.lua:102-105`); `Settings.get` raising inside `open` leaves no
  editor.

## Edge cases

- A stored launcher the validator refuses reads as the default six (`settings.lua:285-298`); the first
  change stores a valid list from there.
- An empty launcher (allowed, `settings.lua:186-190`): "0 of 6 on the home screen", no rows, Add works.
- The folder opened from its sheet was removed meanwhile (studio push): `opts.folder` past the list or not
  a folder opens the top level.
- A hold on the launcher while a sheet is up can't happen: the sheet is on top and ignores it.
- Duplicate entries are allowed, as the validator allows them.
