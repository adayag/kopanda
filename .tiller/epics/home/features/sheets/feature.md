# Tap acts, hold opens a sheet

## Summary

The gesture vocabulary (design §1a; direction doc "Gestures", "Hold on the book", "Hold on empty
space") and the sheet component both looks draw it with: hold on a widget opens that widget's sheet,
hold on empty space opens the home's own sheet, and every sheet row is an action or a submenu.

## Behavior

- One sheet component, styled from the look: Editorial's paper panel under a 2 px rule, Diner's outlined
  box with a hard shadow and a coloured header band. The home behind it is not dimmed.
- Hold on the featured book: header (small cover, title, author, progress, chapter, last opened), then
  Open, Book details (KOReader's), Read status › (a sub-sheet: Reading, On hold, Finished, written
  through KOReader's own calls), More by this author › (the "coming with the library" note until the
  library's author index), Feature a different book (a picker over the last one opened and the six
  most recent books), This widget's settings.
- Hold on empty space: Edit layout (a note until `device-menus`), Open the file browser, Refresh weather
  with its age, Wi‑Fi with its state, KoPanda settings, Sleep.
- Hold on any other widget opens that widget's settings (generated, so the settings stub until
  `device-menus`).
- Tapping a launcher folder entry opens a sheet listing its entries, each with its kind; a tap on one
  runs it as it runs on the home.
- A sheet closes on a tap outside it, on any action, and on KOReader's back; it paints once and never
  animates. One sheet is open at a time.
- Goldens of the book sheet and the home sheet in both looks on the Colorsoft profile.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`; `base/` is the
koreader-base submodule in that checkout. Repo paths are on `main` at `f2ef10b` unless marked. Canvas
references are to `.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board
pixels, scaled by `Screen:scaleBySize` as the looks use them.

### Order and what is cited as spec

This feature starts after `night-mode` (`home/night-mode`) has merged, which is a recorded prerequisite,
and after the tweak `split-home-lua` (TW-l2ibo3, `.tiller/tweaks/split-home-lua/tweak.md`) has merged. A
tweak can't be a hard edge, so that order is stated here and in the first task that touches `home.lua`.

- `night-mode` is approved and not built. Its palette accessor and its rule are cited from
  `.tiller/epics/home/features/night-mode/feature.md` and `tasks/palette/task.md` on `main`:
  - every colour is read through `Looks.palette(ctx.look, ctx.variant)` ("The palette the home draws
    with");
  - no `.lua` file except `looks.lua`, `swatch.lua` and the look files contains the word `palettes`,
    comments included (`palette/task.md` Tests, C3);
  - the home rebuilds inside `paintTo` when its variant is no longer `Looks.variant()`, with no
    `setDirty` of its own, because `DeviceListener` marks every window dirty (`palette/task.md` step 4).
- The split moves `home.lua`'s functions to other modules with no behaviour change. So `home.lua` is
  cited here by function name plus its line at `f2ef10b` (for example "`routeGesture`, `home.lua:504-534`
  at `f2ef10b`"). Where each function lives after the split is an open fact for the
  `hold-and-home-sheet` task, which reads it first.
- `featured-book` and `launcher` have merged, so their code is cited from `main`.

### The key

No key enters the schema. "Feature a different book" writes `featured.pinned`, which `featured-book`
added for this sheet (`schema.lua:88-96`; direction doc "Schema consequences": "set from the sheet, not
a settings screen"). The sheet's look is tokens, not keys. `schema.version` stays 1.

### Hold on the home

Today the home registers two full-screen zones, a swipe and a tap, whose handlers only name a step
(`own_zones`, `home.lua:67-92` at `f2ef10b`), and `routeGesture` runs the step in its order
(`home.lua:504-534` at `f2ef10b`). A hold reaches nothing: the file manager's menu zones are tap and
swipe only (`frontend/apps/filemanager/filemanagermenu.lua:76-113`), and the file chooser's hold is a
menu item's (`frontend/ui/widget/menu.lua:126`, `frontend/apps/filemanager/filemanager.lua:171-177`),
which `InputContainer.onGesture(fm, ges)` never visits (`frontend/ui/widget/container/inputcontainer.lua:266-285`).

- **A third own zone**, `kopanda_home_hold`, `ges = "hold"`, full screen, whose handler names the step
  `"hold"`. It is a zone, as the other two are, so KOReader's touch lock filters it the same way
  (`inputcontainer.lua:297-350`).
- **The step's place**: after the file manager's own zones, where the tap step sits. So the Gestures
  plugin's hold-corner zones, registered on the file manager (`plugins/gestures.koplugin/main.lua:1124-1139`,
  `:1287-1305`), win when bound. Unbound, their handler returns nothing and the hold carries on
  (`:1316-1320`). With Gestures' defaults, the top-right corner hold is bound to `refresh_content`
  (`plugins/gestures.koplugin/defaults.lua:11`), which refreshes the hidden file chooser
  (`filemanager.lua:857-862`). The corner is the top-right eighth of each side (`defaults.lua:67`, the
  KOReader root's): x from 1106 and y under 210 on the Colorsoft. It overlaps the right end of both
  looks' clock, about its last digit (`spec/goldens/home-diner-colorsoft.png`,
  `home-editorial-colorsoft.png`), and a hold there opens no sheet. A hold on the rest of the clock opens
  the settings stub.
- **The step**, in order:
  1. A hold inside a slot whose module has `hold` calls `hold(ctx, ges, built)`, the tap contract's
     arguments (`widgets.lua:3-8`). A return of `false` falls through to step 3; anything else consumes.
  2. A hold inside a slot whose module has no `hold` opens that widget's settings: `SettingsMenu.open()`,
     the stub until `device-menus` (`settings_menu.lua:8-12`).
  3. Otherwise, a hold outside every slot or in a blank slot with no module, opens the home sheet.
- **The widget contract** (`widgets.lua:1-15`) gains an optional `hold(ctx, ges, built)`. Only the
  featured widget has one. Its hold opens the book sheet when the built widget holds a book, and returns
  `false` on the first run, so a hold on the empty featured slot opens the home sheet.
- **Launcher entries and folders** have no hold, so a hold on the launcher opens the settings stub.
  Editing them is `device-menus`' (direction doc "Launcher": "hold on the folder edits it").
- A raising `hold` reaches `Home:onGesture`'s `pcall`, which logs and closes the home onto the file
  browser (`home.lua:538-546` at `f2ef10b`).
- A hold fires while the finger is still down, after 500 ms (`frontend/device/gesturedetector.lua:63`,
  `:1276-1287`). The lift sends `hold_release` to the top widget, by then the sheet
  (`gesturedetector.lua:1346-1356`). The sheet ignores `hold_release` and `hold_pan`.

### The sheet component

`kopanda.koplugin/sheet.lua`, a hand-built `InputContainer`. KOReader's `ButtonDialog` and `Menu` draw
KOReader's own frame and can't take the look (direction doc "Settings menus" keeps those native; "The
two looks", Sheet, draws sheets in the look). `library/context-menu` and `bars/quick-settings` promise to
reuse "the sheet component" (`library/features/context-menu/feature.md:14`,
`bars/features/quick-settings/feature.md:17`), so it knows nothing about books or the home.

A sheet is `{ name, band, header, rows }`:

- `name` is what the settled signal reports: `home`, `book`, `folder`, `status` or `picker`.
- `band` names which Diner band colour the header takes: `book`, `home` or `folder`.
- `header` is either a heading with an aside (`{ heading, aside, aside_beside }`: "Home" with "KoPanda"
  at the right, or "Tools" with "Folder · 3" just after it when `aside_beside`) or a book's
  (`{ cover, title, author, meta }`, `cover` a built widget).
- Each row is `{ icon, label, detail, chip, muted, tick, run }`. `icon` is a registry id or nil, `detail`
  the text at the row's right end, `chip` which chip colour token it takes, `muted` whether the row is
  greyed, `tick` whether a check marks it, and `run` what a tap does.

#### Drawing

Every colour is read through `Looks.palette(ctx.look, ctx.variant)`. Text is `Typeset.line`
(`typeset.lua:49-86`), and icons are `TintedIcon`s in `ink`, or `muted` on a greyed row
(`tinted_icon.lua:1-20`). Fills and borders go through the RGB32 calls for a colour, as the home's
widgets paint (`widgets/quote.lua:51-67`; `base/ffi/blitbuffer.lua:1704-1724`, `:1827`).

- **Editorial** (HoldBook:34-72, HoldHome:34-68): a paper panel the full width of the screen, on the
  bottom edge, under a 2 px `ink` rule. It is padded 40 at the sides and 28 at the foot.
  - The header has a 1 px `ink` rule under it.
  - Each row has a 1 px `hairline` rule under it, as the boards draw it (`#c9c5b8`, HoldBook:43), and the
    last row has no rule and no foot padding (HoldBook:69).
  - Details are plain small text in `muted`, uppercase, 0.1 em (HoldBook:56).
- **Diner** (HoldBookC:30-68, HoldHomeC:30-64): a paper box inset 22 from the sides and the foot, with a
  3 px `outline` border and the 8 px `shadow.sheet` hard shadow (`looks/diner.lua:84`).
  - The header is a band filled with the sheet's band colour, with a 3 px `outline` rule under it.
  - Rows are padded 20 at the sides, each with a 2 px `outline` rule under it except the last.
  - A detail is a chip where the boards draw one: Read status on mustard (HoldBookC:52) and the Wi‑Fi
    state on teal (HoldHomeC:55), each with a 2 px outline and 2/8 padding. Elsewhere the detail is
    plain: the weather's age, in `muted` (HoldHomeC:48).
- **Both**: rows are 15 above and below their content, with the icon at 22, the gap after it, the label
  and the detail at the right. A tick is the registry's `check` icon in the icon's place.
- **The home is not dimmed.** The boards fade it to 25 % and 30 % (HoldBook:19, HoldBookC:19); the
  device draws the sheet over the home as it is.
- **Too many rows.** A sheet taller than the screen leaves out the rows that don't fit, logged once.
  Only a long folder can do that.

#### Tokens

The `sheet` block (`looks/editorial.lua:110-117`, `looks/diner.lua:110-118`) keeps its five tokens and
gains these, with identical paths in both looks and each value carrying its board line in a comment, by
`looks_spec.lua`'s rules (`:82-113` identical paths, `:172-199` strings only as roles, faces or markers):

| Token | Editorial | Diner |
|---|---|---|
| `inset.side`, `inset.bottom` | 0, 0 (HoldBook:34) | 22, 22 (HoldBookC:30) |
| `padding.top`, `.side`, `.bottom` | 0, 40, 28 (HoldBook:34) | 0, 0, 0 (HoldBookC:30) |
| `book_band_color`, `home_band_color`, `folder_band_color` | false | `pink` (HoldBookC:31), `mustard` (HoldHomeC:31), `teal` (no board) |
| `header_rule_color`, `header_rule_width` | `ink`, 1 (HoldBook:35) | `outline`, 3 (HoldBookC:31) |
| `header_padding.top`, `.side`, `.bottom` | 22, 0, 16 (HoldHome:35) | 16, 20, 16 (HoldHomeC:31) |
| `book_header_padding.top`, `.side`, `.bottom` | 24, 0, 20 (HoldBook:35) | 18, 20, 18 (HoldBookC:31) |
| `cover_gap` | 18 (HoldBook:35) | 16 (HoldBookC:31) |
| `cover_w`, `cover_h` | 60, 90 (HoldBook:36) | 60, 90 (HoldBookC:32) |
| `line_gap`, `meta_gap` | 3, 4 (HoldBook:37, :40) | 3, 4 (HoldBookC:33, :36) |
| `aside_gap` | 12 (FolderOpen:36) | 12 (no board) |
| `row_padding.x`, `.y` | 0, 15 (HoldBook:43) | 20, 15 (HoldBookC:39) |
| `row_gap`, `icon_size` | 16, 22 (HoldBook:43-44) | 14, 22 (HoldBookC:39-40) |
| `row_rule_color`, `row_rule_width` | `hairline`, 1 (HoldBook:43) | `outline`, 2 (HoldBookC:39) |
| `last_row_bottom` | 0 (HoldBook:69) | 15 (HoldBookC:65) |
| `status_chip_color`, `state_chip_color` | false | `mustard` (HoldBookC:52), `teal` (HoldHomeC:55) |
| `chip_padding.x`, `.y`, `chip_outline_width` | false, false, 0 | 8, 2, 2 (HoldBookC:52) |

Eight `type` parts join both looks, each exactly `{ color, face, line_height, size, tracking, uppercase }`
naming a face with a file and a role this look has (`looks_spec.lua:201-219`):

| Part | Editorial | Diner |
|---|---|---|
| `sheet_heading` | `display` 26, `ink` (HoldHome:36) | `display` 24, `on_accent` (HoldHomeC:32) |
| `sheet_aside` | `text` 12, uppercase, 0.1, `muted` (HoldHome:37) | `accent` 22, `on_accent` (HoldHomeC:33) |
| `sheet_title` | `display` 24, line height 0.1, `ink` (HoldBook:38) | `display` 24, line height 0.05, `on_accent` (HoldBookC:34) |
| `sheet_author` | `text` 14, `text` (HoldBook:39) | `text` 14, `on_accent` (HoldBookC:35) |
| `sheet_meta` | `text` 12, uppercase, 0.1, `muted` (HoldBook:40) | `strong` 12, uppercase, 0.08, `on_accent` (HoldBookC:36) |
| `sheet_row` | `strong` 17, `ink` (HoldBook:43) | `strong` 17, `ink` (HoldBookC:39) |
| `sheet_detail` | `text` 12, uppercase, 0.1, `muted` (HoldBook:56) | `strong` 12, uppercase, 0.08, `muted` (HoldHomeC:48) |
| `sheet_chip` | `text` 12, uppercase, 0.1, `muted` (not drawn: Editorial has no chips) | `display` 11, uppercase, 0.08, `on_accent` (HoldBookC:52) |

A greyed row draws `sheet_row` and its detail with the colour `muted`, as the launcher greys an entry.

**One new palette role, `on_accent`**: the text on Diner's accent fills, the bands and the chips. Night
mode left it to this feature (`night-mode/feature.md` Notes). The direction doc says "Mustard and pink
tiles take dark text" at night (lines 68-69), and today's `ink` turns cream at night (`looks/diner.lua:39`).

| Look | day | night | grey |
|---|---|---|---|
| Diner | `#2f2e2b`, the boards' ink on the band (HoldBookC:31-36) | `#1e1c1a`, the night paper: no board gives one | `#111111`, ink on the grey tiles (PWRetro:19) |
| Editorial | false | false | false |

It keeps every palette rule: values are false or `#rrggbb` (`looks_spec.lua:129-142`), grey is r = g = b
(`:144-154`), and it stays distinct in grey from every role it differs from by day (`:158-170`).

#### Showing, closing and painting

- **One at a time.** `Sheet.show(spec, ctx, opts)` closes the sheet already shown, if any, then shows the
  new one. A sub-sheet replaces its parent, and closing it leaves the home. That is one state to track rather
  than a stack, and one paint per change on e-ink.
- **Paint once.** `UIManager:show` with `"ui"` over the sheet's rectangle, shadow included
  (`frontend/ui/uimanager.lua:229-273`). KOReader's `ButtonDialog` asks for `"full"` only when coloured
  on a Kaleido panel (`frontend/ui/widget/buttondialog.lua:89-90`, `:327-331`), and only Kobo sets
  `hasKaleidoWfm` (`frontend/device/kobo/device.lua:800`; `frontend/device/generic/device.lua:118`), so
  on the Kindle that is `"ui"` too.
  - The sheet's `dimen` is the whole screen, so it sees every tap, but it paints only its panel and is
    not `covers_fullscreen`.
  - No timer is scheduled and nothing animates.
- **Closing** is `UIManager:close(sheet, "flashui", rect)`, as `ButtonDialog:onCloseWidget` refreshes
  (`buttondialog.lua:333-337`).
  - `close` marks the home dirty again, as the topmost `covers_fullscreen` window (`uimanager.lua:290-355`),
    so the home repaints underneath.
  - The sheet frees its built widgets when it closes.
- **What closes it:**
  - A tap outside the panel closes it and is consumed, as `ButtonDialog:onTapClose` does
    (`buttondialog.lua:347-352`). The home doesn't see that tap.
  - A tap on a row closes the sheet, then runs the row. So what the row shows (a note, KOReader's book
    details, History, a sub-sheet) lands over the home.
  - A tap on the header runs nothing and keeps the sheet open. A tap on a sub-sheet's ticked row closes
    it and runs nothing.
  - The Back key, where `Device:hasKeys()`, by `key_events.Close` on `Device.input.group.Back`, as
    `ButtonDialog` binds it (`buttondialog.lua:98-108`; `frontend/device/input.lua:121`).
  - The `Back` event, sent to the top widget by the dispatcher's `fm_back` (`frontend/dispatcher.lua:169`).
  - Holds, swipes, `hold_release` and `hold_pan` are ignored.
- **The Colorsoft may report no keys.** It declares none (`frontend/device/kindle/device.lua:1208-1220`,
  `generic/device.lua:92`) and gains them only when a frame-tap input is found
  (`kindle/device.lua:553-556`, `:673-675`). Reading can't settle which, so touch-only closing is what the
  Colorsoft is planned for. The emulator has keys (`frontend/device/sdl/device.lua:73`).
- **Failing safe.** The sheet's gesture, key and paint handlers each run in `pcall`. A failure is logged
  and closes the sheet and the home, leaving the file browser, as the home fails (`Home:onGesture` and
  `Home:paintTo`, `home.lua:538-546` and `:463-475` at `f2ef10b`). A paint failure closes them from the
  next tick, since a widget can't close inside the repaint (`home.lua:461-462` at `f2ef10b`).
- **The home underneath.** A home refresh while a sheet is up (the weather fetch finishing) repaints the
  home, and `_repaint` repaints every window above a dirty one (`uimanager.lua:1298-1346`), so the sheet
  stays on top. The home closing by any path closes a shown sheet with it.
- **Night mode while a sheet is up.** The sheet keeps the variant it was built with. Its `paintTo`
  rebuilds when that is no longer `Looks.variant()`, with no `setDirty`, the home's own rule from
  `night-mode`. Closing it instead would need a close from the next tick and would paint one frame in the
  old palette. Nothing toggles night mode while a sheet is up today; the quick-settings sheet will.
- **The settled signal.** After its first paint, from `tickAfterNext` as the home sends its own
  (`settle`, `home.lua:338-355` at `f2ef10b`), the sheet sends
  `KoPandaSettled{ screen = "sheet", name = <its name>, paint_ms }` once. `paint_ms` runs from the hold
  (or tap) that opened it to the first paint, so it counts what the opener builds before the show (the
  book sheet's cover and status read). `Sheet.show` takes it as an optional `opts.started`, the
  `time.monotonic()` the hold step, the featured widget's `hold`, the folder tap or a sub-sheet's row took
  on entry, as `Home.show` takes `opts.started` (`home.lua:384-403` at `f2ef10b`). With none, it runs from
  the start of `show`. A sheet whose paint failed sends nothing.

### The home sheet

`kopanda.koplugin/home_sheet.lua`. `home.lua` requires it inside the hold step, not at load:
`launcher_entries.lua:5` requires `home`, so a top-level require would be a cycle, the way `widgets.lua`
already requires its modules lazily (`widgets.lua:18-19`). The header is "Home", with "KoPanda" as its
aside, and its band is the home's.

| Row | Icon | Detail | Tap |
|---|---|---|---|
| Edit layout | `layout` | none | A note: "Edit layout comes with the settings menus." An `InfoMessage` with no timeout, as `launcher_entries.lua:109-113` shows its notes. |
| Open the file browser | `folder` | none | `Home.close()` (`home.lua:405-409` at `f2ef10b`), revealing the file browser at its current path. |
| Refresh weather | `sun` | the cached reading's age, plain | `Weather.tap(ctx.home)` (`weather.lua:220-236`): a fetch now, or once online, and the home refreshes on success. |
| Wi‑Fi | `wifi`, or `wifi_off` when off | "On" or "Off", the state chip | The launcher's Wi‑Fi entry, `{ kind = "koreader", target = "wifi" }`, through `LauncherEntries.run` (`launcher_entries.lua:155-186`). |
| KoPanda settings | `settings` | none | `SettingsMenu.open()`. |
| Sleep | `moon` | none | `{ kind = "action", action = "suspend", label = "Sleep", icon = "moon" }` through `LauncherEntries.run`. |

- **The weather's age** is a new `Weather.age(reading, now)`:
  - no reading: "never fetched";
  - under a minute (or a reading from the future): "just now";
  - under an hour: "N min ago";
  - under 48 hours: "N h ago";
  - from 48 hours: "N d ago".

  The hour and day thresholds are `Weather.line`'s (`weather.lua:172-177`), which keeps its own suffix.
  `Weather.reading()` gives `fetched_at` (`weather.lua:134-152`).
- **Wi‑Fi** is resolved through `LauncherEntries.resolve` (`launcher_entries.lua:82-107`), so it is "Off"
  when `NetworkMgr:isWifiOn()` is false and greyed with "not available" when the dispatcher lists no
  `toggle_wifi` (`dispatcher.lua:124`, conditioned on `hasWifiToggle`). The toggle goes through the dispatch
  bridge (`dispatch_bridge.lua:36-58`) to `NetworkListener:onToggleWifi`, and the home's own
  `NetworkConnected` and `NetworkDisconnected` handling repaints it (`home.lua:296-312` at `f2ef10b`).
- **Sleep** is the dispatcher's `suspend` (`dispatcher.lua:94`, conditioned on `Device:canSuspend()`). It
  sends `RequestSuspend` to the file manager's `DeviceListener` through the bridge
  (`filemanager.lua:414`; `frontend/device/devicelistener.lua:458-460`), which calls `UIManager:suspend()`
  on the next tick (`uimanager.lua:1679-1686`).
  - The Kindle can suspend (`kindle/device.lua:402`). The emulator simulates it with the screensaver
    (`sdl/device.lua:165`, `:417-428`, `:462-468`).
  - Where the dispatcher doesn't list `suspend`, the row is greyed with "not available", as an action
    entry is (`launcher_entries.lua:64-67`).

### The book sheet

`kopanda.koplugin/book_sheet.lua`, opened by the featured widget's `hold`. `widgets/featured.lua` is 508
lines, past AGENTS.md's 500-line signal, so its `hold` is a few lines that hand the built widget's book
to this module. The band is the book's.

- **A gone file.** When the held book's file is no longer a file, the hold refreshes the home, as a tap
  does (`Featured.tap`, `widgets/featured.lua:475-488`), and opens no sheet.
- **Header:**
  - the cover from `FeaturedCover.build(book, w, h, ctx)` at `cover_w` × `cover_h`, which reads
    CoverBrowser's cache and never asks for an extraction (`featured_cover.lua:209-212`). It takes the
    look's cover frame, as the home's does (direction doc "Covers"). A cached cover bigger than the box
    still fits it (`plugins/coverbrowser.koplugin/bookinfomanager.lua:1013-1030`);
  - the title and the authors from `FeaturedBook.current()` (`featured_book.lua:131-184`), as the built
    widget keeps it (`widgets/featured.lua:453-466`);
  - the meta line, "62% · Letter IV · opened today", its parts joined by " · ", each left out when
    unknown:
    - the percent the home shows (`shown_percent`, `widgets/featured.lua:133-138`);
    - the recorded chapter (`book.chapter`);
    - when it was last opened: the `time` of the book's `ReadHistory.hist` entry
      (`frontend/readhistory.lua:25-35`). It is set when the book opens (`readhistory.lua:313-339`,
      `frontend/apps/reader/readerui.lua:511`) and when it closes (`readhistory.lua:342-350`,
      `readerui.lua:882`). History holds realpaths (`readhistory.lua:26`), so the book's file is compared
      by realpath, as `featured_book.lua:119-129` compares. It reads "opened today", "opened yesterday"
      or "opened N days ago", counted in local calendar days.

| Row | Icon | Detail | Tap |
|---|---|---|---|
| Open | `open_book` | none | What a tap on the book runs, `Featured.tap` (`widgets/featured.lua:475-488`): `fm:openFile(file)` (`filemanager.lua:1616-1639`). |
| Book details | `info` | none | `FileManager.instance.bookinfo:show(file)` (`filemanager.lua:406`; `frontend/apps/filemanager/filemanagerbookinfo.lua:71-87`), KOReader's page, shown over the home. |
| Read status | `bookmark` | the status, the status chip, then " ›" | The status sub-sheet. |
| More by this author | `authors` | "›", plain | `LauncherEntries.run({ kind = "kopanda", target = "authors" })`: the note "Authors are coming with the library." (`launcher_entries.lua:131-133`). |
| Feature a different book | `list` | none | The picker. |
| This widget's settings | `settings` | none | `SettingsMenu.open()`. |

- **The status detail** is KOReader's label for the book's status:
  `BookList.getBookStatusString(BookList.getBookStatus(file), false, true)`
  (`frontend/ui/widget/booklist.lua:366-369`, `:386-389`). It reads Reading, On hold, Finished, or New
  for a book with no sidecar (`:371-378`).
- **"More by this author" has no count.** The board's "More by Susanna Clarke" with "3" (HoldBook:58-64)
  needs the library's author index (`library/features/book-model/feature.md:15`), and
  `series-and-authors` replaces the note with its Authors screen (`series-and-authors/feature.md:12-14`).

#### The status sub-sheet

Headed "Read status" with the book's title as its aside, on the book's band. Its three rows come from
KOReader's own `filemanagerutil.genStatusButtonsRow(doc_settings_or_file, callback)`
(`frontend/apps/filemanager/filemanagerutil.lua:118-146`), called as the file dialog calls it
(`filemanager.lua:255-270`): with `BookList.getDocSettings(file)` when `BookList.hasBookBeenOpened(file)`
(`booklist.lua:348-364`), else with the path.

- The buttons come in KOReader's order, reading, abandoned, complete (`filemanagerutil.lua:141-145`).
  Each row's label is `BookList.getBookStatusString(status, false, true)`: Reading, On hold, Finished.
- The current status's button is disabled (`:131-132`). That row is ticked, and a tap on it closes the
  sub-sheet and writes nothing.
- A tap on another row runs its button's `callback`, so KOReader writes it:
  - `filemanagerutil.saveSummary`, which creates the sidecar when there is none, sets
    `summary.modified` and flushes (`:106-115`);
  - then `BookList.setBookInfoCacheProperty(file, "status", s)` (`booklist.lua:318-326`);
  - then the callback KoPanda passed, which refreshes the home (`Home:refresh`, `home.lua:245-261` at
    `f2ef10b`).

#### The picker

Headed "Feature a book", on the book's band.

- **The first row** is "The last one opened". A tap writes `featured.pinned = false`.
- **Then the six most recent books** in KOReader's history: the entries `FeaturedBook`'s own filter
  keeps (selectable, not the QuickStart guide, still a file; `featured_book.lua:41-49`), most recent
  first (`readhistory.lua:332-333`). Each row's label is the title and its detail the authors, read as
  `FeaturedBook.current()` reads them (CoverBrowser's cache, then the sidecar, then the file name;
  `featured_book.lua:73-99`). They come from a new `FeaturedBook.recent(n)`, built on a new `FeaturedBook.describe(file)` for one
  book; neither raises nor writes.
- **A pinned book older than those six** joins the list after them, so the current choice is always
  shown.
- **Ticks** follow the pin:
  - "The last one opened" is ticked when `featured.pinned` is false, or names a file that has gone,
    which `FeaturedBook` reads the same way (`featured_book.lua:52-64`);
  - a book is ticked when the pin names it, compared by realpath.

  A tap on the ticked row closes the picker and writes nothing.
- **A tap on a book** writes `Settings.set("featured.pinned", entry.file)`. The value is the history's
  realpath (`readhistory.lua:26`), which the `path` validator accepts (`settings.lua:200-203`). A refused
  write is logged and changes nothing (`settings.lua:307-315`).
- **After a write** the picker refreshes the home, then runs the featured slot's `after_show` once
  (`widgets/featured.lua:501-506`). `after_show` runs only after a show (`settle`, `home.lua:356-375` at
  `f2ef10b`), so without that a newly featured book that CoverBrowser hasn't cached would keep its
  typographic cover until the next show.

### The folder sheet

`kopanda.koplugin/folder_sheet.lua`. A tap on a folder entry opens it in place of today's note,
"Tools holds 3 entries; folders open in a later update." (`LauncherEntries.run`,
`launcher_entries.lua:161-166`). `launcher_entries.lua` requires it at call time, since the folder sheet
requires `launcher_entries`. The header comment that "a folder sheet can reuse both" (`:1-3`) becomes
true.

- **The header** is the folder's label, with "Folder · N" as its aside beside it (FolderOpen:35-39). The
  band is the folder's. FolderOpen's "Hold to edit" on the right (:40) waits for `device-menus`.
- **One row per entry**, in order, from `LauncherEntries.resolve`:
  - its icon and its label;
  - on the right, its kind: KoPanda, KOReader, Plugin, Action or Folder on disk (FolderOpen:47, :54, :61
    draw "Plugin" and "Action"; the launcher spec names "Folder on disk", `launcher/feature.md:374-375`);
  - an entry that is off or unavailable is drawn as on the home: `wifi_off`, or greyed with the dashed
    icon, and its suffix ("off", "plugin missing", "folder missing", "not available") in place of the
    kind.
- **A tap on a row** closes the sheet, then `LauncherEntries.run(entry, ctx)`, so the entry does what it
  does on the home, an unavailable entry's note included.
- Folders don't nest (`launcher/feature.md` "Entries"), so a folder sheet never opens another.

### Goldens and budget

- **A scenario userpatch**, `spec/emulator/scenarios/2-scenario-sheet-hold.lua`, waits for the home's
  first settled signal, then sends one `hold` `Gesture` event, as the gesture-forward scenario sends its
  tap (`spec/emulator/scenarios/2-scenario-gesture-forward.lua:62-83`).
  - `KOPANDA_SHEET_HOLD=book` holds at the centre of the featured slot's rectangle, read from
    `Home.shown.slots`.
  - `KOPANDA_SHEET_HOLD=home` holds at the left margin, half way down the screen. That is outside every
    slot rectangle, which the scenario checks, and outside the four corner zones.
- **The capture** runs with the home fixture's `populated` scenario
  (`spec/emulator/scenarios/2-scenario-home-fixture.lua`) and `shot_screen = "sheet"`. The capture patch
  shoots on the first matching signal (`spec/emulator/patches/2-kopanda-capture.lua:61-74`).
- **Four goldens on the Colorsoft:** `sheet-book-diner`, `sheet-book-editorial`, `sheet-home-diner` and
  `sheet-home-editorial`.
  - The fixture freezes the clock at 2026-10-13 08:42, its history entry an hour earlier and its weather
    20 minutes earlier (`2-scenario-home-fixture.lua:31-45`, `:101`, `:178`). So the book's meta reads
    "62% · Letter IV · opened today" and the weather row "20 min ago".
  - The driver turns the fake Wi‑Fi off (`spec/emulator/driver.lua:80`, `:109`), so Wi‑Fi reads "Off".
- **The folder sheet, the sub-sheets and night mode** are covered by the unit specs and the owner's
  emulator run, not by goldens.
- **Budget.** Each sheet capture's `paint_ms` is at most 250 ms, the home's tripwire
  (`spec/emulator/home_capture_spec.lua:7-10`), here from the hold to the sheet's first paint. It is a
  regression tripwire on this Mac, not a device figure. The home's own paint is about 30 ms
  (`spec/goldens/home-diner-colorsoft.json`).
- **The home's goldens** don't change: the home looks the same until something is held.

### HOOKS.md

Every new KOReader surface goes into `kopanda.koplugin/HOOKS.md` with its `file:line`:

- the `hold` and `hold_release` gestures and the hold interval (`gesturedetector.lua:63`, `:1276-1287`,
  `:1346-1356`);
- Gestures' hold-corner zones, their unbound fall-through, `ignore_hold_corners`, and the default
  `refresh_content` binding with `FileManager.onRefreshContent` (`gestures main.lua:1124-1139`,
  `:1287-1305`, `:1316-1320`; `gestures defaults.lua:11`; `filemanager.lua:857-862`);
- `UIManager:close`'s re-dirtying, `_repaint`'s paint order, the `"ui"` and `"flashui"` refreshes and
  `ButtonDialog`'s pattern they follow, and `hasKaleidoWfm`;
- `Device:hasKeys()`, `Device.input.group.Back` and the Kindle's frame-tap keys; the `fm_back` `Back`
  event;
- `filemanagerutil.genStatusButtonsRow` and `saveSummary`; `BookList.hasBookBeenOpened`, `getDocSettings`,
  `getBookStatus`, `getBookStatusString` and `setBookInfoCacheProperty`;
- `FileManager.instance.bookinfo:show` and its close broadcasts (`filemanagerbookinfo.lua:267-285`);
- `ReadHistory.hist[i].time` and where it is set;
- the dispatcher's `suspend`, `DeviceListener:onRequestSuspend` and `UIManager:suspend`;
- `BookInfoManager.isCachedCoverInvalid` for the small cover.

## Notes

The draft's assumption, that a hold on the full-screen home doesn't fall through to the file manager's
own hold handling, is settled by reading (see "Hold on the home"): an unhandled hold is dropped. Night
mode's sheet colours (`on_accent` and the bands) are this feature's, as `night-mode` left them.

Defaults written in without a board or a question:

- **Kinds' names in the folder sheet** follow the launcher spec's: KoPanda, KOReader, Plugin, Action,
  Folder on disk.
- **Sizes the boards draw differently** and one token covers: the folder's rows are padded 16
  (FolderOpen:42), the other sheets' 15, and the sheets take 15. The small cover takes the look's cover
  frame (Editorial's 2/3 shadow and 3 px radius, Diner's 3 px outline and 6 px pink shadow) rather than
  the boards' 2 px radius (HoldBook:36) and 2 px border (HoldBookC:32). Board icons are stroke 1.6 in
  Editorial; the registry's are 2.
- **The boards' background greeting** (HoldBookC:21) is the home's Diner header the home doesn't draw.

For the owner, each a default the lead chose that you can overturn at approval:

- **Hold routing.** The hold step runs after the file manager's zones, as the tap does, so a bound
  Gestures corner hold wins. KOReader's default binds the top-right corner to "refresh content". The
  corner overlaps the right end of both looks' clock (about its last digit): a hold there does nothing
  visible, and a hold on the rest of the clock opens the settings stub. Unbinding it in Gestures, or
  turning on "ignore hold corners", gives the whole clock its settings stub.
- **What a hold on a widget opens.** Only the featured book has a sheet. Every other widget, the
  launcher included, opens the settings stub; empty space and a held empty featured slot open the home
  sheet.
- **Diner band colours:** the book's pink and the home's mustard are the boards'; the folder's teal has no
  board.
- **`on_accent` at night is `#1e1c1a`**, a guess with no board. Dark text on the night teal folder band
  (`#2f6b65`) has low contrast; mustard or pink would read better there.
- **Details per board.** Editorial details are plain muted small caps; Diner draws chips where the boards
  draw them (Read status mustard, Wi‑Fi teal) and plain text where they draw plain (the weather's age).
  "More by this author" is a plain chevron, with no count.
- **Editorial row rules are `hairline`**, as the boards draw them, not the direction doc's
  `hairline_light` "row rules" (line 52), which the launcher uses.
- **"Last opened" in the book header and the Wi‑Fi state on the home sheet** are the direction doc's
  decisions: "Hold on the book" lists "(small cover, title, author, progress, last opened)" and "Hold on
  empty space" lists "Wi‑Fi (with its state)" (lines 22-23). Its "Candidates, not scope" paragraph
  (lines 111-113) lists both as not promised, which contradicts the table. Both are in, by the table.
- **A pinned book older than the six** joins the picker after them, so the current choice is always
  shown. Your decision, as the Behavior records it, is "The last one opened" and the six most recent
  books; this seventh row is the lead's addition.
- **Wording to replace with your own:** "Edit layout comes with the settings menus.", "never fetched",
  "just now", "opened today" / "yesterday" / "N days ago", "Feature a book", "The last one opened", and
  the label "More by this author" (the board writes the author's name).
- **One sheet at a time.** A sub-sheet replaces its parent, and closing it returns to the home, not to
  the book sheet.
- **Night mode while a sheet is up** rebuilds the sheet in the new palette rather than closing it.
- **No dimming**, and no "Hold to edit" on the folder sheet until `device-menus`.
- **The picker after a pin** asks for the new book's cover at once, through the featured slot's
  `after_show`.
- **Book details** is KOReader's page. Editing a book's metadata there doesn't refresh the home, which
  doesn't handle `BookMetadataChanged`; the home shows the change on its next rebuild.
