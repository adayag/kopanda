# A placeholder's library golden on the Colorsoft and the owner's device check

## Approach

The emulator capture and the owner's checks. It starts after `placeholders` and `download-row`, so the
device push carries the whole feature. Repo lines are `main` at `1e25e44`; KOReader is relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`; cwngsync is relative to `cwngsync.koplugin/` at `df90d5e`. Covers
feature section "Goldens and budget"; decision D20; criteria C7, C8, C10, C11 and C12. Modelled on
`spec/emulator/library_hold_golden_spec.lua` and `spec/emulator/library_golden_spec.lua`.

1. **The capture library** is cover-grid's (`spec/emulator/capture_library.lua:12-13`, `:27-41`):
   - the three fixture books at its root and `Gothic/frankenstein.epub`;
   - the library scenario's position on `the-time-machine.epub` and its path-less source book
     (`spec/emulator/scenarios/2-scenario-library.lua:6-21`, `:117-125`).

   Its root shows a folder tile, three downloaded books, the path-less book and an empty sixth cell.
   `spec/fixtures/library/` is not changed.
2. **`spec/emulator/scenarios/2-scenario-cwngsync.lua`** (new; the name may change to fit the userpatch sort,
   `frontend/userpatch.lua:60-61`). It registers a stub module on the file manager as `cwngsync`, the way
   `fm:registerModule` stores plugins (`frontend/apps/filemanager/filemanager.lua:379-384`, `:424`). The stub has:
   - `isConfigured()` returning true;
   - `getLibraryState()` returning `{ version = 1, books = { ["1"] = { kind = "placeholder", path = <root>/a-christmas-carol.epub, size = <its size> } } }`
     (`cwng_library.lua:17-20`), the path as the library scenario stores the root, realpath'd
     (`2-scenario-library.lua:8-10`), and the size read with `lfs.attributes` at patch time;
   - `openLibraryPlaceholder`, which only logs.

   It reads `KOPANDA_LIBRARY_DIR`. Open fact: where to register so the stub is on `FileManager.instance`
   before the library's first listing. Candidates:
   - (a) wrapping `FileManager.init` to register after the original returns;
   - (b) registering from the first home's `KoPandaSettled`, before the library scenario's handler runs the
     library target (`2-scenario-library.lua:252-`).

   Tell them apart by the order the event hook runs handlers and by the log. Prefer (a) if the instance it
   registers on is the one the library reads. A failure before the UI runs exits with status 4, as the other
   scenarios do.
3. **`spec/emulator/library_placeholder_golden_spec.lua`** (new). One scenario, `library-placeholder-diner` on
   `colorsoft`:
   - patches: the home fixture at `KOPANDA_HOME_FIXTURE=empty`, the library scenario at
     `KOPANDA_LIBRARY_STEP=root`, then the stub patch;
   - `KOPANDA_HOME_LOOK` empty and `TZ = "America/Chicago"`, as `library_hold_golden_spec.lua:62-69` passes them;
   - shot on the library's own settled signal, the sidecar's `screen` `library`;
   - `paint_budget.check`, one `KOPANDA_SHOT: saved`, no settle cap;
   - `golden.assert_golden` at the library goldens' threshold.

   If it reads better as a row of `library_golden_spec.lua`'s list with a per-row patch, say so to the lead
   first: C7 binds the new file.
4. **Determinism first:** take three plain captures and compare them with `compare.lua`, empty masks, before
   writing the golden. Any difference stops the task with the diff for the lead.
5. **The golden:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/library_placeholder_golden_spec.lua`.
   Open the PNG with `open <png>` and look at it beside `library-diner-colorsoft.png` before commit:
   `a-christmas-carol`'s tile now has the badge and chip the path-less book's has. The owner's C10 is on the
   committed PNG.
6. **The emulator check (C11):** run the stub scenario in both looks, by day and with night toggled, hold
   `a-christmas-carol`, and hand the owner the sheet. Neither look's sheet is a golden (D20).
7. **C8:** the whole `bin/check` proves every other golden unchanged.
8. **The device check (C12):** push the branch's plugin to the Kindle through the studio's device push, then
   hand the owner C12's list and the attest command prefixed with `cd <the aggregate's worktree> &&`
   (AGENTS.md). The owner's cwngsync is whatever version the Kindle runs. If it isn't `df90d5e`'s v4.1.46
   (`cwngsync.koplugin/main.lua:46`), note the version in the evidence.

## Surfaces

- `spec/emulator/library_placeholder_golden_spec.lua` (new), `spec/emulator/scenarios/2-scenario-cwngsync.lua`
  (new), `spec/goldens/library-placeholder-diner-colorsoft.png` and its `.json` sidecar (new).
- `kopanda.koplugin/HOOKS.md`'s "Capture harness" section, if the stub's hook point is a KOReader surface it
  doesn't name yet.

## Tests

- `library_placeholder_golden_spec.lua` (C7) fails before the golden exists and passes after, and again on a
  second run. Scope check: confirm `bin/check spec/emulator/library_placeholder_golden_spec.lua` runs that file
  alone.
- `library_golden_spec.lua` and `library_hold_golden_spec.lua` pass unchanged (C8): their captures load no stub.
- The whole `bin/check` (C8, C9).

## Edge cases

- **The stub's path must be the record's.** The library lists the realpath'd root it was given, so the stub
  takes its path from the same `KOPANDA_LIBRARY_DIR` after the same realpath. A mismatch shows as no badge,
  and the eyeball in step 5 catches it. Also make the scenario log the index `CloudBooks.index()` gives.
- **Covers.** The library scenario extracts every cover at the grid's box before the library shows
  (`2-scenario-library.lua:14-19`). The placeholder's cover is the fixture's own, so the tile differs from
  `library-diner-colorsoft` only by the badge and chip.
- **The paint budget.** The stub's state holds one book, so the index costs nothing measurable. If `paint_ms`
  passes the budget, report where the time goes to the lead before changing anything.
- **The Kindle's first open.** C12 asks the owner whether the library opens quickly enough. The first listing
  may be the first to read cwngsync's state files (`cwng_library_runtime.lua:104-118`). If it is slow, take it
  to the lead.
