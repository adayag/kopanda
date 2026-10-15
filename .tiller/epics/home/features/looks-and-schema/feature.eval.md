---
node: F-i2mbn1
criteria:
  - id: C1
    statement: "schema.lua loads by a plain dofile in an environment with no require and contains no functions; it returns version 1 and an ordered key list whose one entry, look, is a choice of diner and editorial with labels, default diner and group appearance; every entry has id, type, default, label and group, ids are unique, every type is one settings.lua has a validator for, and every choice default is one of its values"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/schema_spec.lua" }
    required: true
  - id: C2
    statement: "bin/schema-json prints JSON with sorted keys that decodes to a table deep-equal to dofile(schema.lua); two runs are byte-identical; without a luajit at KOPANDA_EMULATOR it exits 2"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/schema_json_spec.lua" }
    required: true
  - id: C3
    statement: "Settings.get returns the schema default with a missing file, a corrupt file and a stored value the key's type doesn't allow, and the stored value when it is valid; Settings.set refuses an undefined key and a disallowed value with false and a reason, leaving the file byte-identical; an accepted set creates settings/kopanda/ if needed, is flushed at once and survives a reopen"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/settings_spec.lua" }
    required: true
  - id: C4
    statement: "A settings file with no schema_version is read as version 1; a file older than the schema runs each migration step in order and is stamped with the schema's version; a file newer than the schema is read with per-key fallback and every write to it is refused, leaving it byte-identical"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/settings_spec.lua" }
    required: true
  - id: C5
    statement: "Diner and Editorial declare identical token paths, and within each look the day, night and grey palettes declare identical roles; every palette value (the colour tokens; other style tokens name palette roles) is false or matches ^#%x%x%x%x%x%x$ and gives a non-nil Blitbuffer.colorFromString; every grey-palette colour has equal red, green and blue; the active look is diner with no settings file and editorial after Settings.set(\"look\", \"editorial\"); the variant is grey when Screen:isColorEnabled() is false and day otherwise"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/looks_spec.lua" }
    required: true
  - id: C6
    statement: "Every face file a look names exists under kopanda.koplugin/fonts/ beside its family's OFL.txt, has no fvar table, and loads through Font:getFace both by absolute path and by a ./-relative path from the KOReader directory; a missing file returns nil from fonts.lua without an error"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/fonts_spec.lua" }
    required: true
  - id: C7
    statement: "Every SVG under kopanda.koplugin/icons/ has exactly one registry entry and every entry names an existing file; every entry has a unique id, a label, a non-empty used_in and a file; no icon file contains currentColor; every file renders through RenderImage:renderSVGImageFile to a non-nil buffer with at least one pixel of non-zero alpha, and every such pixel is black (R = G = B = 0); no Lua file under kopanda.koplugin/ other than icons.lua contains an .svg file name"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/icons_spec.lua" }
    required: true
  - id: C8
    statement: "Tools › KoPanda › Swatches in the file manager and in the reader shows a covers_fullscreen swatch screen that a tap closes; it builds six panels (Editorial and Diner by day, night and grey), each with a chip per colour role labelled with role and hex and a line per face, and an icon row with every registered icon id; with night mode on it shows the inversion note; an error in its build, paint or gesture handling is logged and closes it, leaving the file manager on top and handling input when opened there, and the reader on top and handling input when opened there"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/swatch_spec.lua" }
    required: true
  - id: C9
    statement: "With simpleui, bookshelf or ennUI enabled, Tools › KoPanda exists in the file manager and the reader with Swatches as its only item, and Swatches opens the swatch screen"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/guards_spec.lua" }
    required: true
  - id: C10
    statement: "With simpleui, bookshelf or ennUI enabled, no home appears and one InfoMessage per start names each conflicting plugin; with simpleui enabled, no pre-build, Home tab or kopanda_home action appears, and Tools › KoPanda holds no item but Swatches in the file manager and the reader"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/guards_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/main.lua"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C11
    statement: "The committed swatch goldens match a fresh capture of the swatch screen on both profiles (colorsoft 1264×1680 in colour, paperwhite 1236×1648 in grey), each taken on its KoPandaSettled signal with screen \"swatch\""
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/swatch_golden_spec.lua" }
    required: true
  - id: C12
    statement: "The owner has opened both committed swatch goldens and confirms they show the six panels, the face lines and the icon row, legible and unclipped, at the right size for each profile"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C13
    statement: "The owner has read the swatch screen on the Kindle Colorsoft and confirms the token values are final; the look files and the direction doc's token tables agree on every value"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C14
    statement: "kopanda.koplugin/HOOKS.md names every KOReader module the plugin requires, every G_reader_settings key it reads or writes, and every KOReader internal it reads or patches, each entry with a file:line, including those the new modules use"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/hooks_doc_spec.lua" }
    baseline:
      surface: "kopanda.koplugin/HOOKS.md"
      captured_at: { kind: git_tree, value: "git:2c954f4", path: kopanda.koplugin, observed_at: "2026-10-14T00:00:00Z" }
    required: true
  - id: C15
    statement: "AGENTS.md Commands documents bin/schema-json"
    polarity: introduce
    binding: { type: command, run: "grep -q 'bin/schema-json' AGENTS.md" }
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
tests gate's own `bin/check` run covers the whole suite. C3 and C4 share `settings_spec.lua`, and C9 and
C10 share `guards_spec.lua`; each criterion names the behaviour its describe blocks prove.

C10 and C14 are preserve criteria. C10: the swatch's coexistence exception must not let anything else
of the shell through. Its baseline is `plugin-shell`'s accepted refusal behaviour at `2c954f4`, which
`guards_spec.lua` proves for the home and the message with all three shells and for the pre-build, tab,
Tools entry and action with simpleui (the guard is plugin-agnostic through `Guards.refused`). The swatch
task replaces that spec's "no Tools entry" assertion with a stronger one: Tools › KoPanda's items are
exactly Swatches, checked in the file manager and the reader, and adds C9 beside it. C14: the existing
`hooks_doc_spec.lua` invariant, re-proven over the new modules.

C12 and C13 are the human checks. C12 is the usual look at the goldens before they are committed. C13 is
the point of the swatch screen: the values are settled on the Colorsoft's panel, by the owner, and the
direction doc is updated from it.
