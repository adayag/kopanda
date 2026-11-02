# Focused mode, release 2: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** The reader panel's Go to row opens a KoPanda Go to screen over the book, with two tabs. Chapters lists every
level, marks the current chapter and opens on its page. Bookmarks lists them newest first, and a hold on one offers
Remove bookmark. A tap on a row jumps there and closes the screen.

**Architecture:** The screen is a library window (`LibraryChrome.Window`, as Series and Authors are), shown over the
reader with no nav bar. The chrome gains two small things: a nav-less foot, and a window's own hold sheet. A pure model
(`goto_list.lua`) reads KOReader's TOC and annotations and does the jumps and the removal through KOReader's own
calls. A new row builder (`goto_rows.lua`) draws the text rows, because no plain text row exists today.

**Tech stack:** Lua on KOReader's LuaJIT. Busted unit specs under a fresh `KO_HOME`. Emulator scenario patches with
the capture driver.

**Design:** `docs/plans/2026-11-02-focused-mode-design.md`. The "Go to screen" row of its decisions table is the
spec, and this plan doesn't repeat it. The owner chose on 2026-11-02 to reuse the library frame rather than build a
standalone window.

**Process:** TDD for every task: write the test, run it and see it fail, implement, see it pass. Nothing is committed
during the tasks. The lead runs `bin/check` once at the end and presents the release to the owner before any commit.
Read `bin/check` output through a filter that drops KOReader's chatter
(`2>&1 | grep -vE "ffi.load|Loading|register crengine font" | tail -20`). The gate for each task is
`bin/check --unit`, plus `bin/check spec/emulator/<name>_spec.lua` for each emulator spec the task names.

**Choices this plan makes (not in the design; the owner judges them at the manual check):**
- **Leaving without a jump:** the header carries the detail header's back control, labelled "Book", which closes the
  screen. The design names no way out without a jump.
- **The current chapter:** its row is one line taller than the others. The extra line reads "You are here" under the
  title, so the marker is words, not a symbol. Rows may differ in height, because `ShelfOrder.pages` takes each row's
  own `h`.
- **Text size:** the screen follows the `text_size` setting as every library window does
  (`LibraryChrome.build`, `library_chrome.lua:241-247`). It is a full-screen list that pages, so it has no fit
  problem.
- **Page numbers:** the TOC's own `page` for chapters, and `ReaderBookmark:getBookmarkPageString` for bookmarks. Both
  match what the reader's footer shows.

Facts from the survey (KOReader at the pinned build `e1fe1ac`; check each one before relying on it):
- **TOC:**
  - `ReaderToc:fillToc` is at `readertoc.lua:160-175`.
  - Its items are `{ title, page, depth, xpointer (rolling only) }`; `validateAndFixToc` is at `:176-213`.
  - `getTocIndexByPage(pn_or_xp, skip_ignored_ticks)` is at `:383-406`. Pass the xpointer for a rolling document, and
    nil for `skip_ignored_ticks` so that every level counts.
  - `cleanUpTocTitle` is at `:91`.
  - KOReader's own jump is `ui.link:addCurrentLocationToStack()` (`readerlink.lua:793`), then
    `GotoXPointer(xp, xp)` or `GotoPage(page)` (`readertoc.lua:940-948`).
- **Bookmarks:**
  - Bookmarks are the items in `ui.annotation.annotations` with no `drawer` (`readerbookmark.lua:590-598`,
    `:417-440`).
  - Their fields are `page` (an xpointer when rolling, a number when paging), `chapter`, and `datetime`
    (`"YYYY-MM-DD HH:MM:SS"`, `readerannotation.lua:519-526`).
  - Newest first means sorting by `datetime`, descending. A string compare works (`readerbookmark.lua:604`).
  - Jump with `ReaderBookmark:gotoBookmark(pn_or_xp, marker_xp)` (`:487-492`), after
    `addCurrentLocationToStack` (as `:546` does).
  - Remove with `ui.bookmark:removeItem(item, index)` (`:446-455`), which also updates the dogear. Get the index from
    `ui.annotation:getItemIndex(item)` (`readerannotation.lua:479`).
  - The page label is `getBookmarkPageString(page)` (`readerbookmark.lua:628-643`).
- **The fixture book:** `spec/fixtures/library/frankenstein.epub` has a TOC of 39 entries, nested 3 deep, and no
  bookmarks.
- **The library chrome:**
  - `LibraryChrome.foot` always builds a nav bar (`library_chrome.lua:228-235`), and `LibraryChrome.build` always
    adds it (`:251`).
  - `routeGesture` already guards `self.nav` (`:710`).
  - `hold_step` sends every hold to `LibrarySheets.hold` (`:688-699`).
  - `Home.close()` is a no-op with no home shown (`home.lua:264-268`).
  - `HomeGestures.forward` does nothing without `FileManager.instance`, apart from page swipes, which the window has
    already taken (`home_gestures.lua:131-144`).
  - The header chip builder is local to `library_view.lua:55-77`.

---

### Task 1: The chrome over a book (nav-less foot, a window's own hold, the chip)

**Files:**
- Modify: `kopanda.koplugin/library_chrome.lua` (`foot`, `build`, `hold_step`)
- Modify: `kopanda.koplugin/library_view.lua` (its `chip` moves to `LibraryChrome.chip`)
- Test: a new `spec/unit/library_chrome_spec.lua`, or the chrome's existing unit spec if one exists (`ls spec/unit/ | grep -i chrome`)

**Changes:**
1. **No nav bar:** `LibraryChrome.foot(built, frame, where)` with `where == nil` builds no nav bar. It sets
   `built.nav = nil` and places the pager with its foot at the screen's bottom (`h`). `LibraryChrome.build` adds
   `built.nav` only when it is set.
2. **A window's own hold:** `hold_step` calls `window:hold_sheet(hit, started)` when the window defines it, and
   `LibrarySheets.hold(window, hit, started)` otherwise.
3. **The chip:** `library_view.lua`'s `chip(widgets, fill, ctx)` moves to `LibraryChrome.chip`, and `library_view.lua`
   calls the moved one. The body is unchanged.

**Tests first:**
- A window built with `foot(built, frame, nil)` has no `built.nav`, and its pager's bottom sits within the screen at
  its foot.
- A window that defines `hold_sheet` gets the hit, and `LibrarySheets.hold` isn't called. A window without it still
  reaches `LibrarySheets.hold`.

The library, Series, Authors and Subjects captures must stay unchanged:
`bin/check spec/emulator/library_capture_spec.lua` and whichever emulator specs cover those screens
(`ls spec/emulator/`).

### Task 2: The model (`goto_list.lua`)

**Files:**
- Create: `kopanda.koplugin/goto_list.lua`
- Test: `spec/unit/goto_list_spec.lua` (a fake `ui`, as `spec/unit/focused_panel_spec.lua` builds one)

**API:**
- **`GotoList.chapters(ui)`:** returns `{ rows, current }`.
  - `rows[i]` is `{ title, depth, page, xpointer, index }`, from `ui.toc` after `ui.toc:fillToc()`. Titles go through
    KOReader's clean-up if it can be called on its own (`readertoc.lua:91`); otherwise they are trimmed.
  - `current` is the index `getTocIndexByPage` returns for the current position: the xpointer
    (`ui.document:getXPointer()`) for a rolling document, `ui:getCurrentPage()` (or the paging module's current page)
    for a paging one.
  - Each row's depth is relative to the shallowest, so the top level is 0.
  - An empty TOC gives `{ rows = {} }`.
- **`GotoList.bookmarks(ui)`:** the annotations with no `drawer`, newest first by `datetime`. Each is
  `{ item, chapter, page_label }`. `chapter` falls back to `"No chapter"`, and `page_label` comes from
  `ui.bookmark:getBookmarkPageString(item.page)`.
- **`GotoList.jump_chapter(ui, row)`:** `ui.link:addCurrentLocationToStack()`, then
  `ui:handleEvent(Event:new("GotoXPointer", row.xpointer, row.xpointer))` when the row has an xpointer, or
  `GotoPage(row.page)` otherwise.
- **`GotoList.jump_bookmark(ui, entry)`:** `addCurrentLocationToStack()`, then
  `ui.bookmark:gotoBookmark(entry.item.page, entry.item.pos0)`. Check `gotoBookmark`'s second argument at
  `readerbookmark.lua:487`, and pass what KOReader's own list passes.
- **`GotoList.remove_bookmark(ui, entry)`:** `ui.bookmark:removeItem(entry.item, ui.annotation:getItemIndex(entry.item))`.
  Check the signature at `:446`.

**Tests first:**
- A nested TOC flattens in order with relative depths, and `current` is the entry holding the current page. A
  rolling document is asked by xpointer, a paging one by page.
- Highlights (items with `drawer`) are left out, and bookmarks come back newest first.
- Each jump pushes the location stack first, then sends the right event.
- `remove_bookmark` passes the item's own index.

Add a HOOKS.md entry under "The focused panel" (`HOOKS.md:1581+`) for every KOReader internal this task reads or
calls, each with its `file:line`.

### Task 3: The rows (`goto_rows.lua`)

**Files:**
- Create: `kopanda.koplugin/goto_rows.lua`
- Test: `spec/unit/goto_rows_spec.lua`

**API:**
- **`GotoRows.chapter(row, is_current, width, ctx)`:**
  - The title starts after `depth` indent steps, one line, truncated by `Typeset.line`.
  - The page number sits at the right.
  - The current row adds a second line, "You are here".
  - Returns the widget and its height.
- **`GotoRows.bookmark(entry, width, ctx)`:** the chapter on the left, the page label on the right, one line.
- **`GotoRows.height(kind, is_current, ctx)`:** the row heights the plan pages by.

Draw the rows in the look's existing parts:
- the shelf group row's name part and count part (`ShelfRows.group`, `shelf_rows.lua:456-508`);
- the list's row gap and side;
- one indent step: the look's `shelf.list.side`, or an existing spacing token. Add a token only if none fits, and say
  which one in the report.

Don't grow `shelf_rows.lua` (541 lines).

**Tests first:**
- A depth-2 row's title starts two indent steps right of a depth-0 row's.
- The current row is taller and its texts include "you are here".
- No text overflows `width` at Extra large on 1072 wide, in every look (`Looks.ids()`).

### Task 4: The window (`goto_screen.lua`)

**Files:**
- Create: `kopanda.koplugin/goto_screen.lua`, which extends `LibraryChrome.Window` the way
  `kopanda.koplugin/series_screen.lua` does: `name = "kopanda_goto"`, `screen = "goto"`.
- Test: `spec/unit/goto_screen_spec.lua`

**Behaviour:**
- **View:** `{ tab = "chapters" | "bookmarks" }`. `GotoScreen.show{ ui = ui }` opens on Chapters, at the pager page
  holding `current` (use `ShelfOrder.page_of`). With no chapters it opens on Bookmarks.
- **Plan:** row heights from `GotoRows.height` are paged by `ShelfOrder.pages`. The available height is the screen,
  minus the header, the pager (`LibraryTiles.pager_height`) and the top padding. There is no nav bar.
- **Header:** `LibraryChrome.header` with `back_label = "Book"`, the book's title as the title, `"Go to"` as the
  aside, and two `LibraryChrome.chip`s on the right, "Chapters" and "Bookmarks". The active chip uses the header's
  status fill, the other the sort fill; the owner judges them by eye.
- **Foot:** `LibraryChrome.foot(built, frame, nil)`.
- **Taps:**
  - A chip switches the tab and goes to page 1, or to the current chapter's page for Chapters.
  - A row closes the screen first, then jumps through `GotoList`.
  - The back control closes the screen.
  - The chrome turns the pager and swipes.
- **Holds:** `hold_sheet` on a bookmark row shows a one-row sheet, "Remove bookmark", headed by the bookmark's chapter
  and page. Build it the way `library_pickers.lua:43-58` builds its sheet, with `beneath = window`. Its row removes the
  bookmark and refreshes the window, which stays on the Bookmarks tab, on the same page or the last page that still
  exists. A hold anywhere else does nothing.
- **Empty notes:** an empty tab shows a centred note, "No bookmarks yet" or "No chapters in this book", drawn as
  `series_screen.lua:229-235` draws its note. A book with neither still opens, on Bookmarks, with the note.
- **Refresh:** `refresh()` re-reads both lists from the window's `ui` and rebuilds. The metadata events that call it
  over the reader are harmless.
- **Rotation:** the chrome already rebuilds on a size change (`library_chrome.lua:531-560`).

**Tests first (unit, against a fake ui):**
- The screen opens on Chapters at the page holding the current chapter.
- It opens on Bookmarks when there are no chapters, and shows the note when there is neither.
- A chip tap switches the tab.
- A row tap closes the screen, then calls the jump. Assert the order.
- A hold on a bookmark row shows the sheet, and its row removes that bookmark and leaves one fewer row.
- A hold on a chapter row shows no sheet.
- The window never builds a nav bar.

### Task 5: Wire the panel's Go to

**Files:**
- Modify: `kopanda.koplugin/focused_panel.lua` (the `go_to` action, `:152-154`)
- Test: `spec/unit/focused_panel_spec.lua`

**Change:** `go_to` calls `GotoScreen.show{ ui = ui }`. When that returns nil or raises, it falls back to
`ui:handleEvent(Event:new("ShowToc"))`, so the reader always gets a contents list. Update `HOOKS.md`'s ShowToc entry
(`:1617`) to say it is now the fallback.

**Tests first:**
- The go_to action shows the Go to screen.
- With `GotoScreen.show` stubbed to return nil, it sends ShowToc.

### Task 6: On the emulator

**Files:**
- Modify: `spec/emulator/scenarios/2-scenario-focused-panel.lua` (a new `KOPANDA_FOCUSED_STEP = "goto"`)
- Modify: `spec/emulator/focused_panel_spec.lua`

**The "goto" step:**
1. With the book open, it bookmarks two pages through `ui.bookmark:onToggleBookmark()`, turning a page between them.
2. It opens the panel, taps the `go_to` area, and waits for the `KoPandaSettled` signal with `screen = "goto"`.
3. It reports:
   - the tab, the row count on the page, and whether a row is marked current;
   - whether the window has a nav bar;
   - the page that holds the current chapter.
4. It taps the Bookmarks chip, then holds the first bookmark row and taps "Remove bookmark". It reports the bookmark
   count before and after.
5. It taps a chapter row and reports that the window closed and that the reader's page changed.

**Test:** on the Paperwhite 7th gen with `text_size = "extra_large"`, and on the Colorsoft at the default size:
- the screen opens on Chapters with a current row;
- there is no nav bar;
- a removal leaves one bookmark;
- a chapter tap closes the screen and moves the page.

**Captures:** the builder renders the Go to screen (Chapters, then Bookmarks) on both devices into
`/private/tmp/claude-501/-Users-allendayag-Projects-elatedpanda-kopanda/c900a45d-4b0f-42b8-a25c-2988a80b901c/scratchpad/shots/goto-*`,
for the owner's eye.

### Task 7: Finish (the lead)

1. Run the full `bin/check` once.
2. Render the Go to screen on the Paperwhite 7th gen (Editorial, Diner, at Extra large) and on the Colorsoft
   (Frosted), and `open` the PNGs.
3. Update the design doc where the build chose for it: the back control, the "You are here" line, and the text size.
4. Present a summary and the commit message, then ask: "Ready to commit and push?"

## Agents

- **Builder** (Opus): tasks 1–6, then a self-review. It doesn't commit.
- **Reviewer** (Opus): one pass over the whole diff, against this plan and the design. No mutation checks, because
  nothing here reads outside files or touches the push or bundle path. It ends with a numbered fix list.
- **Fixer** (Opus): a fresh agent, if the review asks for fixes. It writes each test first.
- The lead does task 7.

Estimate: the builder takes 2–3 hours of agent time; the review and fixes take 1 hour.
