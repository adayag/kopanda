# Hold-sheet goldens on the Colorsoft, the paint budget and the device check

## Approach

The emulator captures and the owner's checks. Starts after `book-actions` and `space-sheet` (and so after
every other task). Repo lines on `main` at `5d8a955`; KOReader relative to `~/Projects/kodev/koreader/` at
`e1fe1ac`; cover-grid's capture scenario and spec read as merged. Feature section "Goldens and budget",
criteria C12, C14, C16, C17. Modelled on `spec/emulator/sheet_golden_spec.lua` and
`spec/emulator/scenarios/2-scenario-sheet-hold.lua`.

1. **The capture library** is cover-grid's (goldens task.md:8-11, :12-29): the three fixture EPUBs copied to
   a scratch root with a sub-folder holding one more copy, one path-less source book, a reading position on
   one root book, every cover extracted before the library shows. Its root then shows a folder tile, three
   downloaded books, the not-downloaded book and an empty sixth cell. Reuse its builder and scenario rather
   than a second copy; if the builder is local to `library_golden_spec.lua`, move it to a shared helper
   under `spec/emulator/` and say so in the PR. `spec/fixtures/library/` is not changed.
2. **A history entry for the held book,** so the meta reads both parts ("40% · opened 3 days ago",
   HoldBookC:40): the scenario writes one `ReadHistory` entry for the reading book at three calendar days
   before the home fixture's frozen now (2026-10-13 08:42 in Chicago; `os.time` frozen for every fixture,
   `spec/emulator/scenarios/2-scenario-home-fixture.lua:6-8`, `:78-81`), as the fixture writes its own
   history file (`:151-158`).
3. **`spec/emulator/scenarios/2-scenario-library_hold.lua`,** named to run after cover-grid's
   `2-scenario-library.lua` under the userpatch sort (`frontend/userpatch.lua:60-61`; `_` sorts after `.`;
   confirm the order in the log): on the first `KoPandaSettled` with `screen = "library"`, from the next tick,
   sends one `Event:new("Gesture", { ges = "hold", pos, time = time.now() })`, as the sheet-hold scenario
   sends its own (`2-scenario-sheet-hold.lua:75-97`), at the centre of the tile `KOPANDA_LIBRARY_HOLD` names:
   `book` (the reading book), `remote` (the path-less book), `folder` (the folder tile) or `empty` (the sixth
   cell). Open fact: where the merged `Library` keeps its tiles' rects; read it, and check the point with
   `Library.hit` before sending, reporting a mismatch as `KoPandaSettled{ screen = "scenario", error }`. A
   point inside a Gestures corner is an error too, as the sheet-hold scenario checks (`:45-54`, `:78-81`).
4. **`spec/emulator/library_hold_golden_spec.lua`:** the eight scenarios (book, remote, folder and empty × two
   looks, Colorsoft), with the home fixture at `KOPANDA_HOME_FIXTURE=empty`, cover-grid's library scenario at
   its root step, and this scenario; `shot_screen = "sheet"`; the sidecar's `name` `book`, `book`,
   `library_folder`, `library_empty`; `golden.assert_golden` at the sheet goldens' threshold; one shot, no
   settle cap; `paint_ms` at most 250 (`sheet_golden_spec.lua:15-18`).
5. **Determinism first:** three plain captures of each scenario compared with `compare.lua`, empty masks,
   before the goldens are written. Any difference stops the task with the diff for the lead.
6. **Goldens:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/library_hold_golden_spec.lua`, each PNG opened
   and looked at against its board before commit (`open <png>`); the owner's C16 on the committed PNGs.
7. **C14:** the whole `bin/check` proves every other golden unchanged, the home's book sheet's, the library's
   and the shelf screens' included.
8. **The device check (C17):** push the branch's plugin to the Kindle through the studio's device push and
   hand the owner C17's list, the attest command prefixed with the aggregate's worktree (AGENTS.md). The
   owner deletes only a copy made for the check.

## Surfaces

- `spec/emulator/library_hold_golden_spec.lua` (new), `spec/emulator/scenarios/2-scenario-library_hold.lua`
  (new), a shared capture-library helper under `spec/emulator/` if step 1 moves one,
  `spec/goldens/library-hold-*.png` and their `.json` sidecars (new).

## Tests

- `library_hold_golden_spec.lua` (C12) failing before the goldens exist, passing after, and again on a second
  run. Scope check: confirm `bin/check spec/emulator/library_hold_golden_spec.lua` runs that file alone.
- `library_golden_spec.lua` passes unchanged after any helper move (C14).
- `bin/check` whole (C14, C15).

## Edge cases

- The library's own cover request after its first paint finds every row present (cover-grid's scenario
  extracts them, goldens task.md:18-20) and asks nothing (`BookCovers.wants`, `book_covers.lua:93-108`), so no
  arrival repaints the grid under the sheet after the shot.
- The sheet's header cover is read from CoverBrowser's cache at the sheet's 60×90 (`BookCovers.read`,
  `book_covers.lua:82`); a cover extracted at the grid's larger box serves it.
- The path-less book's sheet reads "Not downloaded" and draws its greyed rows; its cover is the source's or
  the typographic placeholder (`featured_cover.lua:203-211`), which the fixture source makes deterministic by
  giving no cover.
- If a capture's `paint_ms` passes 250: report it and where the time goes (the progress read, the history
  walk, the cover read, the folder's counts) to the lead before changing the budget or the code.
