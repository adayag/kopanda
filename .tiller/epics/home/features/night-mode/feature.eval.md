---
node: F-4jh8sz
criteria:
  - id: C1
    statement: "Looks.variant() answers \"night\" when Screen.night_mode is on and the screen renders colour, \"grey\" on a screen without colour with night mode on or off, and \"day\" otherwise"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C2
    statement: "Looks.palette(look, variant) returns the look's own day and grey palettes; for night it returns, for each role of both looks, the per-channel inverse (ff - x) of the night palette's #rrggbb, false roles staying false, so inverting each value again gives the designed night colour; the look tables, looks/editorial.lua and looks/diner.lua are left with exactly the day, grey and night palettes"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C3
    statement: "No plugin module except looks.lua and swatch.lua indexes a look's palettes directly; the home, typeset.lua and every widget resolve colours through Looks.palette(ctx.look, ctx.variant)"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/night_mode_spec.lua" }
    required: true
  - id: C4
    statement: "On a colour screen stub with a software-inverted blitbuffer: a home built with night mode on leaves the designed night paper in the buffer's stored pixels at its paper corner, and the designed night ink, not the day ink, in its clock and quote text; a home built by day and painted after night mode turns on rebuilds inside that paint, so its first paint stores the night paper, and it calls no setDirty of its own; turning night mode off again gives the day paper on the next paint; a pre-built home taken after the variant changed is dropped; on a grey screen stub, toggling night mode causes no rebuild"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/night_mode_spec.lua" }
    required: true
  - id: C5
    statement: "With night mode on, a featured cover of known pixels painted through the featured widget onto a software-inverted blitbuffer leaves the cover's own pixels in the stored buffer, inverted once by KOReader's ImageWidget and not again by the plugin, while the cover frame and the typographic placeholder take the inverse night roles"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/night_mode_spec.lua" }
    required: true
  - id: C6
    statement: "With night mode set at start, the committed home-night-diner and home-night-editorial goldens on colorsoft match a fresh capture of the populated fixture; each capture's paper corner is the look's designed night paper (#1e1c1a, #15161a) within the compare tolerance; on paperwhite with night mode on, the capture outside the featured cover's rectangle is the pixel inverse of the committed day paperwhite golden of the same look, and inside it matches that golden un-inverted, both within the compare tolerance and the day golden's masks"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/night_golden_spec.lua" }
    required: true
  - id: C7
    statement: "A freshly built populated night home's paint_ms is at most 250 ms on colorsoft in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/night_golden_spec.lua" }
    required: true
  - id: C8
    statement: "In the emulator, from a settled day home, toggling night mode through the menu's ToggleNightMode broadcast and, in a separate run, through Dispatcher's night_mode action paints the home exactly once before the next settled signal, and that capture matches the night golden of the look"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/night_toggle_spec.lua" }
    required: true
  - id: C9
    statement: "With night mode off, every committed day home golden still matches a fresh capture, and this feature regenerates none of them"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    baseline:
      surface: "spec/goldens"
      captured_at: { kind: git_tree, value: "git:e085463", path: spec/goldens, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C10
    statement: "Every hook still fails safe: an error thrown by the home's build, paint, gesture or event handlers, a build that raises while paintTo rebuilds for a new variant included, is logged, leaves no home on the stack, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:e085463", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C11
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including Screen.night_mode, ImageWidget's night-mode inversion and the toggle's event path; no KoPanda module path collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:e085463", path: kopanda.koplugin, observed_at: "2026-10-15T00:00:00Z" }
    required: true
  - id: C12
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C13
    statement: "The owner has opened both night goldens and the Paperwhite night capture and confirms they read as NightA.dc.html and NightC.dc.html intend: the night paper, ink, muted and text roles, Editorial's hairlines and cover outline, Diner's teal band, cream outlines and shadows, the cover in its own colours, and the Paperwhite as a plain dark grey, legible and unclipped"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C14
    statement: "The owner has run the home in the emulator, turned night mode on and off from KOReader's menu and from a gesture bound to Toggle night mode, and seen the home repaint once each time straight into the other palette with no frame of the old one; and has opened the swatch with night mode on and seen its inversion note"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `home-layout` and `featured-book` have merged. Ref-only `test` bindings
resolve to `bin/check <spec file>`, which passes spec paths straight to Busted with no luacheck. C12 is
the lint stage alone. The tests gate's own `bin/check` run covers the whole suite.

C1 and C2 extend `looks_spec.lua`. C3 to C5 are a new `night_mode_spec.lua` on KOReader's LuaJIT under
the plugin harness. It stubs `Screen.night_mode`, colour and the inverse flag of a real blitbuffer, and
reads that buffer's stored pixels, which are what the panel shows on the software path. C5 needs
`featured-book`'s cover widget, hence the feature's dependency on it.

C6 and C7 are a new `night_golden_spec.lua`, whose capture driver starts the emulator with `night_mode`
in the scratch `settings.reader.lua`. C8 is a new `night_toggle_spec.lua` with its own scenario patch. C6's
Paperwhite check reuses the day Paperwhite goldens rather than committing night ones, because grey screens
keep the grey palette under KOReader's inversion.

C9 to C11 are preserve criteria. Their recorded baseline is `e085463`, the commit this feature was
specified on. Because this feature depends on `featured-book`, the state they preserve is `featured-book`'s
merge into `main`, which changes the day goldens, `home.lua` and `HOOKS.md` after `e085463`. The first
task records that merge's sha in its PR as the effective baseline. The bar for C9 is that this feature
leaves those day goldens byte-identical. C10 adds the rebuild-in-paint path to the fail-safe net.

C7 rests on an open fact, whether the emulator's Lua-blit night paint fits in 250 ms. The `goldens` task
stops and asks if it doesn't, rather than move the budget.

C13 and C14 are the human checks. C13 is the look at goldens before they are committed. C14 covers the
live toggle that the scenario drives programmatically, through a real gesture binding.
