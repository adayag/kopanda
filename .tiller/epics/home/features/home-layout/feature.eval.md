---
node: F-wkj9iy
criteria:
  - id: C1
    statement: "schema.lua still loads by a plain dofile with no require and no functions, at version 1, and its keys are, in order, look, text_size, layout.rows, weather.location, weather.units, quote.source, stats.show, with the types, choices, defaults and groups of the spec's Keys table; layout.rows carries widgets (date, clock, weather, quote, stats) and max_columns 3 as data, and its default is the spec's three rows; every type has a validator in settings.lua; no clock.twenty_four_hour key exists"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    required: true
  - id: C2
    statement: "Settings.set refuses, leaving the file byte-identical, a layout with no rows, a row with no slot or more than three, a widget not in the entry's widgets list, a widget twice, a share outside the integers 1-3, a slot with extra or missing fields; a location with an empty name, a latitude outside -90..90, a longitude outside -180..180 or an extra field; a non-boolean stats.show; accepted values survive a reopen; a stored invalid layout or location reads as the schema default"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/settings_spec.lua" }
    required: true
  - id: C3
    statement: "Layout maths: column widths and gaps sum exactly to the content width for every share combination of one to three slots, the last column taking the remainder; rows stack from the top margin with the row gap, a zero-height row taking no gap, and the free height goes before the last row (its bottom edge on the bottom margin) or before the footer, as the look's home.free_space says; rows whose total exceeds the available height are dropped from the end and each drop is logged; Layout.fits is true exactly when nothing would be dropped; a landscape screen (wider than tall) lays out without error; text_size small, medium and large scale font sizes by 0.85, 1 and 1.15, rounded, and leave margins and gaps unchanged"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/layout_spec.lua" }
    required: true
  - id: C4
    statement: "The home builds one slot per stored layout entry, each widget built at its column width; a slot naming an id the registry lacks, or whose widget's height or build raises, is blank and logged while the rest of the home shows; a tap inside a slot whose widget has tap runs it and nothing else, and a tap no widget acts on closes the home onto the file browser; Resume and TimeFormatChanged rebuild the rows and repaint; after a show, a resume and a weather fetch, no KoPanda task is left in UIManager's task queue"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/home_layout_spec.lua" }
    required: true
  - id: C5
    statement: "Date and clock at a fixed instant: Editorial's date is the weekday label (drawn TUESDAY) over \"October 13\", Diner's is \"Tuesday, October 13\" drawn uppercase, with no leading zero and no year; the clock reads \"8:42\" (no leading zero, no AM/PM) with twelve_hour_clock true, and with it unset or false reads \"20:42\" at 20:42, \"8:42\" at 08:42 and \"0:00\" at midnight; each draws in the look's face role, size and colour role from the type tokens; both looks declare identical home and type token paths and the new on_band, strong and quote roles, every new token keeping the look files' value rules (colours as palette roles in *_color keys, on_band exempt from the grey-distinctness check by name)"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/date_clock_spec.lua", "spec/unit/looks_spec.lua"] }
    required: true
  - id: C6
    statement: "quotes.lua is pure data with at least 60 entries, each with a non-empty text of at most 160 characters, an author, a work and a source naming a Project Gutenberg ebook number or a Wikisource page; the quote of the day is entry (local days since 1970-01-01) mod count + 1, the same all day and the next entry after local midnight; the widget draws it in curly quotes with no attribution in at most four lines, ending a longer text in an ellipsis, and the longest entry fits four lines at large in a full-width row on both profiles; quote.source builtin selects quotes.lua"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/quote_spec.lua" }
    required: true
  - id: C7
    statement: "Against fixture Statistics databases under a fixed TZ: minutes today is the floored sum of today's page_stat_data durations over 60; the streak counts consecutive local days ending today, or yesterday when nothing is read today, and is 0 after a gap; books this month counts distinct books read since the first of the local month; the database is opened read-only and a missing file is neither created nor an error and reads as the empty wording; statistics in plugins_disabled or its is_enabled false reads \"Reading stats are off\"; each look's wording and singular forms match the spec; parts drop from the end to fit the column; stats.show false draws nothing at height 0"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/reading_stats_spec.lua" }
    required: true
  - id: C8
    statement: "With socket.http and NetworkMgr stubbed: the request URL carries the stored coordinates, current=temperature_2m,weather_code,is_day, the stored units and timezone=auto; a 200 response is cached to settings/kopanda/weather.lua with fetched_at, units and coordinates; the line per look matches the spec for the condition table, an unknown code, rounding, the sun or moon icon, and the age (none under an hour, hours, days); a cache for other units or coordinates is not shown; with nothing usable cached the line is \"Weather needs Wi‑Fi\"; after a show, a connected device fetches once per process after the settled signal and a disconnected one neither fetches nor prompts; NetworkConnected fetches when connected and no fetch has succeeded, and does nothing when disconnected; a tap fetches when connected and calls runWhenOnline otherwise; a timeout, a non-200, nil headers or bad JSON leaves the cache byte-identical, and on a tap shows the failure message; socketutil's timeout is reset on every path"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/weather_spec.lua" }
    required: true
  - id: C9
    statement: "The committed home goldens match a fresh capture under the fixture userpatch, each taken on KoPandaSettled with screen \"home\": populated in Diner and Editorial on colorsoft (1264×1680, colour) and paperwhite (1236×1648, grey), and empty in Diner and Editorial on colorsoft"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_golden_spec.lua" }
    required: true
  - id: C10
    statement: "A freshly built populated home's paint_ms is at most 250 ms on each profile in the emulator on this Mac"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/home_capture_spec.lua" }
    required: true
  - id: C11
    statement: "The owner has opened all six committed home goldens and confirms they read as the canvas boards intend for each look and profile: rows, header and footer chrome, type, the weather and stats strip, the quote, and the empty wording, legible and unclipped"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C12
    statement: "The owner has run the home in the emulator with Wi-Fi available, tapped the weather and seen Chicago's current temperature in °F with its condition, and seen the reading stats reflect a book just read and closed"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C13
    statement: "In the emulator, closing a fixture book lands on the home with the file manager's paintTo never called before the home's settled signal, the pre-built home shown, and the home's share (onShow to paint) at most 100 ms, now with the real rows"
    polarity: preserve
    binding: { type: test, ref: "spec/emulator/book_close_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C14
    statement: "Gesture routing on the home keeps plugin-shell's order and outcomes: the swipe up from the bottom edge opens settings; a tap or swipe down in KOReader's top menu zones opens the file manager's menu as without the home, honouring activate_menu; a page swipe is consumed; other gestures reach the file manager's own zones, Gestures-plugin corner zones winning over the home's tap"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/gesture_routing_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C15
    statement: "Every hook still fails safe with the real home: an error thrown by the home's build, paint, gesture or event handlers is logged, leaves no home on the stack, and leaves the file manager on top and handling input"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/failsafe_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/home.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C16
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including those the new modules use; no KoPanda module path collides with one in frontend/, common/ or a bundled plugin"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C17
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) at `KOPANDA_EMULATOR`
or its default path, after `looks-and-schema` has merged. Ref-only `test` bindings resolve to
`bin/check <spec file>`, which passes spec paths straight to Busted with no luacheck; C17 is the lint
stage alone; the tests gate's own `bin/check` run covers the whole suite.

C1 replaces `schema_spec.lua`'s one-key assertion from `looks-and-schema` with the seven-key list; C5's
`looks_spec.lua` keeps its identical-paths invariant and gains the new token blocks. C3 is pure maths
with no KOReader UI; C4 runs the plugin in the headless harness (`spec/plugin_harness.lua`) with stub
widgets where the real ones would make it brittle.

C13 to C16 are preserve criteria, baselined at `plugin-shell`'s accepted state, `2c954f4`. C13 is the
pre-build paint budget, now carrying real rows and, if the `reading-stats` task finds it needed, a stats
read at show time. C14 is the gesture order; the placeholder's "tap closes" assertions become "a tap no
widget acts on closes". C15 is the fail-safe net. C16 is the `hooks_doc_spec.lua` invariant over the new
modules and their module names.

C10 is the fresh-build tripwire; the sidecar already records `paint_ms`. C11 and C12 are the human
checks: C11 the usual look at goldens before they are committed, C12 the live paths the goldens stub out
(a real Open-Meteo fetch and a real Statistics flush).
