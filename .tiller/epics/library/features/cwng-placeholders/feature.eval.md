---
node: F-yy4zaa
criteria:
  - id: C1
    statement: "With a cwngsync module registered on the file manager that is configured and whose library state records a path as a placeholder of the file's own size, Books.folder, Books.all, Books.for_path, Books.get and Books.with_progress give that file's record placeholder = true with its path kept; a recorded size that differs from the file's, a downloaded kind, a path recorded in another form, an unconfigured plugin, no cwngsync module and no file manager each give no placeholder; a missing method, a raising call or a state without a books table gives no placeholder and is logged while the listing is otherwise as it was; the state is read once per Books call, not once per book; path-less records and Books.files are unchanged"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/cloud_books_spec.lua" }
    required: true
  - id: C2
    statement: "A placeholder's tile on the library grid and on the one-author grid carries the download badge and the Not downloaded chip, the Up next label still taking the chip's place with the badge kept, and its strip when its sidecar gives a percent; its one-series row carries the badge, the Not downloaded chip unless Finished, and the Not on the Kindle yet note unless it has a bar or is marked read this one next; a tap on it still runs the window's open of that record; the book sheet over it reads the meta Not downloaded and greys Delete with no run while Open, Book details, Read status, More by this author and Add to the home run as for a downloaded book"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/cloud_books_spec.lua" }
    required: true
  - id: C3
    statement: "The book sheet over a placeholder on the library, the one-series list and the one-author grid has a Download row with the download icon directly under Open; a tap closes the sheet and calls the cwngsync instance's openLibraryPlaceholder once with the record's path and a callback; that callback re-lists the window it was held on at its page with the book read again, so the badge is gone once the file is no longer a placeholder, asks for that book's cover again, opens no reader and does nothing when that window is no longer shown; a false return re-lists the window; a raising call or callback is logged with the window as it was; the row is greyed with no run when the instance has no openLibraryPlaceholder; a downloaded book's and a path-less record's sheets have no Download row"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/cloud_download_spec.lua" }
    required: true
  - id: C4
    statement: "Without cwngsync the library, the shelf screens, their tiles and rows, the book sheet over a record and the home's book sheet render and behave as they did before this feature: their spec cases pass as they stand at main 1e25e44, none weakened, and every hook that failed safe before still does"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/books_spec.lua", "spec/unit/library_tiles_spec.lua", "spec/unit/shelf_rows_spec.lua", "spec/unit/book_sheet_spec.lua", "spec/unit/library_screen_spec.lua", "spec/unit/series_screen_spec.lua", "spec/unit/authors_screen_spec.lua", "spec/unit/library_sheets_spec.lua", "spec/unit/failsafe_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin"
      captured_at: { kind: git_tree, value: "git:1e25e44", path: kopanda.koplugin, observed_at: "2026-10-17T20:44:30Z" }
    required: true
  - id: C5
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires or reads from package.loaded, every G_reader_settings and G_defaults key it reads and every underscore-prefixed field or method it touches, and every entry of its Plugin section cites a file:line; no KoPanda module name collides with one in frontend/, common/ or an emulator plugin; main.lua requires every KoPanda module at load, cloud_books included"
    polarity: preserve
    binding: { type: test, ref: ["spec/unit/hooks_doc_spec.lua", "spec/unit/main_requires_spec.lua"] }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:1e25e44", path: kopanda.koplugin, observed_at: "2026-10-17T20:44:30Z" }
    required: true
  - id: C6
    statement: "The schema gains no key: kopanda.koplugin/schema.lua is unchanged from main at 1e25e44"
    polarity: preserve
    binding: { type: command, run: "git diff --quiet 1e25e44 -- kopanda.koplugin/schema.lua" }
    baseline:
      surface: "kopanda.koplugin/schema.lua"
      captured_at: { kind: git_tree, value: "git:1e25e44", path: kopanda.koplugin/schema.lua, observed_at: "2026-10-17T20:44:30Z" }
    required: true
  - id: C7
    statement: "The committed library-placeholder-diner golden on colorsoft matches a fresh capture of cover-grid's capture library at its root with a stub cwngsync naming one root book as a placeholder, shot on the library's KoPandaSettled, and the capture paints within the paint budget"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/library_placeholder_golden_spec.lua" }
    required: true
  - id: C8
    statement: "Every golden committed at main 1e25e44 still matches a fresh capture, this feature regenerates none of them, and the home's capture still paints within its budget"
    polarity: preserve
    binding: { type: test, ref: ["spec/emulator/home_golden_spec.lua", "spec/emulator/night_golden_spec.lua", "spec/emulator/sheet_golden_spec.lua", "spec/emulator/screens_golden_spec.lua", "spec/emulator/nav_golden_spec.lua", "spec/emulator/golden_spec.lua", "spec/emulator/library_golden_spec.lua", "spec/emulator/library_hold_golden_spec.lua", "spec/emulator/series_authors_golden_spec.lua", "spec/emulator/quick_settings_golden_spec.lua", "spec/emulator/swatch_golden_spec.lua", "spec/emulator/home_capture_spec.lua"] }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:1e25e44", path: spec/goldens, observed_at: "2026-10-17T20:44:30Z" }
    required: true
  - id: C9
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C10
    statement: "The owner has opened the library-placeholder-diner golden and confirms the placeholder's tile reads as Main.dc.html draws a not-downloaded book (badge, chip), the same as the path-less book beside it"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C11
    statement: "The owner has held a placeholder on the emulator, with the stub cwngsync, in both looks and by day and night, and confirms the undrawn sheet reads as the book sheet with a Download row under Open, the meta Not downloaded and Delete greyed"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C12
    statement: "The owner has run, on the Kindle with cwngsync configured and their own library: the badge and chip on placeholders on the library grid, one series and one author, and none on downloaded books; held a placeholder and tapped Download, seen cwngsync's download notice, stayed on the same screen and page with no book opened, and seen the tile lose its badge and keep its cover; done the same from one series and one author; tapped Download with Wi-Fi off and seen KOReader's Wi-Fi prompt; opened a placeholder from the sheet and seen it download and open; marked a placeholder's read status (sent to the server with cwngsync's auto sync on); confirmed Delete is greyed on a placeholder and still works on a downloaded book; and found the library quick enough to open"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR` or its
default path. Ref-only `test` bindings resolve to `bin/check <spec file>...`, which passes spec paths straight
to Busted with no luacheck and refuses a path that is not a file; a criterion that lists several files runs
them all. C9 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite, the studio
included.

C1 to C5 run on KOReader's LuaJIT under the plugin harness with a real file manager (`spec/plugin_harness.lua`).
cwngsync is never vendored: the specs register a stub module on `FileManager.instance` as `cwngsync`, as
`spec/unit/quick_settings_controls_spec.lua:582-610` registers one, with only the methods each case needs
(`isConfigured`, `getLibraryState`, `openLibraryPlaceholder`), and remove it after. `spec/unit/cloud_books_spec.lua`
is new (the `placeholders` task creates it); `spec/unit/cloud_download_spec.lua` is new (the `download-row`
task creates it). C7 and C8 are emulator captures under a fresh `KO_HOME`; `library_placeholder_golden_spec.lua`
is new (the `goldens` task creates it). Goldens are regenerated only with `KOPANDA_UPDATE_GOLDENS=1` and each
regenerated PNG is opened before commit.

C4, C5, C6 and C8 are preserve criteria whose `captured_at` is `main` `1e25e44`: the same spec files must pass
after the change, with new cases added beside the old and no old case weakened. C5's `hooks_doc_spec.lua`
finds modules, settings keys and underscore-prefixed internals, not plugin methods
(`spec/unit/hooks_doc_spec.lua:21-58`), so the "cwngsync's placeholders" entry in `HOOKS.md`, with each
cwngsync citation at `df90d5e`, is each task's review item. So is the narrowed scope line in `AGENTS.md:46`
(D10), a prose change no spec reads.

C10 and C11 are the owner's on the committed PNG and on the emulator; C12 by hand on the Kindle, pushed through
the studio's device push. C12 is the only check against the real cwngsync, at whatever version the Kindle runs.
