---
node: F-yrw3g6
criteria:
  - id: C1
    statement: "When the file browser is shown with no pending home, the home is shown over it from the next UI tick with covers_fullscreen, above a history list opened synchronously after showFiles (start_with = history); closing the file manager closes the home; a reader instance never shows one; tapping the placeholder outside the top menu zone closes it and leaves the file manager on top"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/home_lifecycle_spec.lua" }
    required: true
  - id: C2
    statement: "A headless capture of kopanda.koplugin on each profile (colorsoft 1264×1680, paperwhite 1236×1648) is taken on the plugin's own KoPandaSettled signal: the sidecar has screen \"home\", a positive paint_ms, and kopanda among the loaded plugins, with no settle cap"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_capture_spec.lua" }
    required: true
  - id: C3
    statement: "The committed placeholder-home goldens match a fresh capture of kopanda.koplugin on both profiles"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    required: true
  - id: C4
    statement: "The owner has opened both committed placeholder-home goldens and confirms they show the KoPanda placeholder, full screen, with nothing of the file browser visible, at the right size for each profile"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C5
    statement: "CloseDocument in a reader instance builds a pending home without showing it; the next file-manager show puts that pending home on top synchronously from onShow, before any UI tick, and builds none; a reader instance's init drops a pending home; a pending home whose size differs from the screen's is dropped and a fresh one built"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/prebuild_spec.lua" }
    required: true
  - id: C6
    statement: "In the emulator, closing a fixture book lands on the home with the file manager's paintTo never called before the home's settled signal, the pre-built home shown, and the home's share (onShow to paint) at most 100 ms; the close-to-paint time is in the sidecar"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/book_close_spec.lua" }
    required: true
  - id: C7
    statement: "The file manager's menu has a Home tab at index 2 with the home icon that opens the home; both the file manager's and the reader's Tools menus have KoPanda with Home and Settings; the dispatcher action kopanda_home (\"KoPanda: home\") shows the home from the file manager, closes the book and lands on the home from the reader, and is consumed as a no-op by a home already up"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/entry_points_spec.lua" }
    required: true
  - id: C8
    statement: "With a user settings/filemanager_menu_order.lua whose KOMenu:menu_buttons omits kopanda_home, no Home tab and no orphan appear in tab 1 and the Tools entry remains; a saved filemanagermenu_tab_index of 2 or more is incremented exactly once per profile when the tab is first inserted"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/entry_points_spec.lua" }
    required: true
  - id: C9
    statement: "On the home: a swipe north from the bottom edge band (outside the side edge bands) opens the settings stub; a tap or south swipe in the top menu zone opens the file manager's menu; a mid-screen west or east swipe is consumed and leaves the file chooser's page unchanged; other gestures reach zones registered on the file manager; none of this happens in the file browser or the reader"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    required: true
  - id: C10
    statement: "In the emulator, a Gestures-plugin binding performed on the home runs its action, and the History it dispatches is shown by the file manager's History module over the home"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/gesture_forward_spec.lua" }
    required: true
  - id: C11
    statement: "With simpleui, bookshelf or ennUI (any case) among the enabled plugins, no home, tab, Tools entry, action or pre-build appears, and one InfoMessage per start names each conflicting plugin"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/guards_spec.lua" }
    required: true
  - id: C12
    statement: "boot_pending in settings/kopanda/state.lua is set before the first home show of a process and cleared after its paint or on its failure; a set flag at start skips the home once with a notice and clears the flag, and the next show displays the home"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/guards_spec.lua" }
    required: true
  - id: C13
    statement: "AGENTS.md Conventions states that runtime state lives in settings/kopanda/state.lua and is not a setting"
    polarity: introduce
    binding: { type: command, run: "grep -q 'settings/kopanda/state.lua' AGENTS.md" }
    required: true
  - id: C14
    statement: "Every hook fails safe: an error thrown by the home's build, paint, gesture or event handlers, the plugin's init and handlers, the menu-order insert, a menu callback, the state file or the Dispatcher wrapper (when installed) is logged, leaves no home on the stack, and leaves the file manager on top and handling input"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    required: true
  - id: C15
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    required: true
  - id: C16
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path. Ref-only `test` bindings resolve to `bin/check <spec file>`, which runs that spec
alone (`bin/check` passes spec paths straight to Busted, no luacheck); C16 is the lint stage alone; the
tests gate's own `bin/check` run covers the whole suite. C7 and C8 share one spec file, as do C11 and
C12; each criterion names the behaviour its describe blocks prove.

Unit specs run real KOReader code headless (a `FileManager` shown through `showFiles` on the dummy
screen, `fastforward_ui_events` for the UI loop, KOReader's own `spec/unit/commonrequire.lua`); the
emulator specs cover what only a real run shows: the settled capture, the goldens, the paint after a
book close, and whether a dispatched event survives the home on top.

C4 is the one human check: goldens are looked at, not only diffed, before they are committed.
