---
node: F-xo6obj
criteria:
  - id: C1
    statement: "`bin/check` exits non-zero when a spec fails or luacheck warns, and zero when both are clean; with spec paths as arguments it runs only those specs"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/check_spec.lua" }
    required: true
  - id: C2
    statement: "A spec runs on the emulator's LuaJIT with KOReader's frontend and the plugin folder on the path, under a temporary KO_HOME that is not the emulator's folder and is gone after the run"
    polarity: introduce
    binding: { type: test, ref: ["spec/unit/environment_spec.lua", "spec/unit/check_spec.lua"] }
    required: true
  - id: C3
    statement: "A headless capture of the probe plugin produces a PNG at each profile's resolution (1264×1680 colorsoft, 1236×1648 paperwhite), taken on the plugin's settled signal, with the paint time in the sidecar"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/capture_spec.lua" }
    required: true
  - id: C4
    statement: "The golden comparison passes identical images, ignores pixels inside a mask rectangle, fails when more than 0.05 % of compared pixels differ, fails on a size mismatch naming both sizes, and writes a diff PNG on failure"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/compare_spec.lua" }
    required: true
  - id: C5
    statement: "The committed probe goldens match a fresh capture on both profiles; a missing golden fails naming the regeneration flag; with KOPANDA_UPDATE_GOLDENS=1 the capture is written as the golden with its sidecar"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/golden_spec.lua" }
    required: true
  - id: C6
    statement: "The driver refuses before starting the emulator, naming the path, when the emulator's plugins/ holds kopanda.koplugin, when the emulator dir has no luajit, or when the plugin folder to copy is missing; and the scratch profile it writes disables simpleui, bookshelf, ennUI and solariconpack"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/driver_spec.lua" }
    required: true
  - id: C7
    statement: "No capture loads SimpleUI, Bookshelf, ennUI or the Solar icon pack from the emulator's plugins/: the sidecar's list of loaded plugins names none of them"
    polarity: introduce
    binding: { type: test, ref: "spec/emulator/capture_spec.lua" }
    required: true
  - id: C8
    statement: "Every EPUB in spec/fixtures/library/ is listed in the manifest with a matching SHA-256, and every manifest entry has its file"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/fixtures_spec.lua" }
    required: true
  - id: C9
    statement: "Tiller's build gate runs `bin/check --lint` and its tests gate runs `bin/check`, on feature and task"
    polarity: introduce
    binding: { type: command, run: "grep -Eq '^\\s*build:.*run: \"bin/check --lint\".*on: \\[feature, task\\]' .tiller/tiller.yml && grep -Eq '^\\s*tests:.*run: \"bin/check\".*on: \\[feature, task\\]' .tiller/tiller.yml" }
    required: true
  - id: C10
    statement: "luacheck is clean over every Lua file in the repo outside spec/fixtures/"
    polarity: introduce
    binding: { type: command, run: "bin/check --lint" }
    required: true
  - id: C11
    statement: "The owner has opened both committed probe goldens and confirms they show the probe's frame, label and corner marks at the right size for each profile"
    polarity: introduce
    binding: { type: manual }
    required: true
---

# Acceptance

Every criterion is green on this Mac with the pinned emulator build (`e1fe1ac`) present at
`KOPANDA_EMULATOR` or its default path. Ref-only `test` bindings resolve to `bin/check <spec file>`,
which runs that spec alone; C10 is the lint stage alone; the tests gate's own `bin/check` run covers the
whole suite. C11 is the one human check: goldens are looked at, not only diffed, before they are
committed.
