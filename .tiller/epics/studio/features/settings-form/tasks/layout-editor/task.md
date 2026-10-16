# The layout editor with the device's row operations and fit refusal

## Approach

The studio's edit layout: a port of the device's row operations held to them by a shared corpus, and the
screen that applies them through the fit check. Starts after `studio/settings-form/form` and
`studio/settings-form/layout-fit`, and after `home/device-menus/edit-layout` has merged; read
`rows_edit.lua` as built first and record in the PR any operation, note or label that differs from
`device-menus/tasks/edit-layout/task.md:13-31`. The built plugin wins.

1. **`spec/fixtures/studio/rows_edit_cases.lua`**: `return { { op = "<name>", args = { … }, result =
   <value> }, { op = "<name>", args = { … }, refused = "<note>" or true }, … }`, `refused = true` for an
   operation that refuses with no note (`move` past an end). Cases: `move` up, down and past each end;
   `add_row`; `add_column` on rows of one and two and refused at three; `change_widget`; `set_share` to 1,
   2, 3; `remove_column` from rows of two and three; `remove_row` from five and refused for the only row;
   a widget already on the home given to `add_row`, `add_column` and `change_widget` (refused with its
   note); `reset`; `unused` on the default (`{}`) and without `stats`; `label` for every widget id and an
   unknown one (its id); `share_text` for "full", 1+1, 1+2 (both columns), 2+2, 1+1+1; `caption` for one,
   two and three columns, selected and not.
2. **`spec/unit/studio_rows_edit_spec.lua`**: each case through `RowsEdit[op](unpack(args))`, comparing
   with `assert.same`, a refusal as `nil` plus the note.
3. **`studio/src/core/rows-edit.ts`**: the port, pure, each operation deep-copying, returning
   `{ rows }` or `{ refused: note | null }`; the schema entry from `studio/src/schema.ts`.
4. **`studio/src/ui/layout/LayoutEditor.tsx`** at `#/profiles/<id>/layout`, replacing the form task's
   placeholder, as the feature's "The layout editor": "Home" over "Edit layout" and Done; cards, arrows,
   selection (row and column, local state), the selected card's buttons, the foot. Pickers are small
   inline menus listing `unused(rows)` with labels (Change widget: the column's own widget first,
   marked); Width lists 1, 2, 3, the share marked.
5. **Applying a change:** the operation's result; a refusal shows its note (if any) and stops. Otherwise
   `POST /api/profiles/:id/layout-fit` with the new rows, "Checking fit…" shown and every control
   disabled until it answers; `checked` and `proposed > current` → "That won't fit on the home.";
   otherwise one `PUT` of `layout.rows`, the editor taking the answer's rows; unchecked also shows "Fit not
   checked: <reason>" under the header, cleared by the next checked answer. A failed PUT shows "Couldn't
   save Layout: <error>." The selection follows a moved row and clears on a removed one.
6. A read-only or unreadable file opens the editor with every control disabled and its line.

## Surfaces

- `spec/fixtures/studio/rows_edit_cases.lua`, `spec/unit/studio_rows_edit_spec.lua` (new)
- `studio/src/core/rows-edit.ts`, `studio/src/ui/layout/LayoutEditor.tsx` (new), `App.tsx` (the route),
  `studio/src/ui/api.ts` (`checkFit`), `styles.css`
- `studio/test/core/rows-edit.test.ts`, `studio/test/ui/layout-editor.test.tsx` (new)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `spec/unit/studio_rows_edit_spec.lua` and `studio/test/core/rows-edit.test.ts` (C9): every case; the
  Vitest also deep-compares each input to a copy taken first and checks every `rows` result with the
  studio's `rows` validator.
- `studio/test/ui/layout-editor.test.tsx` (C10), `fetch` stubbed and recording requests:
  - the default layout gives five cards, "Row 1 · two columns" with Date 1/2 and Clock 1/2; row 1's up and
    row 5's down disabled;
  - selecting row 1 shows Add column, Change widget, Width, Remove column, Remove row; row 2 lacks Width and
    Remove column;
  - each of move, add column, change widget, width 2, remove column, remove row, add row and reset sends
    one fit request with the expected rows, then one PUT of `layout.rows`; "Checking fit…" shows while the
    fit request is pending and the buttons are disabled;
  - a fit answer `{ checked: true, current: 0, proposed: 1 }` shows "That won't fit on the home." and
    sends no PUT; `{ checked: true, current: 2, proposed: 1 }` (a layout already too tall shrinking)
    writes;
  - `{ checked: false, reason: "no emulator: …" }` writes and shows "Fit not checked" with the reason; a
    following checked answer removes it;
  - Add row with every widget on the home is disabled; removing the only row of a one-row layout shows
    "The home needs at least one row." with no fit request and no PUT;
  - Done returns to the form.

## Edge cases

- The stored layout is refused by the validator: the editor edits the default it reads as, and the first
  write replaces the stored value, as on the device (`device-menus/tasks/edit-layout/task.md:108-109`).
- Reset when the layout already is the default still checks fit and writes, as the device does.
- A fit answer arriving after Done: ignored; nothing is written.
- Moves change height too (row 1 carries the header, `layout.lua:176-206`), so they are checked like any
  change.
