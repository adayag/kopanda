# Find, Go to page and the finished mark (2026-11-06)

Three changes, approved by the owner after real emulator captures: the Focused panel gains Find and Go to page in plain dialogs, and a finished book's tile gains a check. No settings key is added.

KOReader citations are at the pinned build `e1fe1ac`, under `frontend/`.

## Why

Focused mode exists so readers never meet KOReader's menus, yet finding a word or a page meant holding the header for them. KOReader's own dialogs would bring the same confusion with them: Find shows Case sensitive and Regular expression (`apps/reader/modules/readersearch.lua:296-400`), Go to page shows Pin, Skim and Go to % (`apps/reader/modules/readergoto.lua:33-122`).

A tile already shows a progress strip for a book being read or on hold (`library_tiles.lua`, `LibraryTiles.book`), but finished and new books look the same.

## The panel's layout

Top to bottom: Night and Bookmark; Text size and Contrast at full width; Brightness and Warmth side by side; Find and Go to page; Contents, Bookmarks and Home.

A third row of cells alone overflows the screen in every look on the Colorsoft and the Paperwhite 7th gen (Diner on the Colorsoft: 1795 px on a 1680 px screen). Sharing a row between Brightness and Warmth wins back one bar. Measured with the full layout on the Colorsoft: the panel's top is at 47 px in Diner, 118 in Editorial and 133 in Frosted.

- `Steppers.draw` takes a bar with `beside`, a second bar drawn in the same row. Each takes half of the row less a new `quick_settings.pair_gap` token (30 board pixels). The order of the areas stays minus, plus for each bar, the first bar first.
- A device without warmth keeps Brightness at full width. Only the panel pairs them: the quick-settings sheet doesn't change.
- `spec/unit/focused_panel_spec.lua`'s fit test stands unchanged as the proof.

Landscape stays out of scope: the panel is already too tall there today, and this doesn't change that.

## Find in book

The Find cell closes the panel and opens an `InputDialog` titled "Find in book", with Cancel and Find, and its keyboard.

- Find with text calls `ui.search:searchCallback(nil, text)` (`apps/reader/modules/readersearch.lua:252`), the text first through `Utf8Proc.normalize_NFC`: only KOReader's own dialog normalises (`:266`), and the default type doesn't ignore diacritics (`:51`), so decomposed keyboard text could miss. Passing text skips the checkboxes and the regex path: it searches ignoring case with the default type (`:259-261`), then runs `findAllText` (`:288-291`, `:733-759`), which shows "Searching… (tap to cancel)", the results list and "No results in the document". Its `UIManager:close(self.input_dialog)` on a nil dialog is harmless (`ui/uimanager.lua:290-294`).
- Empty text, or only spaces, closes the dialog and searches for nothing.
- The results list and what follows a jump are KOReader's and are not restyled.

## Go to page

The Go to page cell closes the panel and opens an `InputDialog` titled "Go to page", with `input_type = "number"`, a hint and Cancel and Go.

- The hint is "Page N of M": `ui:getCurrentPage()` (`apps/reader/readerui.lua:1007`) and `ui.document:getPageCount()`, or, when `ui.pagemap` exists and `wantsPageLabels()` (`apps/reader/modules/readerpagemap.lua:330`), the current, first and last labels as `ReaderGoto:onShowGotoDialog` reads them (`apps/reader/modules/readergoto.lua:35-41`).
- Go with a page in range calls `ui.link:addCurrentLocationToStack()` (`apps/reader/modules/readerlink.lua:793`), then sends `GotoPage`, as `ReaderGoto:gotoPage` does (`apps/reader/modules/readergoto.lua:139-159`). With labels, `cleanPageLabel` and `getPageLabelProps` (`readerpagemap.lua:176`, `:364`) find the page.
- A number outside 1 to M, an unknown label, or nothing typed leaves the dialog open and goes nowhere.
- Relative pages (`+5`) and hidden flows' `[x]y` are KOReader's power features and are left out.

## Failure

The dialogs live in a new module, `focused_dialogs.lua`. As `show_list` does for the panel's lists (`focused_panel.lua`), a dialog that can't be shown logs and falls back to KOReader's own event: `ShowFulltextSearchInput` or `ShowGotoDialog` (`dispatcher.lua:205`, `:183`). A button whose callback raises logs and closes the dialog, as `SearchScreen.ask` does.

## The finished mark

A book whose status is `complete`, with a file and not a placeholder, gets the badge circle with the `check` icon, at the download badge's place and in the look's badge tokens. A book not downloaded keeps the download badge, its one sign. It shows wherever `LibraryTiles.book` draws: the Library, Series and Authors, Subjects and Search.

## Tests

- `spec/unit/focused_panel_spec.lua`: the areas' order; Find and Go to page close the panel and open their dialogs; the fallback to KOReader's event; Brightness and Warmth side by side, and Brightness at full width without warmth; the fit test, unchanged.
- A new `spec/unit/focused_dialogs_spec.lua`: Find with text, empty text and spaces; Go at 0, 1, the last page and one past it; labels; a raising callback.
- `spec/unit/library_tiles_spec.lua`: the check on a finished book, the download badge on one not downloaded, none on reading or new.
- `spec/unit/steppers` coverage where `Steppers.draw`'s pairing is tested, in whichever spec already covers it.
- Emulator, by name: `spec/emulator/focused_panel_spec.lua` (its `areas` count goes from 13 to 15), `spec/emulator/paint_budget_spec.lua` and `spec/emulator/library_capture_spec.lua`.
- By eye on the Kindle: the keyboard, a real find and a real jump. The emulator has no on-screen keyboard.
