# Library goldens on both profiles, the paint budget and the device check

## Approach

The emulator captures and the owner's checks. Starts after `routing` and `pickers`. Repo lines on `main` at
`4564444`. Feature section "Goldens and budget", criteria C14, C15, C17, C18.

1. **The capture library,** built by the spec in a scratch folder per run: copies of the three fixture EPUBs
   (`spec/fixtures/library/`) at its root and a sub-folder holding one more copy; passed as `library_dir`
   to `driver.capture` (`spec/emulator/driver.lua:335-383`). `spec/fixtures/library/` is not changed, so
   `fixtures_spec.lua` and the file-browser goldens are not touched.
2. **`spec/emulator/scenarios/2-scenario-library.lua`,** named to sort after `2-scenario-home-fixture.lua`
   when it runs with it (`frontend/userpatch.lua:60-61`, as `2-scenario-screens.lua` is named):
   - registers one path-less source book with `Books.add_source` (`books.lua:387-390`), a public-domain
     title and author, no cover;
   - writes a reading position (a sidecar with `percent_finished` and `summary.status = "reading"`) for one
     root book, so its strip shows;
   - extracts every local book's cover synchronously at the grid's cover box with
     `BookInfoManager:extractBookInfo`, as the home fixture extracts the featured cover
     (`2-scenario-home-fixture.lua:183-216`);
   - on the first `KoPandaSettled` with `screen = "home"`, from the next tick, runs the `library` target, then
     per `KOPANDA_LIBRARY_STEP`: nothing (the root), enters the sub-folder (`library:go`), or opens the sort
     picker; failures reported as a `KoPandaSettled{ screen = "scenario", error }` as the file-browser
     scenario does.
   - It runs beside the home fixture at `KOPANDA_HOME_FIXTURE=empty`: the look comes only from the fixture
     (`KOPANDA_HOME_LOOK`, `2-scenario-home-fixture.lua:17-19`, `:103-106`), and `empty` sets up no featured
     book from the fixture library (it returns at `:133`).
   - `Books.add_source` runs after the plugins load, inside a `PluginLoader.loadPlugins` wrapper as the
     fixture wraps it (`2-scenario-home-fixture.lua:192-198`).
3. **`spec/emulator/library_golden_spec.lua`,** modelled on `nav_golden_spec.lua:1-79`: the eight scenarios
   (root on both profiles in both looks, folder and sort on the Colorsoft in both looks), `shot_screen`
   `library` or `sheet`, `golden.check` at `max_fraction = 0.00002`, one shot, no settle cap, `paint_ms` ≤ 250
   for the library captures.
4. **Determinism first:** three plain captures per profile compared with `compare.lua`, empty masks, before
   the goldens are written. Any difference stops the task with the diff for the lead.
5. **Goldens:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/library_golden_spec.lua`, each PNG opened
   and looked at before commit; the owner's C17 on the committed PNGs.
6. **C15:** the full `bin/check` run proves the home, night, sheet, screens, file-browser and probe goldens
   unchanged.
7. **The device check (C18):** push the branch's plugin to the Kindle through the studio's device push and
   hand the owner C18's list, with the attest command prefixed by the aggregate's worktree (AGENTS.md).

## Surfaces

- `spec/emulator/library_golden_spec.lua` (new), `spec/emulator/scenarios/2-scenario-library.lua` (new),
  `spec/goldens/library-*.png` and `.json` (new).

## Tests

- `library_golden_spec.lua` (C14) failing before the goldens exist, passing after, and again on a second run.
- `bin/check` whole (C15, C16).

## Edge cases

- A copied EPUB has a different path, so its CoverBrowser row and sidecar are its own; the scenario extracts
  covers for the copies, not the fixture files.
- The sub-folder's book is a copy of a root book; its id differs (`"file:" .. realpath`), so both list.
- The driver disables the other shells (`spec/emulator/driver.lua:18`); nothing else draws over the library.
- If the 250 ms budget fails on the emulator: report the measured `paint_ms` and where the time goes (listing,
  progress reads, cover reads) to the lead before changing the budget or the code.
