# The library window: header, page, pager, nav bar, gestures and covers

## Approach

The window itself, shown and closed by direct calls; how the rest of KoPanda reaches it is `routing`'s and
the sheets are `pickers`'. Starts after `order` and `tiles`. Repo lines on `main` at `4564444`; KOReader
relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. Feature sections "The window", "The header", "The
page", "The pager", "Gestures", "Covers", "Failure behaviour".

1. **`kopanda.koplugin/library.lua` (`Library`),** modelled on `home.lua` and `editor.lua`:
   `InputContainer:extend{ name = "kopanda_library", covers_fullscreen = true }`; `Library.shown`;
   `Library.show{ dir, page, started }`, `Library.close()`, `library:go(dir, page)` (rebuild in place and
   `setDirty`); `paintTo` in `pcall`, a failure closing it from the next tick (`home.lua:299-318`); the
   paint rebuilds on a variant or size change (`editor.lua:360-369`); the settled signal once per show
   (`home.lua:156-200`), `screen = "library"`.
2. **Build:** `Books.folder(dir)` (`books.lua:242-261`), `LibraryOrder.choice`, `view` and `page`; the header
   (count, title with the back mark below the root, the two pickers with `chevron_down`), the page's tiles
   from `LibraryTiles` placed in the geometry's columns and rows, the pager, and
   `NavBar.new{ look, variant, width, where = "library", listen = false }` at the bottom
   (`nav_bar.lua:232-243`). The empty note (D17) in the page's place.
3. **`NavBar`:** `ACTIVE.library = "library"` (`nav_bar.lua:33`) and `NavBar.run`'s Home branch
   (`:70`) taken for `where == "library"` as well, closing the library before `goHome`.
4. **Gestures** in the feature's order, through the library's own touch zones so the touch lock filters
   them (`home_gestures.lua:47-54`). The forward step reuses the home's: factor `HomeGestures`' forward to
   `fm.menu` and `fm` (`home_gestures.lua:139-160`) into a function both call, the home's routing unchanged.
   Page keys registered only when `Device:hasKeys()` (`menu.lua:984-992`). `Library.hit(x, y)` from the
   built tiles' boxes. A tap on a downloaded book calls `filemanagerutil.openFile(fm, record.path,
   pre)` (`filemanagerutil.lua:498-532`), where `pre` calls `Library.on_open(dir, page)`, a hook `routing`
   fills (here a no-op); `openFile` runs it only once the open goes ahead (`:500-502`). A picker tap calls
   `Library.on_picker(kind)`, a hook `pickers` fills (here a no-op). West and east swipes starting in the
   `DSWIPE_ZONE_TOP_EDGE` or `DSWIPE_ZONE_BOTTOM_EDGE` band go to the forward step, as the home leaves them
   (`home_gestures.lua:40-45`).
5. **Covers:** from `nextTick` after a page's first paint, `BookCovers.request(records, specs, on_arrival,
   alive)` (`book_covers.lua:144-235`); `on_arrival` re-reads each arrived record by `Books.get(id)`
   (`books.lua:303-322`), rebuilds those tiles in place and sets the library dirty; `onCloseWidget` calls
   `BookCovers.cancel()`.
6. **Events:** `onBookMetadataChanged` and `onInvalidateMetadataCache` re-list and rebuild the current page.
7. **Folder memory at close:** `onCloseWidget` calls `LibraryOrder.leave(dir, page)`.
8. `main.lua` requires `library`; `HOOKS.md` gains `filemanagerutil.openFile`, `Menu:onSwipe`'s directions,
   the page keys, `BookMetadataChanged` and `InvalidateMetadataCache`, and `Device:hasKeys`.

## Surfaces

- `kopanda.koplugin/library.lua` (new), `nav_bar.lua`, `home_gestures.lua`, `main.lua`, `HOOKS.md`.
- `spec/unit/library_screen_spec.lua` (new), `spec/unit/library_gestures_spec.lua` (new),
  `spec/unit/nav_bar_spec.lua`, `spec/unit/failsafe_spec.lua`, `spec/unit/library_lifecycle_spec.lua` (new,
  the covers cases; `routing` adds to it).

## Tests

Written first, each run failing before the code, with `Books.folder`, `Books.progress` and `BookCovers`
stubbed where a case needs a listing the fixture library lacks:

- `library_screen_spec.lua` (C6): header text per look for 0, 1 and 6 books and under a status; "Library" at
  the root and the folder's name inside one; pickers' labels; six tiles in three columns and two rows at the
  geometry's boxes; the pager's label and dead arrows on pages 1, a middle one and the last; the empty note;
  the bar with Library active; a rebuild after `Looks.variant` changes and after the screen size changes;
  metadata events re-listing; one `KoPandaSettled{ screen = "library" }` per show with a numeric `paint_ms`.
- `library_gestures_spec.lua` (C7): every row of the feature's gesture order, with `filemanagerutil.openFile`
  stubbed (its `caller_pre_callback` run by the stub); a corner zone registered on the file manager firing
  for a tap the library doesn't take, and not for one in the bar; an edge-band swipe reaching the file
  manager; a picker tap calling `Library.on_picker` with its kind; the touch lock; `Library.hit` for a book, a folder and the gap between tiles.
- `nav_bar_spec.lua` (C6): `where = "library"` lights Library; Home from the library closes it and shows the
  home.
- `library_lifecycle_spec.lua` (C9): the request's records and specs for a page; an arrival rebuilding only
  the arrived tile, with its new title and without re-sorting; a page turn replacing the request; close
  cancelling.
- `failsafe_spec.lua` (C11, C12): a raising paint and a raising gesture route close the library onto the file
  browser; a raising tap action, cover request and arrival leave the page as it was; the existing cases
  unchanged.
- `gesture_routing_spec.lua` and `hold_routing_spec.lua` pass unchanged after the forward step is factored
  (C12).
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C13) pass with `library` and the new entries.

## Edge cases

- A folder deleted between shows: `Books.folder` logs and gives empty lists (`books.lua:202-206`); the
  library shows the empty note. Going up from it still works.
- `Library.go` to a page beyond the end after books vanished: `LibraryOrder.page` clamps it.
- The home's `onCloseWidget` cancels the shared cover check (`home.lua:331`, through
  `featured_cover.lua:233-234`); the library's request is
  always made after the home closed, from the next tick after its own paint.
- Taps while a cover arrival rebuild is pending: the gesture uses the built tiles of the moment; the rebuild
  keeps the boxes, since tiles have a fixed height.
