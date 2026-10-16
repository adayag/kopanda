# Five-tab nav bar in both looks

## Summary

A bottom bar with Home, Library, Authors, History and Settings, drawn from the look (direction doc
"Nav bar"), present on the home screen and on KOReader's file browser.

## Behavior

- The bar wraps `FileManager.setupLayout` (`frontend/apps/filemanager/filemanager.lua:116`) to reserve its
  height beneath the file chooser, and the home reserves the same band. SimpleUI does the same job
  (SimpleUI 2.7.5 as installed, `infra/sui_patches.lua:359`, `:547`, `:737-739`); KoPanda takes the idea, not
  the code.
- Editorial: a hairline bar with uppercase labels and a 3 px rule over the active tab. Diner: a teal
  band with ink dividers and the active tab as a mustard block.
- Tabs resolve through the launcher's entry resolution; Authors shows the placeholder note until
  `library/series-and-authors`.
- Hold on the Settings tab is reserved for the quick-settings sheet (question Q-irxgmk).
- `HOOKS.md` gains the patched function with its citation; goldens for both looks on both profiles on
  the home and on the file browser.

## Specification

KOReader paths are relative to `~/Projects/kodev/koreader/` at the pinned build `e1fe1ac`. SimpleUI paths
are relative to `plugins/simpleui.koplugin/` there, "SimpleUI 2.7.5 as installed" (`_meta.lua`; the folder
is untracked in KOReader's checkout and has no licence file). Repo paths are on `main` at `fa0e7dd`. Boards
are `.tiller/design/2026-10-13-kopanda-screens/<board>.dc.html:<line>`; sizes are board pixels, scaled by
`Screen:scaleBySize` as the looks use them (`layout.lua:4-6`, `:15-17`), so ×2.107 on the Colorsoft.

### Decisions

Owner decisions (owner, 2026-10-16):

- **D1. Where the bar shows:** on the KoPanda home and on KOReader's file browser only. Not over History,
  Collections or Favorites, and not in the reader. History opens KOReader's own full-screen list; closing it
  returns to whatever was beneath (the file browser and its bar, or the home).
- **D2. The Settings tab** opens KoPanda's settings menu, `SettingsMenu.open()`, as the launcher's Settings,
  the swipe up and the home sheet do.
- **D3. Holds:** a hold on any tab is consumed and does nothing. Settings' hold stays reserved for the
  quick-settings sheet (Q-irxgmk, owned by the bars epic). On the home, a hold on the bar does not open the
  home sheet.
- **D4. The bar wins** over every gesture binding inside its band, Gestures' default bottom-left frontlight
  corner included. The specs that probe the bottom corners move their probe points above the bar (below).
- **D5. A tap on the active tab:** in the file browser, Library goes to the home folder's first page
  (`fm:onHome()`); on the home, Home does nothing.
- **D6. No settings key:** five fixed tabs, no on/off, no order. No schema change.
- **D7. The home's bottom follows the boards:** Diner drops its footer stripe (the bar always shows on the
  home, NavBarC:70 draws none), and Editorial's bottom margin above the bar becomes 20 (NavBar:19, :61).
- **D8. Nav labels don't follow `text_size`;** each look's bar has one fixed height.
- **D10. The boot-guard notice** keeps its wording (`main.lua:136-138`); "The Home tab" now also reads as
  the bar's, which is true.

Lead decisions, each overturnable at approval:

- **SimpleUI: ideas only.** No SimpleUI code is copied, so no MIT notice is needed. What is taken is two
  KOReader facts, cited to KOReader below: a chooser built with a `height` is shorter, and `fm[1]` can be
  wrapped after the original `setupLayout`. SimpleUI's mechanisms are named under "SimpleUI" for contrast.
- **Per-look heights, relayout on a look change.** The boards' bars are not the same height (below), so each
  look has its own, and a stored look change re-runs the file manager's layout.
- **The chooser's height is set on `FileChooser`'s class for the duration of the original `setupLayout`
  only**, not by a patch on `FileChooser.init` (below).

### Where the bar shows and what it does

The bar is `kopanda.koplugin/nav_bar.lua` (`NavBar`). It is drawn in two places: by the home's rows, and by
the file manager patch, `kopanda.koplugin/fm_nav.lua` (`FmNav`). Neither name exists in KOReader's
`frontend/`, `common/` or any plugin in the emulator's `plugins/` (checked against
`spec/unit/hooks_doc_spec.lua:104-122`'s rule on 2026-10-16).

| Tab | Label, icon | On the home | In the file browser |
|---|---|---|---|
| Home | Home, `home` | active; a tap does nothing (D5) | the home: `FileManager.instance.kopanda:goHome()` (`main.lua:252-258`), KoPanda's instance being registered under its name (`frontend/apps/filemanager/filemanager.lua:379-389`, `:424`; `main.lua:67-70`) |
| Library | Library, `library` | `LauncherEntries.run{ kind = "kopanda", target = "library" }`: the home closes and the file browser goes to the home folder (`launcher_entries.lua:123-129`) | active; a tap runs the same entry: `Home.close()` finds no home and `fm:onHome()` goes to the home folder, its first page when already there (`filemanager.lua:865-871`, `frontend/ui/widget/filechooser.lua:389-406`) (D5) |
| Authors | Authors, `authors` | `LauncherEntries.run{ kind = "kopanda", target = "authors" }`: the note "Authors are coming with the library." (`launcher_entries.lua:133-135`, `:113-115`) | the same |
| History | History, `history` | `LauncherEntries.run{ kind = "koreader", target = "history" }`: `Dispatcher:execute({ history = true })` (`launcher_entries.lua:171-189`), `ShowHist` (`frontend/dispatcher.lua:68`), which the dispatch bridge carries to the file manager under the home (`dispatch_bridge.lua:33-58`); History shows over the home and its close returns to it | the same, History over the file browser; its close returns to the file browser (`frontend/apps/filemanager/filemanagerhistory.lua:59-97`) |
| Settings | Settings, `settings` | `LauncherEntries.run{ kind = "kopanda", target = "settings" }`: `SettingsMenu.open()` (`launcher_entries.lua:136-138`) (D2) | the same, over the file browser |

- Labels are the boards' (NavBar:71-87, NavBarC:73-89); the four launcher targets' labels and icons match
  `LauncherEntries.KOPANDA` and `KOREADER` (`launcher_entries.lua:18-32`). The five icon ids are in the
  registry with `used_in` "nav" already (`icons.lua:14-29`).
- **Active tab:** Home on the home; Library in the file browser, whatever folder it shows. History, Authors
  and Settings are never active: no screen of theirs carries the bar (D1).
- **Tap:** a tap inside a tab's column runs that tab, once, and is consumed; a tap in the bar outside every
  column (Editorial's side padding) is consumed and runs nothing. The tab's run is in `pcall`;
  an error is logged and the tap still consumed, so the screen under it stays as it was.
- **Hold:** a hold anywhere in the bar is consumed and runs nothing (D3).
- **Everything else** (swipes, pans, two-finger gestures) passes through the bar untouched: the home's swipe
  up from the bottom edge still opens settings when it starts in the band (`home_gestures.lua:29-36`), and the
  file manager's swipes still page.
- **The touch lock:** KOReader's ignore-touch-input swaps every `InputContainer`'s gesture handler for a
  filter that runs only approved touch zones and no `ges_events` (`frontend/ui/widget/container/inputcontainer.lua:299-309`,
  `:322-350`). The bar takes its taps through `ges_events` in the file browser and through the home's own
  filtered zones on the home (`home_gestures.lua:47-54`), never by overriding `onGesture`, so the lock
  silences it as it silences the rest.

### Tokens

A new `nav` block and two type parts in both looks, with identical paths, each value carrying its board line
in a comment, by `looks_spec.lua`'s rules (`spec/unit/looks_spec.lua:83`, `:185`, `:214`). Every colour names
an existing palette role; no role is added.

| Token | Editorial (NavBar) | Diner (NavBarC) |
|---|---|---|
| `nav.fill_color` | `paper` (:68) | `band` (:70) |
| `nav.edge_width`, `nav.edge_color` | 1, `ink` (:68) | 4, `ink` (:70; as the header's 4 px edge, `looks/diner.lua:179-180`) |
| `nav.padding_x` (the bar's side padding) | 24 (:68) | 0 (:70) |
| `nav.padding_top`, `nav.padding_bottom` (a tab's) | 16, 18 (:69) | 14, 16 (:71) |
| `nav.icon_size`, `nav.icon_gap` (icon to label) | 26, 7 (:69-70) | 28, 6 (:71-72) |
| `nav.icon_color`, `nav.active_icon_color` | `text`, `ink` (:73 `#4a4843`; :14, :17 inherited) | `ink`, `on_accent` (:14, :17 inherited; on the mustard block) |
| `nav.active_rule_width`, `nav.active_rule_color` | 3, `ink` (:69) | 0, false |
| `nav.active_fill_color` | false | `mustard` (:71) |
| `nav.divider_width`, `nav.divider_color` | 0, false | 3, `outline` (:71, :75, :79, :83; none on the last, :87) |

| Part | Editorial | Diner |
|---|---|---|
| `type.nav_label` | `strong` 11, uppercase, 0.12, line height 0, `text` (:73) | `strong` 12, uppercase, 0.04, line height 0, `ink` (:75) |
| `type.nav_label_active` | `strong` 11, uppercase, 0.12, line height 0, `ink` (:69) | `display` 12, uppercase, 0.04, line height 0, `on_accent` (:71) |

- Weights: Editorial's 600 and 500 are both `strong`, IBM Plex Sans Medium, since the look ships only Regular
  and Medium (`fonts/ibm-plex-sans/`; `looks/editorial.lua:12-14`), as device-menus mapped 600. Diner's 800
  is `display` and 700 is `strong` (`looks/diner.lua:11-15`).
- Diner's active label and icon are `on_accent`, the dark text the look puts on mustard (`looks/diner.lua:34`,
  `:53`), so the night mustard block keeps dark text; by day it is the board's ink.
- The boards' icon strokes are 1.5/1.7 (Editorial) and 2/2.2 (Diner); the registry's files are stroke 2
  (`spec/unit/icons_spec.lua:95`). A planned difference, as device-menus' chevrons were. Icons are drawn with
  `TintedIcon` in the token's colour (`tinted_icon.lua:1-5`).
- Editorial's edge stays 1 px on the Paperwhite. The direction doc's "hairlines thicken to 2 px" is declared as
  `stroke.hairline_grey` (`looks/editorial.lua:78`), but no module reads it today (`grep -rn hairline_grey
  kopanda.koplugin` finds only the two look files), so every 1 px line Editorial draws stays 1 px in grey; the
  bar does the same.
- D7: Diner's `home.footer.height` becomes 0 (NavBarC:70 draws no stripe; `looks/diner.lua:190-198` today), and
  `Layout`'s footer then has no height (`layout.lua:121-126`). Editorial's `home.margin.bottom` becomes 20
  (NavBar:19, :61; 36 today, `looks/editorial.lua:168`).

### The bar's geometry

- **Height** (device px), per look: `edge + max(0, rule − edge) + padding_top + icon_size + icon_gap +
  label + padding_bottom`, each length scaled, `label` the height of one `nav_label` line set by `Typeset`
  (`typeset.lua:49`) with no `text_size` in its ctx, so `Layout.font_size` scales it by 1
  (`layout.lua:278-283`; D8). The `max` term is Editorial's active rule: 3 px laid from the bar's top over the
  1 px edge (the board's `margin-top: -1px`, NavBar:69), which makes the board's grid row 2 px taller; every
  tab's content starts at that one top, so the active tab's icon lines up with the others.
- **The boards' heights differ.** Editorial: 1 + 2 + 16 + 26 + 7 + an 11 px Plex line + 18 = 70 + label;
  Diner: 4 + 14 + 28 + 6 + a 12 px Bricolage line + 16 = 68 + label. Hence per-look heights and the relayout
  below.
- **Columns:** the width less `2 × padding_x`, split into five by `Layout.columns` with share 1 and no gap
  (`layout.lua:22-42`), so the columns fill it exactly.
- **A tab:** its icon centred in the column at the content top, the label centred under it after `icon_gap`;
  a label wider than its column is cut by `Typeset.line`'s `max_width`.
- **Drawing order:** the fill over the bar; the active tab's fill (Diner) over its column below the edge;
  the dividers (Diner) at the right of tabs 1-4, from below the edge to the bar's bottom; the edge across the
  full width; the active rule (Editorial) over the active column from the bar's top; then icons and labels.
- The bar builds from `{ look, variant, active }` and paints with `Looks.palette(look, variant)`
  (`looks.lua:63-76`) through `Looks.color`; it never names the palettes itself, which `night_mode_spec.lua`'s
  scan for the word `palettes` keeps true.

### The home

- **The band:** `Layout.arrange` places the rows, the footer and the free height in `screen height − bar
  height` (`layout.lua:170`, `:212`, `:245-257` today use the full height), and returns the band as
  `arranged.nav = { x = 0, y = height − bar, w = width, h = bar }`. `Layout.fits` and `Layout.overflow` go
  through the same `arrange` (`layout.lua:268-276`), so edit layout's fit refusals count the band. The bar's
  height is `NavBar.height(look, screen)`, scaled by the screen the layout scales by (`Layout.screen`,
  `layout.lua:13`).
- **Drawing:** `HomeRows.build` (`home_rows.lua:80-135`) builds the bar with Home active at `arranged.nav`
  after the chrome, so it paints last. A bar that fails to build is logged and its band left blank; the rows
  still build.
- **Gestures:** `HomeGestures.route` (`home_gestures.lua:127-160`) gains one step after the home's own swipe
  up (`:133-136`) and before the file manager's menu zones (`:139`): when the own step is `tap` or `hold` and
  the gesture lies in `arranged.nav`, the bar handles it (a tap runs its tab, a hold nothing) and the gesture
  is consumed. Gestures' corner zones, registered on the file manager (`plugins/gestures.koplugin/main.lua:1287-1288`)
  and run at `home_gestures.lua:145`, never see it (D4). Today the bottom-left eighth (KOReader's `defaults.lua:68`) toggles the
  frontlight by default on any device with one (`plugins/gestures.koplugin/defaults.lua:9`), the emulator
  included (`frontend/device/sdl/device.lua:157`), which would otherwise take most of the Home tab.
- The bar's step reads the own step the home's touch zones set, so under the touch lock nothing reaches it
  (`home_gestures.lua:47-54`, `:128-132`).
- **Sheets and editors:** a sheet still sits on the screen's bottom edge less its inset (`sheet.lua:362-364`),
  over the bar; edit layout and launcher management still cover the screen. Neither changes.

#### Fitting the default home above the bar

Open fact **F1**, for `home-band` to settle first. The band costs
about 175 device px on the Colorsoft (70 or 68 board px plus a label line of roughly 14, ×2.107), less what D7
gives back (Diner's 26 px footer, Editorial's 16 px of margin). Reading the committed goldens by eye,
`spec/goldens/home-diner-colorsoft.png` has its last row ending about 10 px above the footer's edge and
`home-editorial-paperwhite.png` about 30 px of free height before its last row, so the default layout may
leave out its last rows in both looks. The nav boards themselves draw a shorter home: Editorial without the
launcher (NavBar:19-65), Diner without the quote and with one row of three tiles (NavBarC:19-68).

- **How to settle:** a unit case computing `Layout.overflow(default rows, ctx)` with the real widgets at
  the Colorsoft (`harness.at_colorsoft`) and the Paperwhite size, both looks, each `text_size`, on the
  populated and empty fixtures' content (the featured title, the quote). At the Paperwhite the device
  screen itself must answer as the Paperwhite's, as `at_colorsoft` does for the Colorsoft
  (`spec/plugin_harness.lua:151-178`, its size fixed at `:155`): text is measured by `Font:getFace` at the
  device screen's scale (`frontend/ui/font.lua:276`), which a `Layout.screen` stand-in
  (`spec/unit/layout_spec.lua:14-21`) does not change.
- **Candidates:** (a) nothing drops at any size; (b) rows drop only at `large`; (c) rows drop at `medium`.
- **What follows** (owner, 2026-10-16: tighten the home's spacing): for (a), go on. For (b) or (c),
  `home-band` tightens the looks' home vertical tokens (row gaps, header and bottom padding, the
  launcher's tile height), in both looks, by the smallest steps that make the default layout drop nothing
  at `small` and `medium` on both profiles with the populated and the empty content. Every row stays; the
  default `layout.rows` does not change. The new values go in the looks files with a comment naming this
  decision, in the PR body, and in the regenerated home goldens the owner looks at. Rows still left out at
  `large` after that are reported with their counts in the PR, not tightened further.

### The file browser

#### The patch

`FmNav.install()` wraps `FileManager.setupLayout` once per process, behind a module-local flag, as
`DispatchBridge.install` wraps `Dispatcher.execute` (`dispatch_bridge.lua:33-58`). `KoPanda:init` calls it
when it is in the file manager and not refused, beside `DispatchBridge.install()` (`main.lua:72-102`).
Plugin instances are made before the first layout (`filemanager.lua:418-429`, then `setupLayout` at `:431`),
so the wrapper is in place for it. A refused instance never installs; another shell's own patch then stands
alone.

What KOReader does that the wrapper relies on:

- `setupLayout` (`filemanager.lua:116-359`) builds the title bar (`:118-136`), then `FileChooser:new{ name =
  "filemanager", ... }` with no `height` or `width` (`:138-154`), keeps it as `self.file_chooser` (`:155`),
  puts it in `fm_ui`, a `FrameContainer` with no padding or border (`:346-351`), sets `self[1] = fm_ui`
  (`:353`) and `self.layout = file_chooser.layout` (`:356`).
- It runs from `init` (`:431`) and `reinit` (`:789-810`, `:802`), which is also `rotate` (`:812`, reached from
  `onSetRotationMode`, `:71-79`) and the keyboard connect handlers (`:816-817`); nothing else in
  `frontend/apps/filemanager/` calls it.
- `FileChooser` extends `BookList`, which extends `Menu` (`frontend/ui/widget/filechooser.lua:18`,
  `frontend/ui/widget/booklist.lua:11-16`); `FileChooser:init` calls `BookList.init`, which calls `Menu.init`
  (`filechooser.lua:98-106`, `booklist.lua:276-279`). `Menu:init` sets `dimen.h = self.height or screen
  height` (`frontend/ui/widget/menu.lua:701-704`), its inner height from that (`:706-710`), its item height
  from the inner height less title and footer at its items per page (`:655-691`), and lays its page footer and
  return arrow on the inner height's bottom (`:893-924`). So a shorter chooser keeps its items per page,
  shrinks each item and puts its footer above the bar.
- A field read through an instance falls back to its class: `Widget:new` makes the instance's metatable the
  class (`frontend/ui/widget/widget.lua:26-48`).

The wrapper, in order:

1. Unless this file manager has KoPanda's instance and it is not refused, the original runs alone.
2. **Before:** the band's height for the active look, `NavBar.height(Looks.active(), Screen)`, and the time.
3. **During:** `FileChooser.height = Screen:getHeight() − band` is set on the class, the original
   `setupLayout` runs in `pcall`, and the class field is put back to what it was (nil) on every path. The
   chooser built inside reads it at its `init`; nothing else is built from `FileChooser` there.
4. **After:** `fm[1]` becomes `FmNav`'s frame: the original `fm_ui` at (0, 0) and a bar with Library active
   at (0, height − band), its dimen the screen. The bar comes first among the frame's children, so a gesture
   reaches it before the chooser; it paints after the chooser. `fm.layout` stays the chooser's.
5. The frame remembers the look and variant it was built with and the band it reserved.

Why the class field and not `FileChooser.init`: it patches one function instead of two, nothing remains on
`FileChooser` once the call returns, so a `PathChooser` (a `FileChooser`) or any chooser built later can never
see it, and it rests on the same KOReader fact (`menu.lua:701`). The cost: `Menu:onScreenResize` re-runs
`init` (`menu.lua:1316-1319`) and would build at full height; `ScreenResize` is sent only by the SDL and
Android ports on a window resize (`frontend/device/sdl/device.lua:314`, `frontend/device/android/device.lua:169`),
never on the Kindle, so it is not handled.

#### Events in the file browser

- `WidgetContainer:handleEvent` offers an event to its children before its own handler
  (`frontend/ui/widget/container/widgetcontainer.lua:80-107`), and `InputContainer:onGesture` tries touch zones
  and then `ges_events` (`inputcontainer.lua:266-285`). The bar, inside `fm[1]`, therefore sees a gesture
  before the file manager's own zones, Gestures' corners among them (`plugins/gestures.koplugin/main.lua:985-990`,
  `:1287-1288`): D4 holds in the file browser by position, with no override list.
- The chooser's hidden return arrow lets a bottom-left tap through (`return_arrow_propagation`,
  `filemanager.lua:145-146`); it now sits above the band.

#### Night mode, a look change and rotation

- **Night mode:** the frame's paint compares its variant with `Looks.variant()` and, when it changed, rebuilds
  the bar before painting, as the home does (`home.lua:282-291`): a toggle reaches widgets before the screen
  flips and then repaints everything (`HOOKS.md:397-433`).
- **A look change:** the one runtime writer of `look` is the settings menu's write (`menu.lua:51-69`; the other
  `Settings.set` callers write `featured.pinned`, `layout.rows` and `launcher.entries`). After it stores a new
  look, it calls `FmNav.relayout()`, guarded: with `FileManager.instance` carrying the bar, `fm:reinit()`
  (`filemanager.lua:789-810`), which re-runs the wrapped `setupLayout` at the new look's band and keeps the
  folder and its page items (`:795-804`), then `UIManager:setDirty(fm, "ui")`. With no file manager (the menu
  opened from a reader) it does nothing; the next file manager builds in the new look.
- **Rotation:** `onSetRotationMode` reaches `reinit` (`filemanager.lua:71-79`, `:812`), so the band and bar
  follow at the new size with no handler of KoPanda's. The home's own rotation handling is unchanged.

#### The settled signal

After a paint of the frame, from `tickAfterNext`, when the file manager is the topmost window
(`UIManager:getNthTopWidget(1)`, `frontend/ui/uimanager.lua:832`) and this frame has not signalled yet, `UIManager.event_hook:execute(
"KoPandaSettled", { screen = "file_browser", paint_ms })`, as the home sends its own (`home.lua:159-199`).
`paint_ms` is the wrapped `setupLayout`'s duration plus that paint's: KOReader's and KoPanda's time to build
and draw the file browser, without the time it sat under the home. At start the file manager is usually
covered by the home before its first paint; a frame painted while covered sends nothing and waits for a paint
on top.

### Failure behaviour

Every hook fails safe, so KOReader's file browser stays usable, as the home's entry points do (`home.lua:39-47`,
`:205-224`, `:295-307`, `:338-346`; `main.lua:261-268`) and the dispatch bridge does (`dispatch_bridge.lua:33-58`):

- **Install** raising: logged by `KoPanda:init`'s `pcall` (`main.lua:73-101`); the original stays.
- **Before** (the band) raising: logged; the original runs alone, full height.
- **The original's own error:** the class field is put back and the error re-raised unchanged
  (`error(err, 0)`), so KOReader's failure stays KOReader's.
- **After** (the frame) raising: logged; the original's result stands, `fm[1]` its `fm_ui`, leaving a blank band
  of paper where the bar would be. The file browser works.
- **The bar's paint** raising: logged once per frame; the chooser still paints; the band stays blank.
- **A tab's run** raising: logged; the tap consumed; the screen as it was.
- **`relayout`** raising: logged; the file browser keeps its layout until the next one.
- On the home, a bar that fails to build leaves its band blank (above); a raising gesture step already closes
  the home onto the file browser (`home.lua:338-346`).

### Upgrade tripwire and HOOKS.md

This is the first feature a KOReader upgrade can break by moving code (design §8,
`2026-10-13-kopanda-design.md:256-258`). Two guards:

- **A tripwire case** in `fm_nav_spec.lua`, run against the emulator's KOReader by `bin/check`: the unwrapped
  `FileManager.setupLayout` is defined at `frontend/apps/filemanager/filemanager.lua:116` (`debug.getinfo`'s
  `source` and `linedefined`); after the original runs on a file manager, `fm[1]` is a `FrameContainer` whose
  only child is `fm.file_chooser`, the chooser's `name` is `"filemanager"`, and a chooser built with
  `FileChooser.height` set has that `dimen.h`. Any upgrade that moves or reshapes the function fails it, and
  the upgrade chore walks this entry before changing the pin.
- **`HOOKS.md`** gains a section for the patch: `setupLayout` and its chooser, `fm_ui` and `layout`
  (`filemanager.lua:116-359`), its callers (`:431`, `:789-817`, `:71-79`), `registerModule` and the instance
  name (`:379-389`, `:418-431`), `Menu:init`'s height (`menu.lua:655-710`, `:893-924`), `onScreenResize`
  (`:1316-1319`), the class-field fallback (`widget.lua:26-48`), the event order
  (`widgetcontainer.lua:80-107`, `inputcontainer.lua:266-285`), Gestures' bottom corners
  (`plugins/gestures.koplugin/defaults.lua:9`, `main.lua:985-990`, `:1287-1288`; KOReader's `defaults.lua:68`) and
  `UIManager:getNthTopWidget` (`frontend/ui/uimanager.lua:832`). `spec/unit/hooks_doc_spec.lua:86-102` checks each entry cites a `file:line` and every
  required module is named.
- `spec/plugin_harness.lua` restores the unwrapped `setupLayout` on every load, as it restores
  `Dispatcher.execute` (`spec/plugin_harness.lua:57`, `:72`), so the wrapper never stacks across specs.

### Goldens and budget

- Every home golden changes: the ten home goldens, the two night goldens and the four sheet goldens over the
  home are regenerated on purpose and each opened before commit. The device-menus-style "home goldens
  unchanged" criterion does not carry over. They are regenerated by `home-band`, the task that changes the
  home, since every task's tests gate is the whole `bin/check` (`.tiller/tiller.yml`, `gates.required.tests`).
- New: `filebrowser-diner` and `filebrowser-editorial` on `colorsoft` and `paperwhite`, the populated fixture's
  library, shot on `KoPandaSettled{ screen = "file_browser" }`.
- Unchanged: the four editor screen goldens (the editors cover the screen), the swatch and the probe goldens.
- **Budget:** each file-browser capture's `paint_ms` is at most 250 ms, the home's tripwire
  (`spec/emulator/home_capture_spec.lua:7-10`), and the home's own budget still holds with the bar in it.
- Open facts for `goldens`, which adds the file-browser captures: **F3**, whether the file browser's title-bar subtitle shows a path that differs by
  checkout, and **F4**, whether CoverBrowser's covers in the list make the capture non-deterministic; each with
  its candidates in the task.

### SimpleUI, for contrast

SimpleUI 2.7.5 as installed wraps `FileManager.setupLayout` once behind a class flag
(`infra/sui_patches.lua:285-293`, `:359`), calls the original unguarded (`:547`), then wraps `fm[1]` with its
bar (`:737-739`). It shortens every `FileChooser` with neither height nor width by patching
`FileChooser.init` (`:411-417`), registers touch zones on the file manager that override the bottom corners
(`screens/sui_bottombar.lua:1037-1043`, `:1249-1250`, registered at `:1285`), and opens its settings on a hold of the bar
(`:1239-1253`, `:1254-1282`).
KoPanda narrows the height to the file manager's chooser for one call, guards its own work, wins the corners
by child order, and consumes holds.

## Notes

The draft's `infra/sui_patches.lua:423` "at 61b71da, MIT" did not match the copy on disk, where `:423` is the
`FileChooser.changeToPath` patch; the clones are gone (`~/Projects/kodev/HANDOFF.md:25`). Since nothing is
lifted, the installed copy is cited for contrast only.

Specs whose probe points move above the bar, on purpose (D4): `spec/unit/gesture_routing_spec.lua:232-254`
(its corner cases tap at `(w − 10, h − 10)` and `(10, h − 10)`, now inside the bar);
`spec/unit/failsafe_spec.lua:510-531` (a corner tap at `(w − 10, h − 10)`); and the emulator scenario
`spec/emulator/scenarios/2-scenario-gesture-forward.lua:68`. Each probes a corner zone, which still reaches
the file manager's zones above the bar; inside the bar the bar wins. `gesture_routing_spec.lua:303-328` taps
the stats slot's bottom-right less 5 (`:319-322`), so its probe follows the slot, but its stub heights
(`:305-306`, 0.67 × h for weather and stats) end the last row at about 728 of the unit screen's 800 under
Diner (row 1 60 + 36 + 28 + 4, two 22 gaps, the quote's 20, 536), which no longer fits above the band, so
the row would drop; its heights change so the row ends inside the corner eighth above the band. `spec/unit/layout_spec.lua:249-257`
(Diner's footer) and `:320-343` (placement at the full 1680) change with D7 and the band.

For the owner, each a default the lead chose that you can overturn at approval:

- **F1, if the default home doesn't fit** (above): the home's vertical spacing tightens until it fits at
  `small` and `medium` (your decision); what `large` still leaves out is reported, not tightened further.
- **Editorial's active tab content** lines up with the others; the board's −1 px margin would drop it 2 px.
- **Diner's active label** uses `on_accent`, ink by day and dark at night, rather than the night ink (cream)
  on the night mustard.
- **Editorial's edge stays 1 px on the Paperwhite**, like every other 1 px Editorial line today.
- **A look change re-lays the file browser out** (`fm:reinit()`), since the looks' bars differ in height.
- **Sheets keep their place** on the bottom edge, over the bar.
- **History from the home** shows over the home, as the launcher's History does; its close returns to the
  home, not the file browser.
