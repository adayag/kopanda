# The launcher editor with the device's entry operations, pickers and icons

## Approach

The studio's launcher management: a port of the device's entry operations held to them by a shared
corpus, the studio's own label and icon edits, the five add flows from the catalog, and the screen.
Starts after `studio/settings-form/form` and `studio/settings-form/catalog`, and after
`home/device-menus/launcher-manage` and `entry-picker` have merged; read `entries_edit.lua` and
`entry_picker.lua` as built first and record in the PR any rule, note or kind label that differs from
`device-menus/tasks/launcher-manage/task.md:12-26` and `tasks/entry-picker/task.md:10-57`. The built
plugin wins.

1. **`spec/fixtures/studio/entries_edit_cases.lua`**, shaped as the rows corpus: `move` within the top
   level and within a folder and past each end; `remove` of a top-level entry, a folder, a folder's entry
   and a folder's only entry (with `folder_removed`); `add` into a folder (also past six inside it), at a
   top level of five, at six with folders at 3 and 5 (into 3), at six with none ("More" in slot six);
   `count`; `kind_line` for each kind, "1 entry" and "3 entries ›".
2. **`spec/unit/studio_entries_edit_spec.lua`**: each case through `EntriesEdit`.
3. **`studio/src/core/entries-edit.ts`**: the port (positions `{ i }` or `{ f, i }` as on the device),
   plus `setLabel(entries, pos, label)` for kinds with a label (plugin, action, directory, folder,
   `settings.lua:84-91`) and `setIcon(entries, pos, icon)` for action and plugin entries, each refusing
   any other kind and an empty label after trimming. Pure, deep-copying.
4. **`studio/src/ui/launcher/LauncherEditor.tsx`** at `#/profiles/<id>/launcher`, replacing the form
   task's placeholder, as the feature's "The launcher editor":
   - the top level and a folder's list (local state), headers, rows with icon, label, kind line, arrows,
     remove; the folder confirm "Remove <label> and its N entries?";
   - **icons:** `catalog.icons` SVG text rendered as an `<img>` from a `data:image/svg+xml` URL (so no
     markup from the file runs in the page) on a light tile; screen entries take `catalog.screens`, folder
     and directory entries `folder` (`launcher_entries.lua:95-101`); an icon id not in the catalog shows
     its id;
   - **label edit:** a click on the label of an entry with one opens an inline field, Enter or blur
     saving through `setLabel`, Escape cancelling;
   - **icon edit:** a click on an action or plugin entry's icon opens the picker, every catalog icon with
     its label, the current one marked;
   - **add:** the five kinds as buttons, and the add flows: screen pickers from `schema` targets with
     `catalog.screens`; the directory path field (trailing `/` trimmed; the two notes); the action list by
     catalog section, one pick; the plugin list then the action list; then, for directory, action and
     plugin, the label field prefilled (last path part, or the action's title) and, for action and plugin,
     the icon picker on `action`; Add or Cancel. The entry goes through `add` (D3), into the open folder
     when one is open.
   - **applying:** every change is one `PUT` of `launcher.entries`, the editor taking the answer;
     a failed PUT shows "Couldn't save Launcher: <error>."; removing a folder's only entry returns to the
     top level.
5. A read-only or unreadable file opens the editor with every control disabled and its line.

**Open fact:** whether the device stores the label trimmed or as typed (`device-menus/tasks/entry-picker/task.md:54-57`
says only that a label empty after `util.trim` is refused). Read `entry_picker.lua` as built and do the
same in the studio's add flows and `setLabel`.

## Surfaces

- `spec/fixtures/studio/entries_edit_cases.lua`, `spec/unit/studio_entries_edit_spec.lua` (new)
- `studio/src/core/entries-edit.ts`, `studio/src/ui/launcher/*.tsx` (new), `App.tsx` (the route),
  `styles.css`
- `studio/test/core/entries-edit.test.ts`, `studio/test/ui/launcher-editor.test.tsx` (new)

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `spec/unit/studio_entries_edit_spec.lua` and `studio/test/core/entries-edit.test.ts` (C12): every case;
  the Vitest also checks each result with the studio's `launcher` validator, deep-compares each input to
  a copy taken first, and covers `setLabel` and `setIcon` (allowed kinds change only that field; other
  kinds and an empty label refused).
- `studio/test/ui/launcher-editor.test.tsx` (C13), `fetch` stubbed and recording requests, the real
  catalog:
  - the default six: "6 of 6 on the home screen", Library to Settings with their catalog labels and
    kind lines, Library's up and Settings' down disabled, each icon an `<img>` with a data URL;
  - a move, a remove, a label edit on a directory entry and an icon pick on an action entry each send one
    PUT with the expected list;
  - a folder's removal asks; Cancel sends nothing; OK sends one PUT;
  - a click on a folder's row shows "Folder · 3" over its label; an add there lands at its end; Done
    returns;
  - each kind adds: KoPanda screen Series `{ kind, target }`; Folder on disk `/mnt/us/books/` as
    `{ kind = "directory", path = "/mnt/us/books", label = "books" }`, `/` and `books` refused with their
    notes; Action History with label "History" and icon `action`; Plugin (the first catalog plugin) then
    History; at six with no folder the new entry makes "More" in slot six;
  - an empty label keeps the Add disabled; Cancel at each step sends nothing;
  - an entry `{ kind = "action", action = "simpleui_open", label = "SUI", icon = "action" }` (not in the
    catalog) lists "Action · simpleui_open" and moves.

## Edge cases

- The stored launcher is refused by the validator: the editor edits the default six it reads as; the first
  write replaces it.
- An empty launcher: "0 of 6 on the home screen", no rows, Add works.
- A label with quotes, backslashes or non-ASCII text round-trips (the writer's `%q`, covered by the
  settings-file fixture).
- SVG text from the catalog is the repo's own, but rendering through `<img>` keeps any script in an SVG
  inert regardless.
- Duplicates are allowed; adding the same screen twice is two entries.
