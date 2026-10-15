---
node: F-3ct1xn
criteria:
  - id: C1
    statement: "Both looks declare identical token paths including the sheet block's inset, padding, band colours, header and book-header padding, cover size, gaps, row padding and rules, chip colours and chip padding, and the eight sheet type parts; every new token keeps the look files' value rules, each colour token naming a palette role or false and each type part naming a face with a file and a role the look has; every palette of both looks has the role on_accent, Diner's #2f2e2b by day, #1e1c1a at night and #111111 in grey, Editorial's false in all three"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C2
    statement: "The sheet component, over a shown home: Editorial's panel spans the screen's width on its bottom edge under an ink rule, Diner's is inset from the sides and foot with an outline border, a hard shadow and its header band in the sheet's band colour; rows lie in order inside the panel with their icons, labels and details, Diner's status chip filled mustard where Editorial's detail is plain, a muted row in muted; a tap on a row closes the sheet before running that row once, a tap on the header runs nothing and keeps it, a tap outside closes it, runs nothing and never reaches the home's tap, a ticked row only closes; holds, hold_release and swipes do nothing; the Back key closes it on a device with keys and no key binding exists without keys, and a Back event closes it; showing a second sheet closes the first; showing calls setDirty once with ui and the panel's rectangle and schedules nothing, closing refreshes flashui over that rectangle and repaints the home; one KoPandaSettled with screen sheet, its name and a numeric paint_ms, counted from the show's opts.started when given and from the start of the show otherwise, follows the first paint, and none a failed paint; with night mode on, a Diner sheet stores the designed night band and on_accent colours under a software-inverted buffer, and a sheet built by day rebuilds inside its next paint after night mode turns on with no setDirty; a sheet too tall for the screen keeps the rows that fit and logs once; no plugin module but looks.lua, swatch.lua and the look files contains the word palettes"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/sheet_spec.lua", "spec/unit/night_mode_spec.lua"] }
    required: true
  - id: C3
    statement: "On the home over a real file manager: a hold outside every slot opens the home sheet over the home; a hold inside a slot whose module has hold calls it once with the home's ctx, the gesture and the slot's built widget, and a false return opens the home sheet; a hold inside a slot whose module has no hold opens the settings stub and no sheet; a hold zone on the file manager that consumes the hold wins over the home's step, and one whose handler returns nothing lets it through; KOReader's touch lock blocks the hold; a hold_release after the sheet opens changes nothing; the home closing closes its sheet"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    required: true
  - id: C4
    statement: "The home sheet is headed Home with the aside KoPanda and lists Edit layout, Open the file browser, Refresh weather, the Wi‑Fi row (U+2011 or a plain hyphen, per the glyph check), KoPanda settings and Sleep in order with their icons; Edit layout shows a note with no timeout and schedules nothing; Open the file browser closes the sheet and the home; Refresh weather calls Weather.tap with the home and shows the cached reading's age (20 min ago for a reading 20 minutes old, never fetched with none); the Wi‑Fi row shows Off with wifi_off when the fake Wi-Fi is off and On with wifi when on, toggles through NetworkListener:onToggleWifi once, and is muted with not available when the dispatcher lists no toggle_wifi; KoPanda settings opens the settings stub; Sleep sends RequestSuspend once to the file manager's DeviceListener and is muted with not available when the dispatcher lists no suspend; Weather.age gives never fetched, just now under a minute and for a future reading, N min ago under an hour, N h ago under 48 hours and N d ago from 48 hours; no case writes the settings file"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/home_sheet_spec.lua", "spec/unit/weather_spec.lua"] }
    required: true
  - id: C5
    statement: "A hold on the featured book opens the book sheet and a hold on the empty featured slot opens the home sheet; the book sheet's header carries the cover built by FeaturedCover at the token size with no extraction asked, the book's title and author, and the meta line of the shown percent, the recorded chapter and opened today, yesterday or N days ago by local calendar day, each part left out when unknown; its rows are Open, Book details, Read status, More by this author, Feature a different book and This widget's settings in order; Open calls the file manager's openFile with the file, Book details calls its bookinfo:show with the file, Read status shows KOReader's label for the book's status (New with no sidecar), More by this author shows the Authors are coming with the library note, and This widget's settings opens the settings stub; a hold on a book whose file has gone refreshes the home and opens no sheet"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/book_sheet_spec.lua", "spec/unit/featured_widget_spec.lua"] }
    required: true
  - id: C6
    statement: "The read status sub-sheet lists Reading, On hold and Finished from KOReader's genStatusButtonsRow with the current status ticked; a tap on another status writes it through KOReader's own calls, so the sidecar's summary.status and summary.modified are set, BookList's cache holds the status, other summary fields survive, the sub-sheet closes and the home refreshes once; a book with no sidecar ticks nothing and gains one on a tap; a tap on the ticked status writes nothing and closes it"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/book_sheet_spec.lua" }
    required: true
  - id: C7
    statement: "The picker lists The last one opened, then the six most recent history books that are still files, selectable and not the QuickStart guide, most recent first, with their titles and authors, and a pinned book older than those as a seventh row; its tick follows featured.pinned, the first row ticked with no pin or a pin to a gone file; a tap on a book stores that entry's realpath in featured.pinned, closes the picker, refreshes the home once and runs the featured slot's after_show once; a tap on The last one opened stores false; a tap on the ticked row and a refused write leave the settings file byte-identical; FeaturedBook.recent and describe raise nothing and write nothing"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/book_sheet_spec.lua", "spec/unit/featured_book_spec.lua"] }
    required: true
  - id: C8
    statement: "A tap on a launcher folder entry opens a folder sheet, with no note, headed with the folder's label and Folder · N; its rows are the folder's entries in order with their resolved icons and labels and their kind (KoPanda, KOReader, Plugin, Action, Folder on disk) at the right, an off entry showing off with wifi_off and an unavailable one muted with its suffix; a tap on a row closes the sheet and runs that entry as the home does, an action dispatching once, a directory opening the file browser there, Wi-Fi toggling and a missing plugin showing its note; a folder too long for the screen shows what fits and raises nothing; no case writes the settings file"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/folder_sheet_spec.lua", "spec/unit/launcher_entries_spec.lua"] }
    required: true
  - id: C9
    statement: "The committed sheet-book-diner, sheet-book-editorial, sheet-home-diner and sheet-home-editorial goldens on colorsoft match a fresh capture of the populated home fixture after a hold on the featured slot or on empty space, each taken on KoPandaSettled with screen sheet and the held sheet's name"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/sheet_golden_spec.lua" }
    required: true
  - id: C10
    statement: "Each of the four sheet captures has paint_ms at most 250 ms, from the hold to the sheet's first paint, in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/sheet_golden_spec.lua" }
    required: true
  - id: C11
    statement: "Every gesture the home routed before this feature routes the same way: the swipe up to settings, the file manager's menu zones, the consumed page swipe, zones registered on the file manager winning over the home's tap, a tap on a tappable slot running it, a tap elsewhere closing the home, the touch lock, and actions dispatched while the home is up reaching the file manager"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:f2ef10b", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C12
    statement: "In the emulator, closing a fixture book lands on the home with the file manager's paintTo never called before the home's settled signal, the pre-built home shown, and the home's share (onShow to paint) at most 100 ms"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/book_close_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:f2ef10b", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C13
    statement: "Every hook still fails safe, the sheets included: an error thrown by the home's build, paint, gesture or event handlers, by a widget's hold, or by a sheet's show, build, paint or a row's action is logged, leaves no home and no sheet on the stack, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:f2ef10b", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C14
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including the hold gesture, Gestures' hold corners, the sheet's refreshes and keys, genStatusButtonsRow, BookList's status calls, bookinfo:show, ReadHistory's time and the suspend path; no KoPanda module path, sheet, home_sheet, book_sheet and folder_sheet among them, collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:f2ef10b", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C15
    statement: "Every committed home golden still matches a fresh capture with no row dropped, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:f2ef10b", path: spec/goldens, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C16
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C17
    statement: "The owner has opened the four sheet goldens and confirms they read as HoldBook, HoldBookC, HoldHome and HoldHomeC intend for each look: Editorial's paper panel under its rule with hairline row rules and plain muted details, Diner's outlined box with its hard shadow, the pink and mustard bands and the mustard and teal chips, the small cover, title, author and meta line, every row's icon and label, legible and unclipped, over an undimmed home"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C18
    statement: "The owner has run the home in the emulator in both looks and, by day and with night mode on, held the featured book, empty space and another widget and seen the book sheet, the home sheet and the settings stub; tapped every row of both sheets; changed a book's read status in the sub-sheet and seen it ticked when reopened; pinned a different book from the picker, seen it featured, then chosen The last one opened and seen the most recent book return; tapped a folder entry written to the settings file and run an entry from its sheet; and closed a sheet by a tap outside and by the Back key"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `night-mode` and the tweak `split-home-lua` have merged. Ref-only `test`
bindings resolve to `bin/check <spec file>...`, which passes spec paths straight to Busted with no
luacheck (`bin/check` header, `run_busted ... -- "$@"`). A criterion that lists several spec files runs
them all. C16 is the lint stage alone. The tests gate's own `bin/check` run covers the whole suite.

C1 extends `looks_spec.lua` with the new paths and the `on_accent` role; the file's existing rules then
check every new token. C2 to C8 run on KOReader's LuaJIT under the plugin harness with a real file
manager under the home, spying or stubbing `UIManager`, `Dispatcher.getDisplayList`, `Device.hasKeys`
and the file manager's modules where a case needs it. C2 reruns `night-mode`'s `night_mode_spec.lua`,
whose scan for the word `palettes` covers the new modules. C3 extends `gesture_routing_spec.lua` with the
hold cases. C6 and C7 write real sidecars and a real settings file under the scratch `KO_HOME`. C8
changes `launcher_entries_spec.lua`'s folder case from the note to the sheet.

C9 and C10 are the four Colorsoft captures through the hold scenario, C10 their paint tripwire. The
folder sheet, the sub-sheets, grey and night are proved by the unit specs and by C18, not by goldens.

C11 to C15 are preserve criteria baselined at `main` `f2ef10b`. That is the latest commit with
`launcher` merged and no hold handling. `night-mode` and `split-home-lua` land between that baseline and
this feature, each keeping these checks green across its own merge (`night-mode`'s C9 to C11; the
tweak's "Done when"), so this feature only has to keep them green on top. C11 is the existing cases of the
same spec file C3 extends. C13 gains the sheet's failure cases beside the home's.

C17 and C18 are the human checks. C17 is the look at the goldens before they are committed. C18 covers
what the goldens and unit specs stub or can't show: KOReader's own book details page, a real status
write and pin seen on the home, the folder sheet, night mode, the Back key and Sleep's screensaver.
