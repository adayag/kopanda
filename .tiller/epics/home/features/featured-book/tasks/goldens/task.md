# Home goldens with the featured row and the paint budgets

## Approach

1. **Open fact first: how does the capture get the fixture book's cover cached deterministically?**
   The widget only asks for extraction after the settled signal, and the capture saves its PNG on that
   signal (`spec/emulator/driver.lua` on `main`), so an empty cover cache would capture the placeholder.
   Candidates:
   - **(a) Synchronous extraction in the fixture userpatch.** The patch runs before plugins load
     (`frontend/userpatch.lua:13`, `reader.lua:190`), when `bookinfomanager` is not yet on `package.path`
     (`frontend/pluginloader.lua:283-287`). It would wrap a call that runs after plugins load and before
     KoPanda's show. Then it would call `require("bookinfomanager"):extractBookInfo(file, specs)`
     (`plugins/coverbrowser.koplugin/bookinfomanager.lua:422-570`), which is synchronous in-process.
     - Risk: the function is written for a subprocess. In the calling process it re-inits crengine's
       cache to CoverBrowser's temporary directory (`:423-439`), which then holds for the rest of the
       capture.
   - **(b) A pre-pass capture.** A first emulator run on the same scratch `KO_HOME` lets the widget's own
     background extraction fill `settings/bookinfo_cache.sqlite3`. The driver then reuses that file for
     the real capture. This needs a `driver.capture` option to keep or seed the cache, with a
     `driver_spec.lua` case.

   Tell them apart by trying (a) first; reject it if the crengine cache change shows in the capture or its
   timings. If no hook point both follows plugin load and precedes the
   home's build without moving `paint_ms`'s start, take (b). Either way, the capture's `paint_ms` must not
   include extraction. Record the choice and the evidence in the PR.
2. **Fixture userpatch** (`spec/emulator/scenarios/2-scenario-home-fixture.lua`, from `home-layout`'s
   goldens task). The populated scenario gains these, all under the scratch `KO_HOME`:
   - `G_reader_settings` `document_metadata_folder = "dir"` (`frontend/docsettings.lua:118-135`), so no
     sidecar lands in `spec/fixtures/library/`;
   - `<DataDir>/history.lua` holding one entry for the realpath of
     `spec/fixtures/library/frankenstein.epub` (`frontend/readhistory.lua:12`, `:89-97`). It is written
     before `readhistory` first loads, or followed by `ReadHistory:reload(true)` (`:359-367`).
   - Frankenstein's sidecar: `percent_finished = 0.62`, `doc_pages = 220`,
     `doc_props = { title = "Frankenstein", authors = "Mary Shelley" }`, `summary = { status = "reading" }`
     and `partial_md5_checksum = util.partialMD5(file)` (`frontend/util.lua:1094`);
   - a `book` row in the scenario's Statistics database with that md5 and `pages = 220`, plus ten
     `page_stat_data` rows of 90 s on ten distinct pages (under the 120 s `max_sec`), each with
     `total_pages = 220` so the `page_stat` view doesn't rescale them (`main.lua:438-451`). The rate is
     90 s a page. 220 − round(0.62 × 220) = 84 pages left, × 90 s = 7560 s, so the caption reads
     "62% · 2 h 6 min left". These rows are dated 2025-01-01, outside the stats widget's month and its
     400-day streak window, so `home-layout`'s streak, minutes and books numbers don't move.
   - the state keys `featured_chapter_file` (the realpath) and `featured_chapter = "Letter IV"`.

   The empty scenario writes no history, so the slot shows the first-run state. A new **typecover**
   scenario is the populated one with `coverbrowser` added to the profile's `plugins_disabled`. The
   driver's list is `M.disabled_plugins` (`spec/emulator/driver.lua:18` on `main`), so either add a
   per-capture `extra_disabled` option with a `driver_spec.lua` case, or have the patch add it to
   `G_reader_settings` before `PluginLoader` reads it (`pluginloader.lua:175`).
3. **`spec/emulator/home_golden_spec.lua`:**
   - regenerate the six `home-*` goldens of `home-layout`;
   - add `home-typecover-diner-colorsoft` and `home-typecover-editorial-colorsoft`;
   - generate with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/home_golden_spec.lua` and open every
     PNG next to its board (Main, HomeRetro, PWEditorial, PWRetro, EmptyStates). The PR lists every
     difference that is on purpose: the real cover against the boards' typographic one, Diner's first-run
     state (no board), the square cover image under Editorial's radius, the grey cover frames from the tokens, the approximate grey hatch, the
     square progress bar ends and the chapter text.
4. **Budgets.** `spec/emulator/home_capture_spec.lua` keeps `paint_ms <= 250` on each profile, now with
   the featured row. `spec/emulator/book_close_spec.lua` runs as is: closing a fixture book now records
   the chapter and pre-builds a home that reads it, and the 100 ms share must still hold. If either bound
   fails, report the measured number and the slow read (time each read in a scratch run) rather than raise
   the bound.

## Surfaces

`spec/emulator/scenarios/2-scenario-home-fixture.lua`, `spec/emulator/home_golden_spec.lua`,
`spec/emulator/home_capture_spec.lua` (only if its scenario setup needs the featured data),
`spec/emulator/driver.lua` and `spec/unit/driver_spec.lua` (only for candidate (b) or `extra_disabled`),
`spec/goldens/home-*.png` and `.json` (six regenerated, two new); `HOOKS.md` harness section for anything
the patch overrides.

## Tests

- `home_golden_spec.lua` (C8): fails first on the six changed goldens and the two missing ones. Then the
  goldens are generated, eyeballed and committed, and a second plain run passes.
- Determinism: two consecutive plain runs pass with empty masks. A cover that differs between runs
  means the cache isn't settled before the build: fix the scenario, don't mask.
- `home_capture_spec.lua` (C9) and `book_close_spec.lua` (C10) pass unchanged in their assertions.

## Edge cases

- `util.partialMD5` reads the EPUB. The patch runs it once at setup, outside any measured span.
- Diner's grey palette is used only on the paperwhite profile; the typecover pair is colour only, as
  `home-layout`'s empty pair is.
- If candidate (a) extracts at a cover size other than the widget's box, `isCachedCoverInvalid` makes the
  widget ask again after the settle. Pass the widget's own box size through `FeaturedCover.box` so the
  first extraction is already big enough.
