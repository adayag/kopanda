# Cover reads and batched extraction with arrival, and the featured cover through them

## Approach

`featured_cover.lua`'s cover read and extraction path, generalised from one file to a list and moved into
the model; `FeaturedCover` keeps its functions as delegates. Paths into KOReader are relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **`kopanda.koplugin/book_covers.lua`.** Module state: `asked` (files asked for in this process),
   `pending` (the in-flight request's files not yet arrived) and `check` (the scheduled function or nil),
   the three `featured_cover.lua:33-34` holds now, plus `pending`.
   - **`BookCovers.read(record, w, h)`**: `featured_cover.lua:70-90`'s `read_cover`, taking the record's
     `path`; a path-less record calls its source's `cover(record, w, h)` through `Books` (caught,
     logged, nil on failure). Never asks.
   - **`BookCovers.wants(info, specs)`**: `featured_cover.lua:298-313` moved unchanged.
   - **`BookCovers.request(records, specs, on_arrival, alive)`**:
     1. Without CoverBrowser, return. Collect each record with a `path` not in `asked` whose
        `getBookInfo(path, false)` row `wants` accepts (each test caught and logged, as `after_show` does
        at `featured_cover.lua:334-338`). None: return.
     2. Replace the request in flight: unschedule its `check`, and remove its `pending` files from
        `asked`. `extractInBackground` is about to terminate their extraction
        (`bookinfomanager.lua:695`).
     3. Mark the files asked before forking, as `featured_cover.lua:342` does now, then
        `pcall(bim.extractInBackground, bim, files)` with `files = { { filepath = path, cover_specs = specs }, … }`
        in the records' order (`:689-745`). Not started or `false` (`:724`): log, schedule nothing; the
        files stay asked, so this process never asks for them again, as today (`featured_cover.lua:345-347`).
        Started: set `pending`, schedule the check at 1 s.
     4. The check is `featured_cover.lua:351-387` over `pending`: return if it is no longer `check`;
        clear `check`; count the run; return if `alive()` is false; read each pending row without a
        cover, moving those with a fitting cover (`has_fitting_cover`, `:58-61`) to `arrived`. If nothing
        is pending: `on_arrival(arrived)` when any, done. Else if `runs < 30 and isExtractingInBackground()`
        (that order, so the 30th check doesn't ask): `on_arrival(arrived)` when any, reschedule. Else read
        each pending file with its cover, free the bitmap, add the usable ones to `arrived`,
        `on_arrival(arrived)` when any, done. The whole check runs in `pcall`; a failure is logged and
        leaves nothing scheduled. Done clears `pending`.
   - **`BookCovers.cancel()`**: unschedule and clear `check`; `asked` stays.
   - **`BookCovers.reset()`**: cancel, clear `asked` and `pending`. For specs.
2. **`featured_cover.lua` delegates.** `build` calls `BookCovers.read({ path = book.file }, w, h)`;
   `wants_extraction` is `BookCovers.wants`; `after_show(home, file, specs)` is
   `BookCovers.request({ { path = file } }, specs, function() home:refresh() end, function() return require("home").shown == home end)`
   when `file` is set; `cancel` and `reset` call `BookCovers`'. `home.lua:331`'s cancel on close is
   unchanged. The module's moved locals go; `box`, `build`'s drawing, the placeholder and the dashed
   frame stay.
3. **`main.lua`** requires `book_covers`. **`HOOKS.md`**: the "featured cover" section's
   `bookinfomanager` entries name `book_covers.lua` as the reader and asker, and add the cache facts the
   model relies on: one row per file (`bookinfomanager.lua:68`), the scale-down at extraction (`:533-540`),
   and the batch's single subprocess walking its files in order (`:702-711`).

## Surfaces

- `kopanda.koplugin/book_covers.lua` (new)
- `kopanda.koplugin/featured_cover.lua`
- `kopanda.koplugin/main.lua`
- `kopanda.koplugin/HOOKS.md`
- `spec/unit/book_covers_spec.lua` (new); `spec/unit/books_source_spec.lua` and
  `spec/unit/books_coverbrowser_spec.lua` (cover cases added)

## Tests

Written first and run failing, then the module. Run through `bin/check <spec>` with its output filtered to
the summary and failures.

- **`spec/unit/book_covers_spec.lua`** (C6), with `featured_cover_spec.lua`'s stub pattern (a
  `bookinfomanager` table in `package.loaded`, `UIManager.scheduleIn` and `unschedule` recording a
  queue, restored in `finally`):
  - `read`: usable bitmap returned; too small, ignored or `cover_bb` nil freed and nil.
  - `request` with four records, one already cached, one path-less, two missing: one
    `extractInBackground` call holding the two paths and the specs; a second request for them asks
    nothing.
  - arrivals: the first arrives at check 2 while extraction runs and `on_arrival` gets it alone; the
    second at the last check's cover read, and `on_arrival` gets it alone; at most one `on_arrival` per
    check; the queue empty after.
  - 30 checks with no arrival end with no call; `alive` false stops at the next check; `cancel` leaves the
    queue empty with `asked` kept; a second request while the first is pending unschedules it and the
    first's unarrived file is asked again by a third; a `false` fork schedules nothing and a later request doesn't ask for its files again.
- **`books_source_spec.lua`** (C4): a source's cover drawn through `read`; `request` with a path-less
  record never calls `extractInBackground`; a raising `cover` logged and nil.
- **`books_coverbrowser_spec.lua`** (C7): after the real `extractBookInfo` at 150×225, `read` at 150×225
  gives a bitmap no larger than the box, and at 300×450 gives nil (the thumbnail is too small).
- `featured_cover_spec.lua`, `featured_widget_spec.lua`, `book_sheet_spec.lua` and `failsafe_spec.lua`
  (C8) pass with no assertion changed; `hooks_doc_spec.lua` and `main_requires_spec.lua` (C10) pass.
- The emulator specs `home_golden_spec.lua`, `sheet_golden_spec.lua`, `home_capture_spec.lua` and
  `book_close_spec.lua` (C9) pass with no golden regenerated.

## Edge cases

- **Call counts the featured spec pins.** "checks each second … as it ends" expects 4
  `isExtractingInBackground` calls and a final `get_cover = true` read (`featured_cover_spec.lua:476-505`);
  "stops after 30 checks" expects exactly 30 (`:535-548`). Step 1.4's order keeps both for one file.
- **A stale bitmap at the last check** is freed even when unusable (`featured_cover_spec.lua:550-574`).
- **CoverBrowser's own file browser in mosaic mode** calls `extractInBackground` too and terminates
  KoPanda's job (`plugins/coverbrowser.koplugin/covermenu.lua:108-131`). KoPanda's files stay marked asked
  until the process restarts; the check ends when extraction stops. That is the featured cover's
  behaviour now, and the grid replaces that file browser.
- **A batch slower than 30 s** on the Kindle leaves the late covers for the next build. Whether the grid
  wants a longer cap is `library/cover-grid`'s question, with its page size in hand.
