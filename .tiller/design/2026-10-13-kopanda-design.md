# KoPanda — design (2026-10-13)

KoPanda is the owner's own interface for KOReader: a plugin that replaces the shell (home screen, then
navigation bar, bars, library) and a desktop studio that edits the same settings the plugin's on-device
menus edit. It succeeds KOReader Theme Studio, which styled SimpleUI and Bookshelf from outside; the
owner judged that studio too much machinery for the payoff and chose to own the renderer instead.

## 1. Decisions (2026-10-13)

| # | Decision | Alternatives considered |
|---|---|---|
| 1 | New repo and project; the theme studio is left where it is and may be archived | finish the studio's delivery epic and freeze; keep the studio and add a custom-module loader |
| 2 | Home screen content: featured book with cover and progress, text widgets (date, clock, weather, quote, reading stats), launcher with icons. No shelf rows of covers | cover rows (needs a grid engine and a cover cache) |
| 3 | Settings are editable both on the device and in a desktop web app, from one schema | theme file only; device menus only; hardcoded |
| 4 | Target is the whole shell: home, nav bar, top and quick-settings bars, library layouts and context menu | home only; home plus nav bar |
| 5 | Built from scratch, staged, lifting MIT-licensed pieces of SimpleUI where they fit | fork SimpleUI |
| 6 | One repo holds the plugin and the studio | two repos |
| 7 | Home layout is rows of one to three columns | single ordered stack; free grid |
| 8 | Tiller runs the project from the start | plain docs and PRs; Tiller after stage 1 |
| 9 | Name: kopanda. Repo `~/Projects/elatedpanda/kopanda`, plugin `kopanda.koplugin`, settings dir `settings/kopanda/` | |
| 10 | Two looks, Editorial and Diner, ship from stage 1 as a first-class `look` setting, Diner the default; widgets draw only from look tokens. Details, tokens and the gesture vocabulary: `2026-10-13-kopanda-ui-direction.md` | one default look now; a third direction, Cover first, drawn and dropped |

## 1a. Principles (owner, 2026-10-13)

The advantage of owning the shell is choosing what not to make configurable. Watching the theme studio
expose SimpleUI's settings showed how many nested, interacting configurations that shell carries.

- **Few settings, strong defaults.** The default look is the owner's look. A key enters the schema
  only when the owner has wanted to change that thing on a real device; "someone might" is not a
  reason. Each feature spec names its keys and justifies each one. No per-slot icon scales, no
  linked-scaling modes, no per-module chrome options. The studio stays a short form over a short
  schema, not a control panel.
- **Context-aware interactions, ZenOS style.** One gesture vocabulary everywhere: tap acts, hold
  opens a menu for the thing held, and the menu's actions depend on what it is (a book, a folder, a
  widget, empty space in the current folder). Launcher entries can offer KOReader's own menus for the
  current context (library or reader). Behaviour adapts to context so that settings don't have to.

## 1b. Second-pass decisions (2026-10-13)

Owner's decision: **placeholder entries.** Series and Authors are on the stage-1 home screen and nav
bar as entries that exist before their screens do. Tapping one shows a short "coming with the library"
note and returns. Their screens (a series list and an author list built from CoverBrowser's metadata
database) land with stage 5. The same rule applies to any later entry: the launcher never hides an
entry because its destination isn't built yet.

Owner's decision: **the studio is the switch-over gate.** The Kindle stays on SimpleUI until stage 2
is done; stages 1 and 2 are proven in the emulator. So stage 1 needs no device push beyond a one-off
hand push of the swatch screen, and the Wi‑Fi pull arrives with the studio. Stages 1 and 2 together are
the MVP.

Owner's decision: **the Paperwhite is another household member's.** A person is a device profile in
the studio with its own settings file (launcher, widgets, look); the plugin stores nothing beyond its
own settings file on each device, so no person layer exists on the device. Stage 2's MVP targets the
Colorsoft; the Paperwhite profile and its push follow, and the grey variants of both looks are drawn
for it already.

Working defaults, adopted unless a stage spec overturns them:

- **Native for the MVP:** Book details, Read status, History and the file browser are KOReader's own
  screens. Stage 1 adds a Home entry to the file manager's menu and registers a dispatcher action so a
  gesture can return to Home before the nav bar exists.
- **No paging.** Edit layout has a height budget and refuses a row that won't fit, instead of paging
  the home screen.
- **Portrait goldens, fluid landscape.** Landscape is allowed (rotation lock exists) and must not break,
  but only portrait is golden-tested until a landscape need appears.
- **Looks are edited in Lua.** The owner chose the studio's MVP as the schema form, the emulator preview
  for both looks on both profiles, and the Wi‑Fi push; a look editor is after the MVP.
- **Coexistence.** KoPanda refuses to start its shell while SimpleUI, Bookshelf or ennUI is enabled, and
  says which. The emulator's own `plugins/` must have them disabled before KoPanda's tests run.
- **Settings file carries a schema version;** every schema change ships a migration and a test.
- **Covers fit inside the frame,** centred, paper showing on the short side; titles cap at two lines
  with an ellipsis.
- **Reading data** comes from KOReader's Statistics plugin database (streak, minutes today, books this
  month, reading speed for "time left"); with no speed, time left falls back to pages left; with the
  plugin disabled, the stats widget says so.
- **Quotes** ship as a curated public-domain file in the plugin; "My highlights" aggregates sidecars later.
- **Weather location** is coordinates, geocoded once from a typed place through Open-Meteo's free
  geocoding endpoint; no key anywhere.
- **Fonts ship as static instances** at the weights used, not variable fonts, until KOReader's font
  stack is shown to expose axes.
- **First thing on the Kindle is a swatch screen:** both palettes, both night palettes, both greys. The
  token values are finalised from the panel, not the boards.
- **Dev loop:** check whether KOReader's SSH plugin runs on the Kindle; if so, stage 1 pushes by scp.
- **Fixture books** for goldens are public-domain EPUBs with known covers, pinned.
- **Paint budget:** the home screen has a paint-time test as well as goldens; closing a book must land
  on it without a visible wait (ennUI's prebuild-on-close pattern).
- **Boot guard:** a home screen that didn't finish drawing last start is skipped once, with a notice
  (ennUI's `boot_pending`).

## 2. References read

Clones live in a scratch folder, never in the repo. Line numbers below are from these commits.

| Plugin | Version | Commit | Lua lines | Licence | What it is to us |
|---|---|---|---|---|---|
| ennUI (critterforks/ennUI.koplugin) | 1.0.0 | ae26fc4 | 3,600 | none | Structure and KOReader hooks of a home screen at our stage-1 size. No licence file: read, don't copy |
| SimpleUI (doctorhetfield-cmd/simpleui.koplugin) | 2.7.5 | 61b71da | 80,400 | MIT | The shell the owner likes; the source of liftable pieces and of the patch map for stages 3–5 |
| ZenOS (xZenLabs/zen-os) | 4.1.0 | d3cbff3 | 121,000 + 95,000 test | GPL-3.0 | The model for the test harness. Copying code makes KoPanda GPL; read, don't copy |
| KOReader | master e1fe1ac (2026-10-08), the kodev emulator build | | | AGPL-3.0 | The runtime. Pinned; upgraded deliberately (§8) |

Device and emulator facts (Colorsoft resolution, headless capture, `KO_HOME` profiles, fonts path, MTP)
are in `handoff-2026-10-08.md` §3–4 beside this file; they carry over unchanged.

## 3. Shape

One repo, two deliverables and one contract between them.

- **`kopanda.koplugin/`** — the plugin, Lua on KOReader's LuaJIT. The only thing that runs on the Kindle.
- **`studio/`** — a local web app on the stack the theme studio used (TypeScript, Node >= 22, Express,
  React 19, Vite, Vitest). Form editor over the schema, emulator preview, Wi-Fi push. Stage 2.
- **The schema** — pure Lua data inside the plugin (`kopanda.koplugin/schema.lua`): every settings key
  with type, default, range or choices, label, and the widget or screen it belongs to, plus the home
  layout (rows and columns). The plugin generates its on-device menus from it; the studio loads it as
  JSON (dumped by a LuaJIT one-liner at build time) and generates its form from it. Both write the same
  settings file under `settings/kopanda/`. A test asserts the studio's JSON equals a fresh dump.

Rules the whole project keeps:

- The screen redraws only on input. No background timers, no animations (ennUI's rule, the right one
  for e-ink).
- Every hook into KOReader is wrapped so a failure leaves KOReader's own file browser usable.
- No settings key exists outside the schema (a spec enforces it).
- KOReader internals the plugin reads or patches are listed in one file (`kopanda.koplugin/HOOKS.md`)
  with the `file:line` they were read from, and checked when KOReader is upgraded.

## 4. Stages

Each stage ships to the Kindle before the next starts. Stages are Tiller epics; features are
specified just in time.

1. **Home.** The plugin, the home screen, the schema, generated device menus, Lua specs, emulator
   goldens, hand push to the Kindle.
2. **Studio.** Form from the schema, emulator preview per device profile, Wi-Fi pull into the plugin
   with staged apply and rollback.
3. **Bottom navigation bar.** First patch into KOReader's file manager.
4. **Top bar, title bar, quick-settings bar.**
5. **Library layouts and context menu.**

Out of scope, don't re-suggest (carried from the studio): context-aware looks (per-book themes, time
rules), the CWNG library folder, the Xteink X4 Pro. Also out: publishing the plugin, i18n, the reader
(status bars, page browser, reader menus) and sleep screens; KOReader's own stay as they are.

Noted for after the MVP, not scheduled: Calibre-Web-NextGen as a library source (books not yet
downloaded, with covers and metadata cached by book id, download on tap), consuming icon packs through
the icon registry, to-be-read and collections, an Android profile. The UI direction doc has the detail.
Two of these shape stage-1 and stage-5 code now: the icon registry (below) and a book model that never
assumes a local file.

## 5. Stage 1: the plugin

Five modules, the division ennUI proved at this size.

**Entry (`main.lua`).** A `WidgetContainer` plugin with `is_doc_only = false`, so it loads in both the
file manager and the reader. It shows the home screen when the file browser appears and pre-builds it
as a book closes, the way ennUI does: `onShow` (ennUI `main.lua:62`) and `onCloseDocument`
(`main.lua:144`) call into a `showHome` (`main.lua:87`) that finds the live file manager through
`package.loaded["apps/filemanager/filemanager"].instance` and shows the home widget full-screen over it
(`main.lua:111`). The widget sets `covers_fullscreen = true` (ennUI `ennui_home.lua:108`) so KOReader
knows nothing beneath it needs painting. `onCloseWidget` on the plugin (`main.lua:131`) closes the home
widget when the file manager goes away, or KOReader can't quit. A dispatcher action and a Tools-menu
entry open the home screen and the settings. KOReader's own `start_with` setting
(`reader.lua:255`) is left alone: the home sits over whatever the file manager opens.

**Home (`home.lua`).** One `InputContainer` built from the schema's layout: rows, each with one to
three widget slots and width shares. Tap, swipe and hold gestures over the whole screen; swipe up from
the bottom edge opens settings (ennUI uses the bottom 12 %, `ennui_home.lua:33`); KOReader's own top
menu stays reachable in its tap zone (`defaults.lua:59`, top eighth of the screen). Pages if the rows
overflow. Gestures follow §1a: tap on a widget acts (open the featured book, refresh weather, run a
launcher entry); hold on a widget opens that widget's menu (its settings, and for the featured book the
book's actions: details, read status, collections); hold on empty space opens the home screen's own
menu (layout, settings, open the file browser).

**Widgets (`widgets/*.lua`).** Small tables: `id`, `build(width, ctx)`, `height(ctx)`, settings prefix.
Stage 1 ships date, clock, weather, quote, reading stats, featured book, launcher.

- *Featured book*: the most recent file in `ReadHistory.hist` that still exists on disk
  (`readhistory.lua:16`; ennUI's `lastBookFile` does the same, `ennui_home.lua:90`). Cover and metadata
  from KOReader's bundled CoverBrowser plugin: `BookInfoManager:getBookInfo(filepath, get_cover)`
  (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325`), which returns the cached cover or
  schedules extraction (`:422`). Progress from the book's sidecar via `DocSettings:open(doc_path)`
  (`frontend/docsettings.lua:221`), key `percent_finished` (the footer formats the same key,
  `readerfooter.lua:333`). SimpleUI's featured module uses the same manager (`module_currently.lua:641`).
  Assumption to verify in the first task: CoverBrowser is enabled on the Kindle and the emulator profile;
  if it isn't, the widget shows title and author without a cover.
- *Launcher*: entries are plugins, folders, collections, dispatcher actions. Icons are SVGs in
  `settings/kopanda/icons/`, rendered with `RenderImage:renderSVGImageFile(filename, width, height, zoom)`
  (`frontend/ui/renderimage.lua:338`); ennUI renders its icons through `renderImageFile` (`:28`).
- *Weather*: fetches when online, caches to a file, shows the cached line and its age offline. One
  fetch per KOReader session plus tap to refresh, as ennUI does.

**Schema (`schema.lua`).** Pure data, no functions. Types: boolean, integer with range, number, choice,
string, icon, path. Each key names its default, label and group. The layout section lists rows and their
slots. Fonts, colours, strokes, shadows and radii are not keys: they belong to a look.

**Looks (`looks/*.lua`).** One table per look (Editorial, Diner): faces, a palette by role, stroke
weights, shadow offsets, radii, tile and sheet styles, with a grey variant for grayscale panels and a
night palette. Widgets and chrome read every visual value from the active look and nothing else. The UI
direction doc lists the tokens. Night mode: KOReader inverts the framebuffer, so while it is on the
plugin draws the inverse of the night palette and pre-inverts cover bitmaps, and the panel shows the
night palette as designed (assumption; the first task verifies the inversion point and the cost).

**Icons (`icons.lua`, `icons/*.svg`).** A registry: every icon the shell draws has a stable id, a label,
the places it appears, and a default stroke SVG. Looks pick icons by id; icon packs, after the MVP, map
onto the same ids. Nothing draws an SVG by file name.

**Screens.** One build for every device. Layout is computed at runtime from the screen's width and
height, and every length goes through `Screen:scaleBySize`, which scales by the shorter edge over
600 px (`base/ffi/framebuffer.lua:414`). Rows fill the width; columns take their shares. Goldens are
per device profile (Colorsoft and Paperwhite first).

**Settings (`settings.lua`).** `LuaSettings:open(DataStorage:getSettingsDir() .. "/kopanda/settings.lua")`,
the KOReader API ennUI wraps in `ennui_store.lua`. Reads fall back to the schema default. Writes are
refused for keys the schema doesn't define.

**Menu (`menu.lua`).** Walks the schema and emits KOReader menu tables: toggles for booleans,
spinners for ranges, radio lists for choices, pickers for font, colour and icon. Hand-written menu code
only for what the schema can't express: ordering rows and slots, launcher entry management.

## 6. Stage 2: the studio

Carries forward from the theme studio what still earns its place and nothing else.

- **Form** generated from the schema JSON; a row editor for the layout.
- **Preview**: materialise the current settings into a scratch `KO_HOME` profile and capture the
  emulator headless at the profile's resolution. The capture patch gets simpler than the studio's,
  which waits on SimpleUI's private internals to know the screen has settled: KoPanda announces its own
  settled state.
- **Push**: the plugin gets a Studio menu entry on the Kindle (host:port of the Mac), pulls the plugin
  build and a settings bundle over Wi-Fi, verifies and stages them, and a restart applies with rollback.
  The theme studio's companion (`lua/themestudio.koplugin/apply.lua`, `sync.lua`) is the model and
  much of it ports.

## 7. Stages 3–5: patching the shell

SimpleUI's patch map (`infra/sui_patches.lua`) names the surfaces: `FileManager.setupLayout`
(overridden at `:423` and `:4712`; KOReader defines it at `filemanager.lua:116`, where it builds the
title bar `:118` and the file chooser `:138`), `FileChooser.init` (`:470`), `TitleBar.new` (`:1491`),
`Menu.init` (`:2910`), `UIManager.show` (`:1920`), plus `FileManager.reinit`, `paintTo`, `onHome`,
`FileChooser.changeToPath`, `onMenuHold`, `ReaderUI.showReaderCoroutine` and `Dispatcher.execute`.
Each stage's spec names exactly which of these it wraps, cites the KOReader line, and adds it to
`HOOKS.md`. Anything lifted from SimpleUI is lifted with its MIT notice.

## 8. Dev loop and tests

Two test layers, the ZenOS shape on tooling already present:

- **Lua unit specs with Busted**, run on KOReader's LuaJIT with the rocks KOReader ships for its own
  tests (`kodev test`, `koreader/kodev:911`; `spec/rocks` in the emulator build), under a fresh
  `KO_HOME` per run. Cover the pure parts: schema to menu tables, settings defaults and refusal, row
  layout maths, weather cache and offline fallback, launcher entry resolution.
- **Emulator goldens**: headless capture at Colorsoft resolution per device profile, status strip
  masked, regenerated only deliberately. Reuses the kodev capture recipe and the theme studio's
  driver pattern (`test/emulator/helpers.ts`, `lua/patches/2-kts-capture.lua`).
- **Studio**: Vitest, plus the schema-equality test (§3).

`bin/check` runs the Lua specs and luacheck (later also the studio's typecheck, lint and tests) and is
the project's one gate command. KOReader is pinned to the kodev build; upgrading it is a deliberate
chore: rebuild, run `bin/check` and the goldens, walk `HOOKS.md`, regenerate goldens on purpose.

Device loop: stage 1 pushes `kopanda.koplugin/` by hand (MTP single session per handoff §4, or the SSH
plugin if it runs on the Kindle). Stage 2 replaces that with the Wi-Fi pull.

## 9. Repo layout at stage 1

```
kopanda/
  AGENTS.md  CLAUDE.md  .tiller/
  kopanda.koplugin/   _meta.lua main.lua home.lua schema.lua settings.lua menu.lua widgets/ HOOKS.md
  spec/               Busted specs, emulator goldens, run script
  bin/check
```

## 10. Open questions

1. Weather location and units; which widget shows what for reading stats (Statistics plugin data or
   KOReader's history only). Ask when the weather and stats widgets are specified.
2. Colour on the Colorsoft: do widgets get per-widget text and background colours in the schema from
   stage 1, or greyscale first? Ask when the schema is specified.
3. Whether the SSH plugin runs on the Kindle (stage-1 push). Check on the device.
