# Focused mode (2026-11-02)

Decided on 2026-11-02 with the owner, for the older readers in the household and for everyone else
on the owner's devices: KOReader's menus confuse a reader who only wants to read. Focused mode is one
setting, on by default, that puts a simple KoPanda panel where KOReader's reader menus open, closes the
shell's remaining doors into KOReader's own screens, and keeps one admin route, a hold, for the owner's
work (Storefront app updates, KoPanda updates, KOReader's settings).

ZenOS's Zen mode (xZenLabs/zen-os v4.2.0, a2d72301, GPL-3.0, read and not copied) was the starting point.
It filters KOReader's top-menu tabs by name (`modules/menu/patches/zen_mode.lua:14-117`) and moves
KOReader's menus one level down under its own settings. Focused mode replaces the menus instead of
filtering them: the reader gets a panel of big controls, not a shorter list of KOReader's tabs.

## Facts

- In the reader, a top tap or a swipe down opens the top menu and the bottom config panel together
  (`frontend/apps/reader/modules/readermenu.lua:484-503`, `show_bottom_menu` on by default). A bottom tap
  or a swipe up opens the config panel alone (`readerconfig.lua:154-166`). The tap zones are
  `readermenu_tap`, `readermenu_swipe` and their `_ext` twins (`readermenu.lua:90-170`), and
  `readerconfigmenu_tap` and `readerconfigmenu_swipe` (`readerconfig.lua:57-130`).
- KOReader's full reader menu opens by `ReaderMenu:onShowMenu` (`readermenu.lua:396`). The reader menu's
  folder icon closes the book and shows the file manager (`readermenu.lua:65-73`). KoPanda then puts the
  home over it (`kopanda.koplugin/main.lua:359`, `:399`).
- Text size: `IncreaseFontSize` and `DecreaseFontSize` (`readerfont.lua:400-411`), rolling documents only
  (`frontend/dispatcher.lua:245-246`).
- Contrast: EPUBs have `font_gamma`, labelled Contrast, values `{10, 15, 25, 30, 36, 43, 49, 56}`, default 15
  (`frontend/ui/data/creoptions.lua:571-576`). PDFs and comics have `contrast`, values
  `{0.8, 1.0, 1.5, 2.0, 4.0, 6.0, 10.0, 50.0}` (`frontend/ui/data/koptoptions.lua:489-494`).
- Night mode: `ToggleNightMode` (`dispatcher.lua:138`). KoPanda's quick settings already reads and toggles
  it (`kopanda.koplugin/quick_settings.lua:107-121`).
- Light: the quick settings' brightness and warmth (`quick_settings.lua:135-153`).
- Bookmarks: `ReaderBookmark:onToggleBookmark` (`readerbookmark.lua:347`), `isPageBookmarked` (`:403`),
  `getBookmarkPageString` (`:628`).
- Chapters: `ReaderToc:fillToc` (`readertoc.lua:160`), `getTocIndexByPage` (`:383`), `getMaxDepth` (`:482`).
- Outside the reader, a top-edge tap on the home or the library goes to KOReader's file-manager menu
  (`kopanda.koplugin/home_gestures.lua:131-144`). A tap on an empty spot closes the home onto the file
  browser (`home_gestures.lua:176-181`). The Settings tab opens KoPanda's settings (`nav_bar.lua:87`), and
  a hold on it opens the quick-settings sheet (`nav_bar.lua:209-235`).
- A file held in the file browser gets KOReader's file dialog, Delete among its buttons
  (`frontend/apps/filemanager/filemanager.lua:337`). KOReader already has a Lock home folder setting
  (`filemanagermenu.lua:356-359`), enforced in the chooser (`frontend/ui/widget/filechooser.lua:268`, `:409`).
- KoPanda's settings screen shows only schema rows (`kopanda.koplugin/settings_menu.lua:17-25`). Check for
  update lives only in Tools › KoPanda › Studio (`studio_menu.lua:243-274`).
- Storefront (ultimatejimmy/storefront.koplugin, 228de36, plugin name `storefront`) adds one Tools entry
  (`storefront.koplugin/main.lua:12014-12022`) and registers the dispatcher action `storefront_open`
  (`:12032`). KoPanda's launcher already checks that a plugin's dispatcher action is registered before
  offering it (`launcher_entries.lua:63-66`).
- A sheet closes before running a tapped row (`kopanda.koplugin/sheet.lua:295-300`); a tap in a body's area
  runs it and keeps the sheet open (`:288-293`), which is how quick settings' − / + stay open
  (`quick_settings.lua:270-351`). A hold anywhere on the panel outside a body area runs the spec's hold
  (`sheet.lua:316-331`). A sheet sits at the screen's bottom (`sheet_layout.lua:433`) and leaves out rows
  that don't fit, offering More when the spec asks for it (`sheet_layout.lua:292-340`).
- The reader's footer takes the bottom tap before the config menu: `readerfooter_tap` overrides
  `readerconfigmenu_tap` and cycles the footer's mode, and `readerfooter_hold` opens its menu
  (`frontend/apps/reader/modules/readerfooter.lua:903-926`).
- Font size changes show KOReader's "Increasing font size…" notification (`readerfont.lua:403`). A rolling
  document re-renders on every step, which takes seconds on a Paperwhite.

## Decisions

| Topic | Decision |
|---|---|
| The setting | `focused.on`, boolean, label "Focused mode", default `true`, in a new `focused` group. One key. |
| Reader: top and bottom | With the mode on, the four reader hooks (top tap, top swipe down, bottom tap, bottom swipe up) open the panel and nothing else. With it off, or when a wrap fails, KOReader's behaviour is unchanged. |
| Reader: the panel | A KoPanda sheet over the book, drawn in the look at one fixed size, Medium, whatever `text_size` is set to (Large left Diner too tall on the Colorsoft). Header: title · chapter, then page, percent, time and battery. Then, top to bottom: Night mode, Bookmark this page / Remove bookmark and Go to side by side; Text size A− / A+ (rolling documents only), Contrast − / + (KOReader's own steps, `font_gamma` or `contrast` by document type), Light − / + (warmth where the device has it); Home, the last row. |
| Reader: panel taps | Text size, Contrast, Light and Night mode act and the panel stays open, so the page re-renders in view and a mistaken Night tap can be undone. Bookmark, Go to and Home close the panel, then act. A second tap made while a font change renders is left to KOReader for now; a guard against it is queued for after release 1. |
| Reader: status bar | With the mode on, a tap on the reader's status bar opens the panel, as any bottom tap does, and a hold on it does nothing; neither reaches KOReader's status-bar menu (`readerfooter.lua:903-926`). Release 1 wraps both. |
| Reader: font notice | KOReader's "Increasing font size…" notice stays, so a tap shows it registered during the slow re-render. |
| Reader: header hint | The header always carries a hint line, "Hold here for all settings", under the title and chapter. It counts toward the fit. |
| Reader: panel holds | Only a hold on the header opens KOReader's full reader menu (`ReaderMenu:onShowMenu`). A hold on any row or − / + is consumed and does nothing, so a long press never leaves the mode. Release 1 adds a header-only hold to `sheet.lua`. |
| Reader: fit | At its fixed Medium size every row fits on the Paperwhite 7th gen's 1072x1448 and the Colorsoft's 1264x1680; no More. Home is the last row, nearest the hand (the owner's choice after the first captures, 2026-11-02); with nothing left out, the way out is always on screen. |
| Reader: other states | The panel lays out when it opens and closes on rotation. It stays open across sleep and resume. KOReader's own `activate_menu` choice (tap, swipe or both, `readermenu.lua:29`) still applies to the wrapped hooks. In a PDF or comic, Text size is hidden, Contrast steps `contrast`, Light as usual. |
| Reader: word hold | Unchanged: dictionary and highlight work as in KOReader. |
| Go to screen | A KoPanda window with two tabs, built like the series and authors screens (fixed-height rows, a page at a time, the ‹ › pager). Chapters: every level in one list, indented one step per level, no expand arrows, page at the right (in an EPUB the numbers move when the text size changes), the current chapter marked "you are here", opening on the pager page that holds it. Bookmarks: newest first, each with chapter and page; a hold offers Remove bookmark. A tap jumps and closes the screen. No chapters: it opens on Bookmarks. Neither: it says so. |
| Outside: top edge | A tap on the home's or the library's top edge opens the quick-settings sheet. A hold opens KOReader's file-manager menu (admin). |
| Outside: empty tap | A tap on an empty spot on the home stays on the home. |
| Outside: Settings tab | A tap opens the quick-settings sheet; a hold opens KoPanda's full settings. Swapped from today, with the mode on only. Quick settings also holds Sleep, Rotation lock and Wi-Fi (`quick_settings.lua:118-130`): more than "Settings" suggests, harmless. |
| Admin routes | Two rules. A hold on the top (the panel's header in a book, the top edge on the home and library) opens KOReader's menu for where you are. A hold on Settings opens KoPanda's settings, where Updates and Focused mode itself (to turn it off) live. |
| Outside: file browser | A hold on a book or folder opens KoPanda's book or folder sheet, the library's, in place of KOReader's file dialog. |
| Delete | The library's book sheet keeps Delete… behind KOReader's confirmation (`book_sheet.lua:287-303`), with the mode on too. The confirmation is the guard; it is KOReader's dialog, not scaled by `text_size`. |
| Outside: home folder | KOReader's own Lock home folder, turned on once per device by the owner. No code. |
| Updates section | KoPanda's settings screen gains an Updates section at its end: "KoPanda: Check for update" (the Studio menu's action) and "Apps (Storefront)", which runs `storefront_open` and is hidden when Storefront isn't loaded. Actions, not settings: no schema key. The owner's update route: hold Settings › Updates. |
| History | Unchanged: KOReader's own History list. Left for later. |

## First run

There is no migration marker and no welcome screen. The day release 1 lands, every device has the mode
on: the first top tap in a book opens the panel, and the owner finds KOReader's menu by the header's hint
or the admin routes above. Turning the mode off is Settings › Focused mode: a tap on Settings until
release 3 swaps the tab, a hold after.

## Releases

| # | Release | Size |
|---|---|---|
| 1 | The setting, the reader panel and its four hooks, the Updates section | 1.5–2 days |
| 2 | The Go to screen | 1–1.5 days |
| 3 | Outside the reader: top edge, empty tap, Settings tab, file browser holds | about 1 day |

Each is a release of its own, panel first. Release 2's Go to row opens KOReader's own table of contents
(`ShowToc`, `readertoc.lua:807`) until release 2 ships.

## Risks and assumptions

- A KoPanda sheet has only opened over the home and the library. Opening one over a book, and closing it
  back to the page without a full refresh, is the first thing release 1 proves on the emulator.
- Storefront's plugin name and action id are read from its main branch at 228de36. The version on the
  devices is unchecked; release 1 checks the dispatcher lists `storefront_open` on a device before relying
  on it, and the row stays hidden when it doesn't.
- The Gestures plugin may bind the same top or bottom zones to other actions on a device. Release 1 checks
  the order the reader's zones run in with the Gestures plugin loaded.

## Tests

Each written first and seen failing.

- Unit: the schema has `focused.on`, boolean, default true, in the `focused` group. The settings reader
  returns true with nothing stored.
- Unit: the panel's rows for a rolling document, for a paging document (no Text size) and with no
  frontlight (no Light). Contrast steps through the document type's own values and stops at each end.
- Unit: the Updates section lists Storefront only when its action is registered.
- Unit (release 2): the chapter list flattens a nested table of contents with each row's depth, marks the
  chapter holding the current page and picks the page it opens on. Bookmarks sort newest first.
- Unit: a hold on a panel row or a − / + area runs nothing; a hold on the header runs the admin hold.
- Emulator: with the mode on, a top tap and a bottom swipe up in a book open the panel and not
  KOReader's menus; a hold on the header opens KOReader's reader menu; with the mode off both open
  KOReader's menus as before. A tap on A+ leaves the panel open. The panel captures on the Colorsoft and
  the Paperwhite, keeps one size at every text size, and leaves no row out on the Paperwhite 7th gen or the Colorsoft.
- Emulator (release 3): with the mode on, a top-edge tap on the home opens the quick-settings sheet, an
  empty tap leaves the home shown, and a hold on a file in the file browser opens the book sheet.
