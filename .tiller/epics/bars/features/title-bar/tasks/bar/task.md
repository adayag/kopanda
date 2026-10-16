# The title bar widget: its tokens in both looks, the plus icon and its paint

## Approach

KoPanda's bar as a widget that reads a real file chooser and paints the look, with its tokens and the plus
icon, and nothing put into KOReader's file manager yet. Starts once `nav-bar/nav-bar` is done (the
feature's prerequisite). Repo lines on `main` at `6443f03`; KOReader relative to `~/Projects/kodev/koreader/`
at `e1fe1ac`. The feature's "The bar", "Tokens" and "Geometry" are the spec.

1. **Open fact F1 first: the down mark.** In a scratch case under the harness at the Colorsoft, set
   `Typeset.line` for Editorial's `title_bar_sort` part and Diner's on "▾" (U+25BE) and on U+E000, paint each
   into a `Blitbuffer` and compare. Candidates: (a) the two differ in both looks, so "▾" renders; (b) they
   match in one look or both, so it is the missing-glyph box. For (a) the mark is the text " ▾" after the
   label; for (b) it is the registry's `chevron_down`, tinted in the label's colour at the label line's height
   after a space's width, in both looks. Record which in the module's header comment and the PR.
2. **Tokens.** In `looks/editorial.lua` and `looks/diner.lua`, a `title_bar` block after `nav` and the parts
   `type.title_bar_count`, `type.title_bar_title`, `type.title_bar_sort` and `type.title_bar_status`, with the
   feature's two tables, each line's comment naming its board line (Library:17-27, LibraryC:19-27) or why it
   has none, as the look files do (`looks/diner.lua:383-417`). Numbers, booleans, roles and faces only, so
   `looks_spec.lua`'s string rule (`spec/unit/looks_spec.lua:185-212`) needs no new marker.
3. **The plus icon.** Lucide's `plus` as `icons/plus.svg`, stroke 2 and black like its siblings
   (`spec/unit/icons_spec.lua:88-130`), and a registry entry `{ id = "plus", label = "Add", used_in =
   { "title bar" }, file = "icons/plus.svg" }` with the Lucide comment the others carry (`icons.lua:56-61`);
   `check` gains `"title bar"` in its `used_in` (`icons.lua:55`). Then `npm run catalog` in `studio/` rewrites
   `studio/src/catalog.json`, and `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/swatch_golden_spec.lua`
   regenerates the two swatch goldens; open each (`open <png>`) and check only the new cell differs.
4. **`kopanda.koplugin/title_bar.lua`** (`KoTitleBar = TitleBar:extend{ ... }`), requiring at load
   KOReader's `ui/widget/titlebar`, `ui/widget/container/inputcontainer`, `ui/gesturerange`, `ui/geometry`,
   `ui/uimanager`, `ui/widget/booklist`, `ui/widget/filechooser`, `apps/filemanager/filemanagerutil`,
   `ffi/util`, `util`, `logger`, and KoPanda's `looks`, `typeset`, `icons`, `tinted_icon` and `paint`:
   - `KoTitleBar:init()`, replacing `TitleBar:init` (`frontend/ui/widget/titlebar.lua:86-393`) entirely: the
     width (`self.width` or the screen's, as `:96-98`), `KoTitleBar.height(look, screen)` (below), the
     `dimen` `{ x = 0, y = 0, w, h }`, `has_left_icon = false`, `has_right_icon = true`, the right icon id from
     `self.right_icon`, `left_button = { image = { dimen = Geom:new{} } }`, and the one listening
     `InputContainer` child with `ges_events` `tap`, `hold` and `hold_release` (feature, "Taps and holds"),
     each `GestureRange` built with `range = function() return self.dimen end`, read at match time
     (`frontend/ui/gesturerange.lua:25-39`, the idiom its comment names at `:28`). Then
     `OverlapGroup.init(self)` so `_size` and `dimen` agree (`frontend/ui/widget/overlapgroup.lua:42-56`); a
     range over `self.dimen` itself would go stale, since that init replaces `self.dimen` with a new `Geom`
     (`:55`).
   - `KoTitleBar.height(look, screen)`: the feature's formula, lengths through `screen:scaleBySize`, lines
     from `Typeset.line(part, sample, screen:getWidth(), { look = look, variant = "day" })` with no
     `text_size` (D8); the variant is only there because `Typeset.line` colours from the palette
     (`typeset.lua:51`).
   - `bar:state()`: `{ variant, title, count, sort, status, icon }` read from `self.fm.file_chooser` (nil-safe:
     no chooser, no count) and `Looks.variant()`, by the feature's rules: the home test with the chooser's
     path and `filemanagerutil.getHomeFolder()` (`filemanagerutil.lua:25-27`) each through
     `ffiUtil.realpath`, the raw string when that is nil, then compared as `filemanagerutil.lua:33` does; the
     folder name from `util.splitFilePathName` as `filechooser.lua:327-329` takes it, except that the title
     is "/" when the path is "/" (`splitFilePathName("/")` gives `"/", ""`, `frontend/util.lua:1017-1021`,
     an empty name); the count over `item_table` entries with `is_file`
     (`filechooser.lua:174`), the sort label from `self.fm.file_chooser:getCollate()`'s id
     (`filechooser.lua:206-215`) through `KoTitleBar.SORT_LABELS`, the status label from
     `FileChooser.show_filter.status` in KOReader's order (`filemanagermenu.lua:875`) through
     `BookList.getBookStatusString` (`booklist.lua:386-389`).
   - `bar:build(state)`: the count, title and picker lines, chips' boxes, the icon and the tap areas, in the
     feature's geometry; it keeps the boxes in bar-relative px.
   - `paintTo(bb, x, y)`: sets `dimen.x`/`y` as `TitleBar:paintTo` does (`titlebar.lua:395-402`); reads
     `state()` in `pcall` and rebuilds when it differs from the built one (a failure logged once, the last
     build kept; with no build yet, it paints the fill and edge only, in `Looks.variant()`'s palette or day
     if that raises too); then paints in the feature's drawing order in `pcall` (a failure logged once);
     sets `left_button.image.dimen`'s fields in place to the title column's box on screen: the count and
     title lines' left edge and width, from the bar's top to the title line's bottom (feature, D3).
   - `bar:handle(ges)`: the gesture's position against the areas. A `tap`: sort → `self.on_sort()`,
     status → `self.on_status()`, plus → `self.right_icon_tap_callback()`, each true; the title area false.
     A `hold` in the title area: `self.left_icon_hold_callback()`, a flag set, true; anywhere else false. A
     `hold_release`: true and the flag cleared when the flag is set, else false, as `IconButton` pairs them
     (`frontend/ui/widget/iconbutton.lua:146-170`). The listener calls it in `pcall`; an error is logged and
     the gesture returns false.
   - `getHeight`, `getSize`, `setTitle`, `setSubTitle`, `setLeftIcon`, `setRightIcon`,
     `generateHorizontalLayout`, `generateVerticalLayout` as the feature's interface says; the dirty marks are
     `UIManager:setDirty(self.show_parent, "ui", self.dimen)`, as KOReader's (`titlebar.lua:443-468`).
5. **`main.lua`** requires `title_bar` with the other modules (`main.lua:22-62`).
6. **`HOOKS.md`:** each KOReader module `title_bar` requires that `HOOKS.md` doesn't name yet goes under
   "Widget and support modules" (`HOOKS.md:1079`) with its `file:line`. The swap's section is
   `file-browser`'s.

## Surfaces

`kopanda.koplugin/looks/editorial.lua`, `kopanda.koplugin/looks/diner.lua`, `kopanda.koplugin/title_bar.lua`
(new), `kopanda.koplugin/icons.lua`, `kopanda.koplugin/icons/plus.svg` (new), `kopanda.koplugin/main.lua` (the
require only), `kopanda.koplugin/HOOKS.md`, `studio/src/catalog.json` (regenerated),
`spec/goldens/swatch-colorsoft.{png,json}`, `spec/goldens/swatch-paperwhite.{png,json}` (regenerated). Specs:
`spec/unit/title_bar_spec.lua` (new), `spec/unit/looks_spec.lua`, `spec/unit/icons_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `looks_spec.lua` (C1): the `title_bar` paths join the identical-paths list (`:83-125`); "give the title bar
  block and parts the boards' values" per look, as the editor and nav cases do, asserting every value of the
  feature's two tables. The role, face and type rules (`:185-233`) then cover the new tokens.
- `icons_spec.lua` (C2): the registered-ids list (`:37-49`) gains `plus`; a case that `plus` and `check` have
  `"title bar"` in `used_in`; the stroke, colour and render cases (`:88-130`) cover the new file.
  `studio_catalog_spec.lua` passes on the regenerated catalog.
- `title_bar_spec.lua` (C3), in the harness, the bar built against `harness.show_fm(dir)` on a scratch copy of
  the fixture library with a subfolder, with `on_sort`, `on_status` and `right_icon_tap_callback` spies:
  - **Height:** per look equal to the formula from the tokens and measured lines, at the unit screen and in
    `harness.at_colorsoft`; the same with `text_size` stored as small, medium and large; `getHeight()`,
    `dimen.h` and `getSize().h` equal.
  - **Title:** "Library" with the chooser at the home folder, with `home_dir` stored as the folder, as it
    plus "/" and as a symlink to it made in the scratch area; the subfolder's name after `changeToPath`; "/" at the root.
  - **Count:** the scratch folder's three books with the subfolder and the go-up entry not counted; "3 books"
    / "3 books on the shelf", uppercase in Editorial; one book "1 book"; an empty folder "No books"; with
    `FileChooser.show_filter.status = { complete = true }` and one book's sidecar marked complete
    (`BookList.resetBookInfoCache` between), one.
  - **Labels:** each collate id of `BookList.collates` to its short label, `access` to Recent; a stub id to its
    text; no filter All; `{ reading = true }` Reading; `{ reading = true, abandoned = true }` "Reading +1".
  - **At paint:** a second paint with nothing changed rebuilds nothing (a spy on `build`); after a sort change
    one paint rebuilds once; with `state` stubbed to raise before the first paint, the paint logs once,
    raises nothing and leaves the fill colour above the edge and the edge colour at the bottom, with no
    line drawn.
  - **Paint:** into a `Blitbuffer` at the Colorsoft, sample pixels: Editorial's 1 px ink edge at the bottom and
    paper above it, no chip boxes; Diner's mustard band, the 4 px ink edge, the sort chip's paper and the
    status chip's pink inside 2 px outline-coloured borders; once in night (`Looks.palette`'s inverted night
    palette) and once in grey.
  - **Taps:** at each area's centre the matching spy runs once and `handle` returns true; on the title and the
    count it returns false and runs nothing; a `Gesture` event sent to the bar reaches `handle` through the
    listener, also after the bar has been painted at a non-zero position (the range reads the live
    `dimen`); a spy that raises is logged and `handle` returns false.
  - **Holds:** with a `left_icon_hold_callback` spy, a hold at the title's centre and one at the count's each
    run the spy once and return true, and the `hold_release` after each returns true; holds on the sort
    picker, the status picker and the plus return false and run nothing, and their releases return false; a
    raising hold spy is logged and `handle` returns false.
  - **Interface:** `setRightIcon("check")` then `"plus"` switch the icon; `setTitle`/`setSubTitle` change no
    line and mark the bar dirty unless `no_refresh` (a spy on `UIManager.setDirty`); `setLeftIcon` does
    nothing; both generators return `{}`; after a paint `left_button.image.dimen` is the title column's
    box, the same table as before the paint.
- `night_mode_spec.lua` runs unchanged: its scan for the word `palettes` covers `title_bar.lua`.
- `swatch_spec.lua`'s fit case (`:370-383`) and `swatch_golden_spec.lua` pass with the new cell (C10).
- `hooks_doc_spec.lua` and `main_requires_spec.lua` pass with `title_bar` required and its modules named.

## Edge cases

- A face that fails to load: `Typeset` raises (`typeset.lua:22-30`); `KoTitleBar.height` and `new` raise to
  the caller, which `file-browser` guards (KOReader's bar).
- A long folder name: cut by `Typeset.line`'s `max_width`; the pickers keep their width.
- A file the chooser lists from an unreadable folder's remembered contents has no `is_file`
  (`filechooser.lua:146-158`: the remembered items are built at `:355-363` with no `is_file`, the dummy
  item at `:148` through `getListItem` with no `mode`, `:168`); it is not counted. Flat view counts every file it shows.
- With `show_unsupported` on, every listed file counts as a book: the count is what the chooser shows.
- The swatch gains a row if the new cell overflows the last one; `swatch_spec.lua`'s fit case says whether it
  still fits. If it doesn't, stop and bring the layout choice to the lead.
- No timers, no animation: the bar reads and paints only when KOReader paints the file manager.
