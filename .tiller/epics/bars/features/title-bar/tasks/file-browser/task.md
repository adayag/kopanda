# The title bar in KOReader's file browser: the one-shot swap, its pickers, failsafe and tripwire

## Approach

KoPanda's bar put in place of KOReader's for the file manager's one `TitleBar:new` call, inside nav-bar's
`setupLayout` wrapper, with the pickers' menus, every step failing safe, an upgrade tripwire and the
`HOOKS.md` record. Starts after `bars/title-bar/bar`. Repo lines on `main` at `6443f03`, and nav-bar's
`fm_nav.lua` as nav-bar's `file-browser` task (T-9h0fhs) leaves it; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The feature's "What KOReader does with the file manager's bar",
"The seam", "Failure behaviour" and "Upgrade tripwire and HOOKS.md" are the spec.

1. **The tripwire first** (C5), in `spec/unit/fm_title_bar_spec.lua`, against KOReader's own function
   (`harness.fm_setup_layout`, nav-bar task `file-browser` step 2) before anything is swapped:
   `rawget(require("ui/widget/titlebar"), "new")` is nil; with `TitleBar.new` and `FileChooser.new` set to
   recording pass-throughs for one call of the original on `harness.show_fm()`'s file manager (and put back
   after), the first `TitleBar.new` call precedes the first `FileChooser.new` and its attributes carry
   `left_icon = "home"`, `right_icon = "plus"`, and functions `right_icon_tap_callback` and
   `left_icon_hold_callback` (`frontend/apps/filemanager/filemanager.lua:118-136`, `:131`, `:134`);
   afterwards `fm.title_bar` is the bar that call returned and `fm.file_chooser.title_bar` the same table (`:150`, `frontend/ui/widget/menu.lua:721`); the
   chooser's `available_height` is its inner height less `fm.title_bar:getHeight()` and its page footer
   (`menu.lua:666-677`). It passes today and must keep passing; its comment says what to do when it fails:
   re-read the lines `HOOKS.md` cites, then change the pin.
2. **`kopanda.koplugin/fm_nav.lua`**, nav-bar's wrapper (nav-bar feature.md:236-246):
   - **Before:** nav-bar's step already reads `Looks.active()` in its `pcall` for the band (nav-bar task
     `file-browser` step 3, its lines 28-29; nav-bar feature.md:239); that look is kept in a local and
     passed to the one-shot, so the band and the bar share one read. No second `pcall`: a raising look is
     nav-bar's failure, the original alone (nav-bar feature.md:295).
   - **During:** beside `FileChooser.height`, `TitleBar.new` set to the one-shot of the feature's seam step 2:
     it restores `TitleBar.new` to the value `rawget` read before (nil), copies the attributes table
     shallowly (so `left_icon_hold_callback`, `right_icon_tap_callback` and `show_parent` come with it),
     adds `fm`, `look`, `on_sort` and `on_status`, and returns `KoTitleBar:new(copy)` under
     `pcall`, else logs and returns `TitleBar.new(class, attrs, ...)`, KOReader's own. After the original
     returns or raises, `TitleBar.new` is restored again (a no-op when the call came), on both paths, before
     the original's error is re-raised with `error(err, 0)`.
   - **`FmNav.open_sort(fm)`** and **`FmNav.open_status(fm)`**, the bar's `on_sort` and `on_status` (closures
     over `fm`): each in `pcall`, builds the tab from `fm.menu:getSortingMenuTable().sub_item_table` or
     `fm.menu:getShowFilterMenuTable().sub_item_table` (`frontend/apps/filemanager/filemanagermenu.lua:873-957`),
     sets its `icon = "appbar.filebrowser"` (`:36`), and shows a `TouchMenu` with that one tab in a full-screen
     `CenterContainer`, as `SettingsMenu.open` does (`settings_menu.lua:18-35`). A failure is logged and shows
     nothing.
3. **`HOOKS.md`:** a section "The file browser's title bar: `TitleBar.new` inside `setupLayout`, its consumers
   and the sort and status menus" with every citation the feature's "Upgrade tripwire and HOOKS.md" lists,
   what KoPanda relies on in each, that the bar re-reads its state at paint and why (the feature's D11), and
   that the tripwire in `fm_title_bar_spec.lua` guards it. The nav-bar section's `setupLayout` entry gains a
   line pointing here.

## Surfaces

`kopanda.koplugin/fm_nav.lua`, `kopanda.koplugin/HOOKS.md`. Specs: `spec/unit/fm_title_bar_spec.lua` (new),
`spec/unit/failsafe_spec.lua`.

## Tests

Written first and run failing. Read `bin/check` output through a filter that drops KOReader's
library-loading chatter and the per-test lines.

- `fm_title_bar_spec.lua`:
  - **Tripwire** (C5): step 1; and with KoPanda loaded, after `harness.show_fm()` `fm.title_bar` is a
    `KoTitleBar` (`getmetatable(fm.title_bar) == KoTitleBar`, `frontend/ui/widget/widget.lua:39-47`).
  - **In place** (C4): `fm.title_bar == fm.file_chooser.title_bar`; the chooser's `available_height` is its
    inner height less the bar's height and its page footer; `rawget(TitleBar, "new")` is nil after the layout.
  - **State** (C4), on a scratch copy of the fixture library with a subfolder, painting the file manager to a
    buffer after each step: `changeToPath` to the subfolder shows its name and count; `fm:onHome()` with
    `home_dir` stored as `ffiUtil.realpath` of the scratch folder shows Library (`changeToPath` realpaths
    the path it shows, `frontend/ui/widget/filechooser.lua:341-348`, and macOS's temp folders resolve
    through `/private`, so a raw temp path would differ from the chooser's; the bar compares realpaths
    anyway, `bar`'s `state()`); `fm:onSetSortBy("access")` shows Recent
    (`filemanager.lua:1685-1690`); the status menu's "finished" item picked with no finished book shows
    Finished and No books.
  - **Pickers** (C4): a tap at the sort picker's centre through `UIManager:sendEvent` shows a `TouchMenu`
    (`harness.top()[1]`: `harness.top()` is the full-screen `CenterContainer`, the `TouchMenu` its first
    child, as `SettingsMenu.open` builds it, `kopanda.koplugin/settings_menu.lua:23-29`) whose items' texts are
    `getSortingMenuTable().sub_item_table`'s in order; selecting
    "last read date" through the menu's `onMenuSelect` stores `collate = "access"` and the next paint's sort
    label is Recent; the status picker likewise with KOReader's five status items; with `fm.menu` stubbed to
    raise, the tap is logged and nothing is shown.
  - **Plus and select mode** (C4): a tap on the plus shows KOReader's plus dialog (`fm.plus_dialog`,
    `filemanager.lua:778-786`); `fm:onToggleSelectMode()` shows the check and a second call the plus
    (`:514-530`).
  - **Folder menu** (C4): with `fm.onShowFolderMenu` wrapped in a counting spy that calls through, a hold
    at the title's centre sent through `UIManager:sendEvent` calls it once and shows a `ButtonDialog`
    (`harness.top()`, `frontend/apps/filemanager/filemanager.lua:1430-1437`); its `anchor()` returns
    `fm.title_bar.left_button.image.dimen`, the title column's box; after a paint the dialog's top
    (`dialog.movable.dimen.y`) is at or below that box's bottom
    (`frontend/ui/widget/container/movablecontainer.lua:152-161`, `:195-198`); the `hold_release` that
    follows is consumed; running one of its buttons' callbacks changes the chooser's path
    (`filemanager.lua:1358-1361`).
  - **Re-layout** (C4): `fm:reinit()`, `fm:onSetRotationMode` to landscape and back, and a look change through
    the settings menu's look submenu (nav-bar's `FmNav.relayout()`) each leave a `KoTitleBar` at the new width
    and in the new look.
  - **Refused** (C4): with `Guards.refused` stubbed true before `load`, `fm.title_bar` is KOReader's
    `TitleBar` after `show_fm`.
  - **Other title bars** (C6): after KoPanda's layout, `rawget(TitleBar, "new")` is nil; a
    `Menu:new{ title = "T", item_table = {} }`, a `PathChooser:new{ path = harness.library }`, History's list
    (`fm.history:onShowHist()`, `frontend/apps/filemanager/filemanagerhistory.lua:59`, its
    `booklist_menu`, `:61`) and Collections' (`fm.collections:onShowColl()`,
    `frontend/apps/filemanager/filemanagercollection.lua:76`, its `booklist_menu`, `:81`; both modules
    registered at `filemanager.lua:405`, `:407`) each have a `title_bar` whose metatable is KOReader's
    `TitleBar`; after `harness.open_reader(book)` a `Menu` built in the reader does too.
- `failsafe_spec.lua` (C7), in the file's "leaves the file manager usable" form, each with the file manager on
  top and handling a tap afterwards: `Looks.active` raising during the layout (KOReader's `TitleBar`, no band:
  nav-bar's before step runs the original alone); `KoTitleBar.new` raising (KOReader's bar with its Home
  button's `left_button`); the original `setupLayout` raising (re-raised unchanged, `rawget(TitleBar, "new")`
  and `rawget(FileChooser, "height")` nil); `KoTitleBar.state` raising at paint (logged once over two paints);
  the paint raising (logged once, the chooser's rows still painted); `handle` raising on a tap (logged, the
  tap not consumed); the kept hold callback raising on a title hold (logged, the hold not consumed); a
  picker's menu raising (logged, nothing shown).
- `hooks_doc_spec.lua` and `main_requires_spec.lua` (C8) pass with the new section in.
- nav-bar's `fm_nav_spec.lua` runs unchanged and passes: the band, the bar, the settled signal and its
  tripwire (`fm[1]`'s only child is the chooser) don't depend on which title bar the chooser has.

## Edge cases

- **SimpleUI or another shell enabled:** KoPanda is refused (`main.lua:78-85`) and never installs, so no swap;
  SimpleUI's own one-shot (`screens/sui_titlebar.lua:1344-1368` at `61b71da`) stands alone.
- **A second `TitleBar:new` inside the same call** (none at `e1fe1ac`, the tripwire's first-call case) is
  KOReader's own: the one-shot restores `TitleBar.new` before it builds.
- **`setupLayout` raising before its bar is built:** the one-shot never ran; the restore after the call puts
  `TitleBar.new` back anyway.
- **The cached main menu's reverse and mixed items** may hold a chooser from before a re-layout
  (`filemanagermenu.lua:130`, `:1120-1129`); the pickers never use them (D5). That quirk is KOReader's own and
  is left alone.
- **Select mode across a re-layout:** `setupLayout` passes `right_icon = "check"` while `selected_files` is set
  (`filemanager.lua:132`), which the bar starts from.
- **The touch lock:** the bar's listener is an `InputContainer`, silenced as nav-bar's bar is
  (`frontend/ui/widget/container/inputcontainer.lua:299-309`).
- **CoverBrowser** reads the bar's `dimen.h` at every re-measure (`plugins/coverbrowser.koplugin/listmenu.lua:836-845`,
  `mosaicmenu.lua:782-803`); the bar's height never changes (D8), so its rows stay put between refreshes.
