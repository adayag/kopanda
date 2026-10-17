# Series and authors goldens on the Colorsoft, the paint budget and the device check

## Approach

The emulator captures and the owner's checks. Starts after `routing`. Repo lines on `main` at `b05fe55`;
KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Feature section "Goldens and budget",
criteria C13, C14, C16, C17. Modelled on cover-grid's `goldens` task (task.md:8-41) and
`spec/emulator/nav_golden_spec.lua`.

1. **The capture library,** built by the spec in a scratch folder per run and passed as `library_dir` to
   `driver.capture` (`spec/emulator/driver.lua:335-383`): the three fixture EPUBs under their own names, plus
   copies of them under new names, enough for the feature's list (an under-way, a finished and a not-started
   series, a reading up-next book, a two-author book, at least three letters, one author whose books fill
   two rows of three across a series and outside one, and the series list over two pages so its pager shows a
   live arrow). `spec/fixtures/library/` is not changed (`spec/unit/fixtures_spec.lua` counts three).
2. **`spec/emulator/scenarios/2-scenario-series-authors.lua`,** named to sort after
   `2-scenario-home-fixture.lua` (userpatches run in name order, `frontend/userpatch.lua:60-61`):
   - inside a `PluginLoader.loadPlugins` wrapper, as the home fixture's
     (`spec/emulator/scenarios/2-scenario-home-fixture.lua:192-198`): `BookInfoManager:extractBookInfo` for
     every copy, then `setBookInfoProperties` (`plugins/coverbrowser.koplugin/bookinfomanager.lua:572-588`) with a
     public-domain title, author (newline-joined for the two-author book, as `books.lua:36-50` splits), series,
     `series_index` and `ignore_cover = "Y"` (`:47`), so its cover draws the scripted title's placeholder; the
     three originals keep their real covers;
   - sidecars for the `complete` and `reading` books (`summary.status`, `percent_finished`), as cover-grid's
     scenario writes its reading book;
   - one path-less source book in a series, `Books.add_source` (`books.lua:387-390`) with its `series` and
     `series_index` (`:141-151`), no cover;
   - on the first `KoPandaSettled` with `screen = "home"`, from the next tick, per `KOPANDA_SHELF_VIEW`:
     `showSeries` at the list, `showSeries` at one series, `showAuthors` at the list, `showAuthors` at one
     author, each shown directly at its view so the window's one settled signal is the shot; failures as a
     `KoPandaSettled{ screen = "scenario", error }`, as the file-browser scenario reports them;
   - beside the home fixture at `KOPANDA_HOME_FIXTURE=empty`, the look from `KOPANDA_HOME_LOOK`
     (`2-scenario-home-fixture.lua:17-19`, `:133`).
3. **`spec/emulator/series_authors_golden_spec.lua`:** the eight scenarios (four views × two looks, Colorsoft),
   `shot_screen` `series` or `authors`, `golden.check` at `max_fraction = 0.00002`, one shot, no settle cap,
   `paint_ms` ≤ 250 (`spec/emulator/home_capture_spec.lua:7-10`).
4. **Determinism first:** three plain captures of each view compared with `compare.lua`, empty masks, before the
   goldens are written. Any difference stops the task with the diff for the lead.
5. **Goldens:** `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/series_authors_golden_spec.lua`, each PNG
   opened and looked at before commit (`open <png>`); the owner's C16 on the committed PNGs.
6. **C14:** the whole `bin/check` proves every existing golden unchanged, the library's and the swatch's
   included.
7. **The device check (C17):** push the branch's plugin to the Kindle through the studio's device push and hand
   the owner C17's list, the attest command prefixed with the aggregate's worktree (AGENTS.md).

## Surfaces

- `spec/emulator/series_authors_golden_spec.lua` (new), `spec/emulator/scenarios/2-scenario-series-authors.lua`
  (new), `spec/goldens/series-*.png`, `spec/goldens/authors-*.png`, `spec/goldens/author-books-*.png` and their
  `.json` sidecars (new).

## Tests

- `series_authors_golden_spec.lua` (C13) failing before the goldens exist, passing after, and again on a second
  run.
- `bin/check` whole (C14, C15).

## Edge cases

- A copied EPUB has its own path, so its CoverBrowser row and sidecar are its own; `setBookInfoProperties`
  updates the row `extractBookInfo` wrote, keyed by directory and file name (`bookinfomanager.lua:68`), so the
  extraction comes first.
- The windows' own extraction request after the first paint finds every row present and asks nothing
  (`BookCovers.wants`, `book_covers.lua:93-108`), so no arrival repaints after the shot.
- `ignore_cover = "Y"` keeps a copy's real cover out (`books.lua:95`); without it a copy would show another
  book's cover under its scripted title.
- If a capture's `paint_ms` passes 250: report it and where the time goes (`Books.all`, the progress reads, the
  cover reads) to the lead before changing the budget or the code.
