# Quick settings from the top menu

2026-10-18. The owner could not change night mode or brightness while reading: the
quick-settings sheet opens only from the home's launcher and the nav bar's Settings hold,
and nothing of KoPanda runs inside the reader. This adds one way in from KOReader's own top
menu, in the reader and the file browser alike, as SimpleUI's quick-settings tab does.

The design doc (`.tiller/design/2026-10-13-kopanda-design.md` §"Stages") lists the reader as
out of scope. This is the owner's deliberate extension: one tab in the reader's top menu,
reusing the sheet. Everything else in the reader (status bars, page browser, reader menus,
the bottom config dialog) stays KOReader's.

## What the owner sees

Tap the top of the page (or swipe down from the top eighth, KOReader's menu gesture,
`frontend/apps/reader/modules/readermenu.lua:120-145`, `defaults.lua:59-60`). The menu's tab
bar carries one more tab, just before Main: KOReader's `appbar.contrast` icon, the half-filled
circle. Tapping it closes the menu and opens the quick-settings sheet over the page: battery,
brightness and warmth bars, the six cells. Brightness, warmth, Night, Wi-Fi and rotation lock
act with the sheet open; Sync books, Screenshot and Sleep close it first. A tap outside the
sheet, KOReader's Back or the Back key returns to the page.

The file browser's top menu gets the same tab, just before its Main, opening the sheet over the
file browser or the home, whichever is up.

Captures from the emulator, taken with a scratch userpatch that added the tab to the real
reader menu (`2026-10-18-menu-quick-settings/mock-scenario.lua`):

- `2026-10-18-menu-quick-settings/reader-menu-tab.png`: the reader's top menu with the tab.
- `2026-10-18-menu-quick-settings/file-browser-menu-tab.png`: the file browser's top menu over
  the home with the tab (`mock-scenario-file-browser.lua`).
- `2026-10-18-menu-quick-settings/sheet-over-page-diner.png`: the sheet over Frankenstein's
  title page, Diner.
- `2026-10-18-menu-quick-settings/sheet-over-page-editorial.png`: the same, Editorial.

The captures show the tab last; the review moved it before Main (see Decisions).

Decisions taken with the owner:

- Entry point: a tab in KOReader's top menu, not a reader gesture bound to a dispatcher action
  and not a patch into the reader's gesture zones.
- Position: just before Main, decided 2026-10-18 after review, so Main stays the far-right tab.
  A menu swipe starting in the right third of the screen opens the last tab
  (`readermenu.lua:466-482`, `frontend/apps/filemanager/filemanagermenu.lua:1083-1100`), and
  TouchMenu turns an opening index on a `remember = false` tab into tab 1
  (`frontend/ui/widget/touchmenu.lua:458-462`, from `:668`), so a last tab made that swipe open
  tab 1. The tab keeps `remember = false`: remembered, its callback would run inside
  TouchMenu's init and open the sheet under the menu. The insert shifts no remembered tab
  index: the reader keeps one per book (`readermenu.lua:547-553`, in the document's sidecar),
  the file browser one globally (`filemanagermenu.lua:1007-1009`), and KoPanda leaves both
  alone.
- Icon: KOReader's `appbar.contrast`. The tab bar takes icon names only and resolves them in
  KOReader's own icon folders plus a user `icons/` folder under KOReader's data directory
  (`frontend/ui/widget/iconwidget.lua:20-29`) read at launch, so a KoPanda icon would show only from the
  second start after install. The owner rejected three panda drafts; no icon ships.
- The sheet, not SimpleUI's buttons-inside-the-menu panel: no patch of TouchMenu.

## What changes

- **`menu_entries.lua`** generalises the Home-tab helper. Today it knows one tab
  (`kopanda_home`), one order module (`ui/elements/filemanager_menu_order`), one menu-sorter
  name (`filemanager`) and one position (index 2, with the one-time shift of the saved
  index). It takes a spec: tab id, order module, sorter name and position (2 or before Main).
  Three tabs use it: Home in the file browser (unchanged), quick settings in the file browser
  (before Main), quick settings in the reader (before Main, order module
  `ui/elements/reader_menu_order`, sorter name `reader`). A before-Main position skips the
  saved-index shift. With a user's own
  top-level order list, a tab appears only when that list names it, as today.
- **`main.lua`** `addToMainMenu` adds `kopanda_quick_settings` with the icon, `remember =
  false` and a guarded callback: close the menu (`onCloseFileManagerMenu` in the file
  browser, `onTapCloseMenu` in the reader, `readermenu.lua:517`), then open the sheet at once
  with a paint-clock stamp, as the Home tab acts. In the reader the sheet gets a no-op `beneath`.
- **`quick_settings.lua`** passes an opener's `beneath` through to the sheet as the nav bar
  already does; nothing else changes. The sheet's failure path closes `beneath`, so in the
  reader it closes nothing and the page stays.
- **`HOOKS.md`** gains the reader-menu lines now read: the default tab buttons
  (`readermenu.lua:55-80`), the one-time build and cache of the tab table (`:396-400`,
  `:330-340`), the per-book tab index (`:548-552`), the close functions (`:445-451`,
  `:517-520`), the order table and its empty file-browser entry the tab entry imitates
  (`frontend/ui/elements/reader_menu_order.lua:4-12`, `:228`), and the icon lookup.
- **Design doc** out-of-scope line gets one clause naming the tab.

No schema key. No setting. No studio change. No new icon.

## Tests

Busted unit specs on the emulator's LuaJIT, written before the code:

1. `spec/unit/menu_tabs_spec.lua` (new, or the existing entry-point specs extended): a plugin
   instance with a document gets `kopanda_quick_settings` just before Main in the reader order's
   buttons, with the icon, `remember = false` and an empty order entry; a file-browser instance
   gets it just before Main in the file-browser order, Home still at 2; a user's own order list without the tab
   yields no tab and is not written; the callback closes the menu and shows one sheet named
   `quick_settings` while the reader (or file browser) stays shown; an opener that raises logs
   with the tab's name and leaves the menu usable.
2. `spec/unit/quick_settings_spec.lua`: shown over a reader with a no-op `beneath`, a sheet
   failure closes the sheet and nothing else.
3. The existing Home-tab specs (entry_points, guards, failsafe, gesture_routing,
   home_over_window, home_lifecycle, prebuild, push_notice, shelf_lifecycle) keep passing on
   the generalised helper.
4. `spec/unit/hooks_doc_spec.lua` on the new HOOKS.md lines.

No golden: no board draws the sheet over a page. The owner judges it on the emulator and the
Kindle. Gate: `bin/check --unit`, plus `bin/check spec/emulator/quick_settings_golden_spec.lua`
since the sheet's paint budget covers it.

## Failure handling

Every path wrapped, as the plugin's rule says: a failure is logged with where it happened
(the tab's name) and KOReader's menu and page are left as they were. A tab that cannot be
added leaves the menu without it.
