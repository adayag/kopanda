# Sort and status sheets over the library, and sheets closing the screen beneath

## Approach

The two pickers' sheets, and the sheet component's additions they need. Starts after `screen` and `routing`. Repo lines on
`main` at `4564444`; board `SortC.dc.html`. Feature section "The pickers", decisions D8, D9, D11.

1. **`sheet.lua` additions,** each optional so every existing sheet builds as it does
   (`sheet.lua:1-11` spec shape):
   - `header.aside_above`: the aside set above the heading, stacked, in the `sheet_aside` part
     (SortC:40-41); today the aside's x is set at `sheet.lua:180-184` and it shares the heading's baseline
     (`:198-209`).
   - `header.label`: a right-hand small-caps label ("Library", SortC:43) in a new `sheet_label` part. The
     existing `header.hint` (`sheet.lua:6`, drawn at `:190-197` in `sheet_aside`) is left as it is, since
     the folder sheet's "Hold to edit" uses it (`folder_sheet.lua:55`).
   - A row's `sublabel`: a second line under the label (SortC:46-48) in a new `sheet_sublabel` part.
   - A row's `selected`: the row filled with a new `sheet.selected_fill_color` (Diner `teal`, SortC:45;
     Editorial false) and `check` at the row's right.
   - A sheet whose rows have no icons sets their labels flush, without the icon's indent
     (`sheet.lua:242`, `:307`).
   - New tokens in both looks with identical paths. Where SortC differs from today's sheet tokens (heading
     28 against `sheet_heading` 24, row padding 16 against 15), the existing tokens stay, so existing sheets
     don't move; the sort sheet uses them.
2. **The failure path:** `close_all` (`sheet.lua:446-460`) closes the screen the sheet was shown over,
   passed in `opts.beneath` (a table with a `close` function) by `Sheet.show` (`:504-521`), defaulting to the
   home so every existing caller behaves as today.
3. **`kopanda.koplugin/library_pickers.lua` (`LibraryPickers`):** `sort(library)` and `status(library)`
   build the two specs from the feature's rows and the folder's current choice, and show them with
   `beneath = Library`. A row's `run`: `LibraryOrder.choose(dir, …)`, close the sheet, `library:go(dir, 1)`.
   It sets `Library.on_picker` (`screen` step 4) to show the sheet of that kind.
4. `main.lua` requires `library_pickers`.

## Surfaces

- `kopanda.koplugin/sheet.lua`, `library_pickers.lua` (new), `library.lua`, `looks/diner.lua`,
  `looks/editorial.lua`, `main.lua`.
- `spec/unit/sheet_spec.lua`, `spec/unit/library_pickers_spec.lua` (new), `spec/unit/looks_spec.lua`.

## Tests

Written first, each run failing before the code:

- `sheet_spec.lua` (C10): each addition builds and paints in both looks; a sheet with none of them has the
  same row and header boxes as before (compare the boxes of an existing sheet spec before and after); a
  failing sheet shown with `beneath` closes that and not the home; without it closes the home as today.
- `library_pickers_spec.lua` (C10): a tap on each picker in the library's header opens its sheet; the sort
  sheet's four rows with their sublabels and the current one
  selected; the status sheet's three; a tap on Title stores it for this folder alone and shows page 1 under
  the new order; the sheet's `KoPandaSettled{ screen = "sheet", name }` (`sheet.lua:487-502`).
- `sheet_golden_spec.lua` passes unchanged (C15): the existing sheets do not move.
- `looks_spec.lua` (C3) over the new sheet tokens and parts.

## Edge cases

- This task runs after `routing` (a recorded edge): both edit `library.lua` and `main.lua`.
- A tap on the row already selected: stores nothing new, still closes and shows page 1.
- A sheet over the library when the file manager closes (a book opened from elsewhere is not possible here,
  but a quit is): `Sheet.close` runs from the library's `onCloseWidget` as the home's does
  (`home.lua:322-339`).
- Editorial's sort sheet is not drawn on any board; it uses Editorial's sheet tokens with no selected fill,
  shown to the owner in `goldens`' sort-sheet golden.
