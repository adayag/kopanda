# Edit layout: the row operations and the screen

## Approach

The pure operations on `layout.rows`, the fit count they're checked with, and the screen that applies
them, opened from the home sheet's Edit layout row. Repo lines are on `main` at `ca26783`; KOReader paths
relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Starts after `home/device-menus/editor-frame`.
`home_sheet.lua` is `sheets`'; read it as built before changing its row.

1. **`Layout.overflow(rows, ctx)`** in `layout.lua`: `#arrange(rows, ctx, place).dropped`, the same
   unlogged placement `Layout.fits` uses (`layout.lua:266-270`, `place` at `:45-102`). `Layout.fits` keeps
   its body; its comment names `overflow` as what the edit-layout screen asks.
2. **`kopanda.koplugin/rows_edit.lua`**, pure, requiring only `schema` and KOReader's `util`. The entry is
   the schema's `layout.rows` (`schema.lua:32-49`). Each operation deep-copies its input
   (`util.tableDeepCopy`, `frontend/util.lua:184`) and returns new rows, or `nil` and a note:
   - `move(rows, i, delta)`; `nil` past an end.
   - `add_row(rows, widget)`; `add_column(rows, i, widget)`, "A row holds at most three columns." at
     `max_columns` (`schema.lua:39`).
   - `change_widget(rows, i, j, widget)`; `set_share(rows, i, j, share)`, 1 to 3 (`settings.lua:46`).
   - `remove_column(rows, i, j)` on a row of two or more; `remove_row(rows, i)`, "The home needs at least
     one row." for the only row (`settings.lua:151-154`).
   - `reset()`: a copy of the schema default (`schema.lua:40-46`).
   - `unused(rows)`: `entry.widgets` (`schema.lua:38`) not named in `rows`, in that order.
   - `label(id)`: Date, Clock, Weather, Quote, Reading stats, Featured book, Launcher.
   - `share_text(row, j)`: "full" for a one-column row, else `share/total` reduced by their gcd.
   - `caption(rows, i, selected)`: "Row N · one column" / "two columns" / "three columns", then
     " · selected".

   A widget given to `add_row`, `add_column` or `change_widget` that is already on the home is refused
   ("Each widget can be on the home once.", `settings.lua:43`); the pickers never offer one, so this is a
   guard.
3. **`kopanda.koplugin/edit_layout.lua`**, `EditLayout.open(opts)`, `opts.started` and `opts.selected` (a
   row index to start selected, for the goldens' scenario; none from any other caller):
   - reads `Settings.get("layout.rows")` and keeps a deep copy as the screen's rows;
   - `Editor.show{ screen = "edit_layout", aside = "Home", title = "Edit layout", body, foot }`;
   - **body:** a card per row (EditLayout:29-98): up and down arrows (`chevron_up`, `chevron_down`),
     greyed at the ends; the caption (`editor_caption`); a box per column with `label` (`editor_box`)
     and `share_text` (`editor_share`), on paper in a selected card (EditLayout:51). A selected card
     draws `selected_outline_color` and `selected_fill_color`, its selected column's box with an outline one board px heavier than the others,
     and its buttons below the boxes (EditLayout:53-57), wrapping to a second line when they don't fit:
     Add column, Change widget, then Width and Remove column on rows of two or more, then Remove row.
     Add column is greyed with three columns or no unused widget.
   - **foot** (EditLayout:101-104): Add row, greyed with no unused widget; Reset to the look's default,
     in `muted` with no border.
   - **taps:** a card selects its row (first column); a box in the selected card selects that column;
     an arrow moves; a button runs its operation, through a picker where it needs a choice:
     - Add column, Add row: a sheet "Add a widget" of `unused(rows)`, each row labelled;
     - Change widget: a sheet "Change widget" of the selected column's widget, ticked, then
       `unused(rows)`;
     - Width: a sheet "Width" of "1", "2" and "3", the current share ticked.

     Sheets via `Sheet.show(spec, ctx, opts)` with `name = "picker"`, `band = "home"`
     (`sheets/feature.md:108-117`), the editor's ctx.
   - **applying** a result: `nil` → its note (`InfoMessage`, no timeout). Otherwise, when
     `Layout.overflow(new, ctx) > Layout.overflow(current, ctx)`, the note "That won't fit on the home."
     Otherwise `Settings.set("layout.rows", new)`: on `false`, log, the note "Couldn't save the layout.",
     nothing changes; on `true`, the screen takes `new`, `Home.shown:refresh()` when a home is shown
     (`home.lua:60-72`), then `Editor:refresh()`. The selection follows a moved row and clears on a
     removed one.
4. **The home sheet's Edit layout row** (`sheets/feature.md:261`; `hold-and-home-sheet/task.md:58-59`): its
   `run` becomes `EditLayout.open{ started = time.monotonic() }` in place of the note. `edit_layout` is
   required at call time if `home_sheet` can't require it at load without a cycle (`edit_layout` needs
   `home` for `Home.shown`, and `home` reaches `home_gestures`, where `sheets` adds the hold step that
   opens the home sheet; check with the built code).
5. **`main.lua`** requires `rows_edit` and `edit_layout` (`main.lua:22-48`).
6. **HOOKS.md:** `util.tableDeepCopy` (`frontend/util.lua:184`) and `InfoMessage` notes from the screen.

## Surfaces

`kopanda.koplugin/layout.lua`, `rows_edit.lua` (new), `edit_layout.lua` (new), `home_sheet.lua`,
`main.lua`, `HOOKS.md`. Specs: `spec/unit/layout_spec.lua`, `spec/unit/rows_edit_spec.lua` (new),
`spec/unit/edit_layout_spec.lua` (new), `spec/unit/home_sheet_spec.lua`, `spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `layout_spec.lua` (C6): `Layout.overflow` is 0 for the schema default on the Colorsoft size the spec
  already uses, and 1 for a layout one row too tall (build it from the existing too-tall case); it equals
  `fits and 0` exactly; it logs nothing (`logger.warn` spied).
- `rows_edit_spec.lua` (C6): one case per operation, each asserting the result and that
  `Settings.validators.rows(entry, result)` is true and the input is unchanged (deep-compared to a copy
  taken first); every refusal returns `nil` and its note; `unused` on the default is `{}` and on a
  layout without stats is `{ "stats" }`; `share_text` gives "full", "1/2" for 1+1, "1/3" and "2/3" for
  1+2, "1/2" for 2+2; `caption` gives the three forms and " · selected".
- `edit_layout_spec.lua` (C7), over a shown home in the harness with a real settings file:
  - **Cards:** five for the default, captions "Row 1 · two columns" and "Row 2 · one column", boxes
    "Date"/"1/2", "Featured book"/"full"; row 1's up arrow and row 5's down arrow are disabled.
  - **Select:** a tap on card 2 shows its buttons; on row 1, Width and Remove column too.
  - **Each change** (move row 2 up, add column on row 3 by picking from the sheet, change widget, width
    2, remove column, remove row, add row, reset): the settings file holds the new rows; `Home.refresh`
    (spied) ran once; `setDirty` on the editor ran once with `"ui"`.
  - **Refusals:** with a layout whose next row can't fit (stub `Layout.overflow` to grow), adding a row
    shows "That won't fit on the home." and the file is byte-identical; removing the only row of a
    one-row layout shows its note, same bytes; with `Settings.set` stubbed to return false, a move shows
    "Couldn't save the layout.", same bytes.
  - **Pickers:** Add row on a home with every widget is greyed and opens nothing; Change widget's sheet
    lists the column's widget ticked, then the unused ones.
  - **Done** closes the editor; the home is on top.
- `home_sheet_spec.lua` (C7): the Edit layout case changes from the note to: the editor named
  `edit_layout` is shown, with no `InfoMessage`.
- `failsafe_spec.lua` (C15): `Settings.get` raising inside `EditLayout.open` is logged and leaves no
  editor.

## Edge cases

- A stored layout the validator refuses reads as the default (`settings.lua:285-298`); the screen then
  edits the default, and the first change stores a valid list.
- A layout already too tall (the studio wrote it): moves and removals that don't add to the overflow
  pass, so it can be fixed on the device.
- A widget id the schema lists but `widgets.lua` has no module for can't occur today (`widgets.lua:20-28`
  matches `schema.lua:38`); `label` falls back to the id.
- The selected row removed: no selection, no buttons.
- `Home.shown` nil (opened over the reader): no refresh; the home rebuilds from the settings on its next
  show.
