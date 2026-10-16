---
node: F-k4yn5f
criteria:
  - id: C1
    statement: "spec/fixtures/studio/settings_written.lua is byte for byte what the studio's writer produces for its data set and byte for byte what LuaSettings:flush writes for the same data (header line aside, compared as the fixture's); with that file as the plugin's settings file, Settings.get returns every schema key's value as written, each one other than quote.source differing from its default"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_settings_file_spec.lua", "studio/test/core/settings-written.test.ts"]
      run: "bin/check spec/unit/studio_settings_file_spec.lua && npm --prefix studio test -- test/core/settings-written.test.ts"
    required: true
  - id: C2
    statement: "For every case in spec/fixtures/studio/validator_cases.lua, the plugin's Settings.validators and the studio's validators each give the case's expected verdict; the corpus covers every schema key's type with accepted and refused values, including a sparse list, a keyed table where a list is due, a non-integer and an out-of-range share, a repeated widget, a nested folder, an unknown entry kind, a screen target outside the schema's, a relative and a root path, and a location with an extra field"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_validators_spec.lua", "studio/test/core/validators.test.ts"]
      run: "bin/check spec/unit/studio_validators_spec.lua && npm --prefix studio test -- test/core/validators.test.ts"
    required: true
  - id: C3
    statement: "The studio's reader reads what dump writes (nested tables, number and string keys, %q escapes including \\ddd, a backslash-newline, \\0 and bytes over 127, %.14g numbers) and hand-written Name = and positional fields and -- comments, keeping lists, keyed tables and sparse tables apart; it reports anything outside the literal subset (an expression, a call, nil, inf, a long string, a second value) as unreadable with its line and column; the writer orders keys as orderedPairs does and formats numbers as %.14g and strings as %q; the schema version is 1, the test failing with a message to port migrations.lua's steps before raising it"
    polarity: introduce
    binding:
      type: test
      ref: ["studio/test/core/lua.test.ts", "studio/test/core/validators.test.ts"]
      run: "npm --prefix studio test -- test/core/lua.test.ts test/core/validators.test.ts"
    required: true
  - id: C4
    statement: "GET /api/profiles/:id/settings answers every schema key's value: defaults for a missing file, the stored value when its validator accepts it, the default with the key listed in invalid when it refuses it, keys outside the schema in unknown with their written text; a schema_version that is a number above 1 is read_only, any other schema_version but an absent, false or 1 one, and a file outside the literal subset, are unreadable with a reason; PUT /api/profiles/:id/settings/:key writes that key and schema_version 1, keeps every other stored key byte-equivalent, leaves no temporary file, creates settings/kopanda/ when missing, answers the re-read state, and refuses an unknown key with 404, a refused value with 400 naming the key and a read-only or unreadable file with 409, each leaving the file byte-identical; two concurrent PUTs to one profile both land"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/server/settings.test.ts"
      run: "npm --prefix studio test -- test/server/settings.test.ts"
    required: true
  - id: C5
    statement: "The profile screen's form renders exactly one control for every key of the real schema, in schema order under its group's heading, look first; a schema handed to the form with an undeclared type shows No control for that type and renders the rest; a choice, the boolean and the path each send one PUT of their key on a change and none for the value shown, the path refusing a relative path and / with its note and unpinning to false; a failed PUT shows Couldn't save with the error and keeps the file's state; unknown keys are listed as kept, a refused stored value is noted beside its control, and a read-only or unreadable file disables every control with its line; the layout and launcher rows open #/profiles/<id>/layout and #/profiles/<id>/launcher, which a reload keeps open and whose Done returns to the form"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/settings-form.test.tsx"
      run: "npm --prefix studio test -- test/ui/settings-form.test.tsx"
    required: true
  - id: C6
    statement: "For every case in spec/fixtures/studio/geocoding_cases.lua the plugin's LocationSearch.url and LocationSearch.parse and the studio server's functions give the case's URL and candidates (trimmed and util.urlEncode-encoded queries, countryCode=US for exactly five digits only, names with admin1 or country, results without a name or numeric coordinates skipped, no results as none); GET /api/geocode answers candidates from a stubbed Open-Meteo, 400 for an empty query and 502 for a failed, non-2xx, unreadable or timed-out request; the location control searches, lists Choose a place, writes exactly name, latitude and longitude on a pick, and shows its notes for no place and for a failure, writing nothing"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_geocoding_spec.lua", "studio/test/server/geocoding.test.ts", "studio/test/ui/location.test.tsx"]
      run: "bin/check spec/unit/studio_geocoding_spec.lua && npm --prefix studio test -- test/server/geocoding.test.ts test/ui/location.test.tsx"
    required: true
  - id: C7
    statement: "bin/layout-fit at the dummy screen's 600x800 prints the same overflow counts as Layout.overflow computes in process for the default rows and for a layout of every widget on its own row; at 1264x1680 @ 300 it reports that screen and 0 for the default rows; a given settings file's look and text_size are the ones measured with (a change of text_size or look in the file changes a count the test picks to differ); it exits 1 naming the index for a row list the rows validator refuses and for input that is not JSON, exits 2 naming the path with no luajit at KOPANDA_EMULATOR, and leaves no scratch KO_HOME behind"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/layout_fit_spec.lua" }
    required: true
  - id: C8
    statement: "POST /api/profiles/:id/layout-fit runs the fit command once with the profile's width, height, dpi and settings file for the current effective layout.rows and the proposed rows and answers checked with both counts; a command exiting 2, exiting 1, printing unreadable output or exceeding its timeout answers checked false with a reason; the resolved bin/layout-fit path exists from the server module in source and in the build layout"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/server/layout-fit.test.ts"
      run: "npm --prefix studio test -- test/server/layout-fit.test.ts"
    required: true
  - id: C9
    statement: "For every case in spec/fixtures/studio/rows_edit_cases.lua the plugin's RowsEdit and the studio's row operations give the case's result or refusal note (move, add_row, add_column refused at three, change_widget, set_share, remove_column, remove_row refused for the only row, reset, unused, label, share_text, caption), and no studio operation changes its input"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_rows_edit_spec.lua", "studio/test/core/rows-edit.test.ts"]
      run: "bin/check spec/unit/studio_rows_edit_spec.lua && npm --prefix studio test -- test/core/rows-edit.test.ts"
    required: true
  - id: C10
    statement: "The layout editor shows a card per row with its caption, its columns' labels and shares and its arrows, the first row's up and the last row's down disabled; selecting a row shows Add column, Change widget, Width and Remove column on rows of two or more, and Remove row; every change (arrows, each button, Add row, Reset) asks the fit endpoint first and shows Checking fit while it waits, then writes layout.rows with one PUT when the proposed count is not above the current one, and shows That won't fit on the home with no PUT when it is; an unchecked answer writes and shows Fit not checked with its reason until a later check succeeds; pickers list only unused widgets; a refused operation shows its note with no fit request and no PUT"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/layout-editor.test.tsx"
      run: "npm --prefix studio test -- test/ui/layout-editor.test.tsx"
    required: true
  - id: C11
    statement: "studio/src/catalog.json is byte-identical to a fresh bin/catalog-json run and a mismatch fails naming npm run catalog; it holds the General, Device, Screen and lights and File browser sections with only none and arg actions, no reader, rolling or paging section, the bundled plugins the file manager loads with no is_doc_only one, none outside BUILTIN_PLUGINS and no kopanda, every icon registry entry with its label and its file's SVG text including action, and the KoPanda and KOReader screens' labels and icons; bin/catalog-json refuses with exit 2 with no luajit at KOPANDA_EMULATOR; the studio's catalog type accepts the checked-in file"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_catalog_spec.lua", "studio/test/catalog.test.ts"]
      run: "bin/check spec/unit/studio_catalog_spec.lua && npm --prefix studio test -- test/catalog.test.ts"
    required: true
  - id: C12
    statement: "For every case in spec/fixtures/studio/entries_edit_cases.lua the plugin's EntriesEdit and the studio's entry operations give the case's result (move and remove within a list, a folder's only entry removed taking the folder, add into a folder, at the end of a top level under six, into the first folder of a full top level, and the sixth and new entry becoming a folder More in slot six, count and kind_line); the studio's set_label and set_icon change only that field of an entry of a kind that has it, every result passing the studio's launcher validator, and no operation changes its input"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/studio_entries_edit_spec.lua", "studio/test/core/entries-edit.test.ts"]
      run: "bin/check spec/unit/studio_entries_edit_spec.lua && npm --prefix studio test -- test/core/entries-edit.test.ts"
    required: true
  - id: C13
    statement: "The launcher editor shows N of 6 on the home screen and a row per entry with its catalog icon on a light tile, its label and kind line, arrows disabled at the ends and remove; arrows, remove, a label edit and an icon pick each write launcher.entries with one PUT; removing a folder asks first and its cancel sends nothing; a folder's row opens Folder · N over its label, whose adds go into it and whose Done returns; each of the five kinds adds its entry (screens from the schema's targets, a directory from a typed path with / and a relative path refused by their notes and its last part as the default label, an action from the catalog's four sections with its title as the default label and action as the default icon, a plugin from the catalog's plugins then an action), the seventh going into a folder by D3; an empty label is refused; cancel adds nothing; an entry whose action or plugin the catalog lacks is listed by its ids"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/launcher-editor.test.tsx"
      run: "npm --prefix studio test -- test/ui/launcher-editor.test.tsx"
    required: true
  - id: C14
    statement: "The studio's typecheck, lint and tests pass, studio-shell's tests included"
    polarity: introduce
    binding: { type: command, run: "npm --prefix studio run check" }
    required: true
  - id: C15
    statement: "With npm run dev the owner opens the Colorsoft profile and changes the look, text size, units and stats, pins a device path and unpins it, searches a city and a ZIP and picks a place, edits the layout (a move, an added column, a width, a row the fit refuses, a reset) and sees Fit not checked once with KOPANDA_EMULATOR pointing nowhere, adds an entry of each kind and a seventh into a folder, edits a label and an action entry's icon, and removes the folder; then starts the emulator on a scratch KO_HOME holding the plugin under plugins/ and a copy of the profile's settings file at settings/kopanda/settings.lua, and sees the home show the look, text size, rows, launcher entries and weather place chosen in the studio"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

The form is accepted when the studio reads and writes the plugin's file as the plugin does (C1, C3, C4),
judges values as the plugin does (C2), shows every key once with its reports (C5), searches places by the
device's rules (C6), fits the layout by the plugin's own rule with a working fallback (C7, C8, C10), edits
rows and entries exactly as the device does (C9, C12, C10, C13) from a catalog that cannot go stale
unnoticed (C11), passes the studio's own check (C14), and the owner has seen a studio edit land on the
emulator's home (C15).

Every criterion is satisfiable by this feature once its two prerequisites have merged: the Lua sides of
C1, C2, C6, C9, C11 and C12 run against modules this repo holds then (`settings.lua` today; `RowsEdit`,
`EntriesEdit`, `LocationSearch`, `Layout.overflow` and the `action` icon from `home/device-menus`), and the
studio sides need nothing but the studio package from `studio/studio-shell`. No criterion needs the
preview.

No `preserve` criterion: nothing on `main` changes behaviour. The feature adds `bin/layout-fit`,
`bin/catalog-json`, the studio's files and the `spec/fixtures/studio/` corpora; it changes studio-shell's
`App.tsx`, `api.ts` and `ProfileScreen.tsx`, which do not exist on `main` today and whose own tests run
under C14.
