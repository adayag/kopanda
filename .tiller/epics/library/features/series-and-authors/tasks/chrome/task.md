# Factor the library's window chrome into a shared module, the library unchanged

## Approach

A pure refactor of code `library/cover-grid` (F-2nt0fx) builds, so the two new windows share it. Starts once
cover-grid has merged to `main`; read `library.lua`, `library_pickers.lua`, `library_tiles.lua` and
`main.lua` as merged, since their line numbers and names exist only then. Feature section "The chrome",
decision D1. Cover-grid's spec says what `library.lua` holds: feature.md:114-141 (the window),
:188-192 (the pager), :248-274 (gestures), :296-305 (covers), :307-320 (book close), :332-344 (failures);
screen task.md:10-38 and routing task.md:15-27 (how it was built).

1. **`kopanda.koplugin/library_chrome.lua` (`LibraryChrome`)** takes from `library.lua` every part that does
   not name the library's folders, sorts or tiles:
   - the window base: an `InputContainer:extend` with `covers_fullscreen = true` that a window module
     extends, its `shown` slot, `show(opts)` and `close()` with `UIManager:show(…, "full")` /
     `UIManager:close(…, "full")`, `go(...)` rebuilding in place and setting dirty;
   - the paint guard, a failed paint closing the window onto the file browser from the next tick; the
     rebuild on a `Looks.variant()` or `Screen:getSize()` change before painting; the settled signal once per
     show with the window's `screen` name and `paint_ms`;
   - the header frame: band fill, padding, the bottom edge, a left column (an optional back control, the
     aside, the title) and a right-hand slot the window fills (the library's pickers);
   - the pager, its dead arrows (cover-grid D16) and its taps; the nav bar in its band from
     `NavBar.new{ where }`;
   - the gesture route in cover-grid's order, the window supplying its own tap and `hit`; swipes and page
     keys calling the window's page change; forwarding to the file manager's menu zones;
   - `onBookMetadataChanged` / `onInvalidateMetadataCache` calling the window's re-list; `onCloseWidget`'s
     shared part (the `shown` slot, the cover check's cancel);
   - the pending window for a book's close (build, take, drop for another size or variant), so `main.lua`
     asks the chrome rather than `Library` by name. The return record stays the library's shape here; the
     `routing` task adds the screen to it.
   - **One window at a time:** `LibraryChrome.shown` is the chrome window on screen; showing one closes the
     one shown and the home first. With only the library on the chrome this is the library's own rule today
     (cover-grid feature.md:126-127).
2. **`library.lua`** keeps what is the library's: the listing, `LibraryOrder` and its memory, the header's
   count, title and pickers, the page of `LibraryTiles`, its taps (`on_open`, `on_picker`), `Library.hit`.
   Module-level names other code or specs reach (`Library.shown`, `Library.show`, `Library.on_open`,
   `Library.on_picker`, `Library.return_to`) keep working, as fields or thin forwards, so no spec changes.
3. `main.lua` requires `library_chrome` at load (`spec/unit/main_requires_spec.lua`); `HOOKS.md` entries that
   name `library.lua` for a hook the chrome now holds name `library_chrome.lua`.
4. Draw the line by what the series and authors windows need (feature sections "Series", "Authors", "Book
   close"); anything only the library uses stays in `library.lua`. Where the split asks for a choice the spec
   does not settle (the header's right-hand slot's shape, how a window hands the chrome its page count),
   take the simplest that fits both, and say so in the PR.

## Surfaces

- `kopanda.koplugin/library_chrome.lua` (new), `kopanda.koplugin/library.lua`, `kopanda.koplugin/main.lua`,
  `kopanda.koplugin/HOOKS.md`; `kopanda.koplugin/library_pickers.lua` only if it reaches a moved name.
- No spec file changes, other than `spec/unit/main_requires_spec.lua` and `hooks_doc_spec.lua` passing as
  they are.

## Tests

No new behaviour, so no new failing test first: the net is cover-grid's, run before and after the move, and it
must pass with no case changed or weakened (C10, C11, C12):

- `bin/check spec/unit/library_screen_spec.lua spec/unit/library_gestures_spec.lua
  spec/unit/library_lifecycle_spec.lua spec/unit/library_pickers_spec.lua spec/unit/library_tiles_spec.lua
  spec/unit/library_order_spec.lua spec/unit/nav_bar_spec.lua spec/unit/fm_nav_spec.lua
  spec/unit/failsafe_spec.lua spec/unit/gesture_routing_spec.lua spec/unit/hold_routing_spec.lua
  spec/unit/prebuild_spec.lua spec/unit/hooks_doc_spec.lua spec/unit/main_requires_spec.lua`.
- `bin/check spec/emulator/library_golden_spec.lua` with no `KOPANDA_UPDATE_GOLDENS`: the library goldens
  match without regeneration (C10).
- The whole `bin/check` (C14, C15).
- Scope check: confirm each file above exists on `main` before starting; a missing one means cover-grid
  named it differently, so use its name and say so in the PR.

## Edge cases

- A behaviour cover-grid's tests do not cover (a code path with no case) still moves unchanged; the review
  traces old against new for those paths (AGENTS.md: a pure refactor gets one review pass tracing behaviour).
- Cover-grid's code may already factor some parts (the forward step it shares with the home,
  `home_gestures.lua`, screen task.md:24-25); reuse it, do not move it twice.
- A spec that reaches `Library`'s internals by a name the move takes away: keep the name as a forward rather
  than editing the spec; if that is impossible without a contortion, stop and bring it to the lead.
- `library.lua` passing 500 lines before the move is a reason for it, not a second refactor: move only the
  chrome.
