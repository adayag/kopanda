---
node: F-kglqs4
criteria:
  - id: C1
    statement: "studio/src/schema.json is byte-identical to a fresh bin/schema-json run; when it differs (a key added to schema.lua without regenerating) the spec fails and its message names npm run schema"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/studio_schema_spec.lua" }
    required: true
  - id: C2
    statement: "The studio's seed profiles are exactly colorsoft and paperwhite, and each one's width, height, dpi and color equal spec/emulator/profiles.lua's entry of the same id"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/studio_profiles_spec.lua" }
    required: true
  - id: C3
    statement: "loadConfig reads KOPANDA_STUDIO_PORT and KOPANDA_STUDIO_PROFILES_DIR with defaults 4490 and ~/.kopanda/profiles, an empty value taking the default and ~ or a leading ~/ expanding to the home directory; a port that is not an integer in 1-65535 throws naming the variable and the value; every variable loadConfig reads appears in the repo's .env.example; the server entry prints one line and exits 1 on a bad port and on a port in use"
    polarity: introduce
    binding:
      type: test
      ref: ["studio/test/server/config.test.ts", "studio/test/server/index.test.ts"]
      run: "npm --prefix studio test -- test/server/config.test.ts test/server/index.test.ts"
    required: true
  - id: C4
    statement: "A missing profiles directory is created holding colorsoft and paperwhite profile.json files from the seed and no settings files; an existing directory, empty or not, is left unchanged; GET /api/profiles answers the directory's absolute path and lists profiles in id order with id, name, device, width, height, dpi, color and has_settings, reflects a profile added or edited on disk without a restart, skips a directory with no profile.json, and lists a profile.json that is unparseable or fails validation as id plus error; GET /api/profiles/:id returns a valid profile with its absolute settings_path and 404 with an error for an unknown or invalid id; an unknown /api path is 404 with an error"
    polarity: introduce
    binding:
      type: test
      ref: ["studio/test/server/profiles.test.ts", "studio/test/server/app.test.ts"]
      run: "npm --prefix studio test -- test/server/profiles.test.ts test/server/app.test.ts"
    required: true
  - id: C5
    statement: "The first screen shows a loading line, then one row per profile with name, device, resolution, DPI, colour or greyscale and whether settings exist, an invalid profile as its id and reason that does not open, an empty directory as No profiles in <dir>, and a failed request as its error; choosing a profile sets #/profiles/<id> and shows its name, device facts, settings path and All settings at their defaults when it has no settings file, with a way back to the list; loading at #/profiles/<id> opens that profile directly and an unknown id shows No profile <id> with the way back"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/profiles.test.tsx"
      run: "npm --prefix studio test -- test/ui/profiles.test.tsx"
    required: true
  - id: C6
    statement: "The studio's schema type accepts the checked-in studio/src/schema.json, and a key with a type the studio does not declare fails the check"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/schema.test.ts"
      run: "npm --prefix studio test -- test/schema.test.ts"
    required: true
  - id: C7
    statement: "bin/check with no arguments runs a == studio stage after lint and before == unit; a failing studio check makes it exit 1 without starting the unit specs; with no node on PATH or no studio/node_modules it refuses with exit 2 naming npm ci --prefix studio (and brew install node when node is missing); luacheck skips studio/node_modules and studio/dist"
    polarity: introduce
    binding: { type: test, ref: "spec/unit/check_spec.lua" }
    required: true
  - id: C8
    statement: "The studio's typecheck, lint and tests pass"
    polarity: introduce
    binding: { type: command, run: "npm --prefix studio run check" }
    required: true
  - id: C9
    statement: "The owner runs npm run dev and opens the Vite URL, then npm run build and npm start and opens http://127.0.0.1:4490; in both the profile list shows Colorsoft and Paperwhite, opening Colorsoft shows its profile screen and a reload keeps it open; with KOPANDA_STUDIO_PROFILES_DIR pointing at a missing directory, npm start creates and lists both seed profiles"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C10
    statement: "bin/check's existing behaviour survives: a failing spec exits 1 naming it, named-spec mode runs no luacheck and removes its KO_HOME, a missing emulator, luacheck or spec file refuses with exit 2, a lint failure exits 1, and a repo path with a space works, and named-spec mode needs neither node on PATH nor studio/"
    polarity: preserve
    binding: { type: test, ref: "spec/unit/check_spec.lua" }
    baseline:
      surface: "bin/check"
      captured_at: { kind: git_tree, value: "git:c414aae", path: bin/check, observed_at: "2026-10-15T00:00:00Z" }
    required: true
---

# Acceptance

The studio shell is accepted when the contract with the plugin holds (C1, C2, C6), the server and its
config behave as specified (C3, C4), the first screen lists and opens profiles (C5), the studio is part
of the project's one gate without disturbing it (C7, C8, C10), and the owner has seen both serving modes
work in a browser (C9).
