---
node: F-9okxa7
criteria:
  - id: C1
    statement: "The studio builds a profile's bundle from the working tree's kopanda.koplugin/ and the profile's settings file: every regular file under the plugin as plugin/<rel>, dot-entries skipped, a symlink or a segment outside ^[A-Za-z0-9._-]+$ failing the build naming it; settings.lua with a first line matching ^-- /.+/settings/kopanda/settings\\.lua$ (any absolute path ending in the settings file's name, not only its own) rewritten to -- settings/kopanda/settings.lua and any other first line kept, and a missing file served as -- settings/kopanda/settings.lua, return {}; the manifest { format: 1, profile, hash, files[{ path, size, sha256 }] } lists every file in UTF-8 byte order with the hashTree hash; built from spec/fixtures/push/tree/ for profile vector it equals spec/fixtures/push/manifest.json byte for byte"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/server/bundle.test.ts"
      run: "npm --prefix studio test -- test/server/bundle.test.ts"
    required: true
  - id: C2
    statement: "GET /api/push/profiles lists the valid profiles as { id, name, device } in id order with no dir or settings_path; GET /api/push/:id/manifest answers the manifest, 404 for an unknown or invalid profile and 500 naming the entry for a bundle that fails to build; GET /api/push/:id/files/:hash/<path> answers the file's bytes as application/octet-stream with no-store, 409 { error, hash } with the current hash when :hash is stale, 404 for a path not in the bundle or an unknown profile; a settings change between the manifest and a file request turns that request into a 409"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/server/push.test.ts"
      run: "npm --prefix studio test -- test/server/push.test.ts"
    required: true
  - id: C3
    statement: "KOPANDA_STUDIO_HOST defaults to 127.0.0.1, empty takes the default, and is listed in .env.example; GET /api/health answers { ok, host, port, addresses } with no addresses on a loopback host; from a non-loopback peer only GET /api/health, /api/push/profiles, /api/push/<id>/manifest and /api/push/<id>/files/<64 hex>/<path> pass, while /api/profiles, /api/profiles/<id>, the settings and preview routes, any non-GET and the UI's files answer 403 { error }; from a loopback peer every route passes"
    polarity: introduce
    binding:
      type: test
      ref: ["studio/test/server/lan-guard.test.ts", "studio/test/server/config.test.ts"]
      run: "npm --prefix studio test -- test/server/lan-guard.test.ts test/server/config.test.ts"
    required: true
  - id: C4
    statement: "The profile screen shows Pull from the Kindle at <address>:<port> for each LAN address when the LAN is on and the LAN off line when it is not, and Bundle <first 12 hex> from the manifest route with Refresh fetching it again and a failed fetch showing its error"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/push-status.test.tsx"
      run: "npm --prefix studio test -- test/ui/push-status.test.tsx"
    required: true
  - id: C5
    statement: "The device side agrees with the shared vectors: over spec/fixtures/push/tree/ it computes every sha256 and the bundle hash in spec/fixtures/push/manifest.json, and accepts that manifest for profile vector"
    polarity: introduce
    binding:
      type: test
      ref: "spec/unit/push_bundle_spec.lua"
      run: "bin/check spec/unit/push_bundle_spec.lua"
    required: true
  - id: C6
    statement: "A pull is refused, with nothing staged, download/ purged and an earlier stage left byte-identical, for: a manifest that is not JSON, not an object, of another format or profile, with a hash or sha256 that is not 64 hex, a size that is not a non-negative integer, an unsafe path (empty, absolute, backslash, empty, . or .. segment, a character outside ^[A-Za-z0-9._-]+$), a path neither settings.lua nor under plugin/, two paths equal ignoring case, settings.lua, plugin/main.lua or plugin/_meta.lua missing, or paths out of byte order; a file answered 409 (pull again) or any other failure; a file of the wrong size or sha256; and a bundle hash that does not recompute"
    polarity: introduce
    binding:
      type: test
      ref: "spec/unit/push_pull_spec.lua"
      run: "bin/check spec/unit/push_pull_spec.lua"
    required: true
  - id: C7
    statement: "A verified pull replaces any earlier stage with staged/ and a staged.lua holding format, profile, hash, the running plugin's folder made absolute with doubled slashes collapsed, the exact runtime names of the enabled SimpleUI, Bookshelf and ennUI plugins and the time, then copies push_apply.lua to patches/1-kopanda-apply.lua byte for byte; it is refused before any request with no address or profile, with patches/.patches_disabled present, with probation.lua present, or from a plugin folder not named kopanda.koplugin; a failed arm leaves no staged.lua; Tools › KoPanda › Studio is in the normal and the refused menu, its address and profile are stored in state.lua as studio_address and studio_profile, and a staged pull offers Restart, which broadcasts the Restart event"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/push_pull_spec.lua", "spec/unit/studio_menu_spec.lua"]
      run: "bin/check spec/unit/push_pull_spec.lua spec/unit/studio_menu_spec.lua"
    required: true
  - id: C8
    statement: "On scratch folders the apply patch, with a stage: moves the plugin folder to rollback/plugin and the staged plugin into its place, moves the settings file to rollback/settings.lua and the staged one into its place, adds each disable name to plugins_disabled keeping every other entry, sets boot_pending false, writes probation.lua and a result applied, keeps rollback/record.lua with the previous plugins_disabled (absent told from empty), and leaves no stage; with nothing staged and no probation it changes nothing; a bad stage record or incomplete stage ends failed with nothing moved; a failure at each of the move, settings and plugins_disabled steps restores everything and ends failed with no probation; a failure writing the result, removing staged.lua or purging staged/ is only logged and leaves the install applied on probation, and a leftover staged.lua with no staged/plugin ends the next run failed with nothing moved; the file required as a module runs nothing and dofile'd runs, catching its own errors into result.lua"
    polarity: introduce
    binding:
      type: test
      ref: "spec/unit/push_apply_spec.lua"
      run: "bin/check spec/unit/push_apply_spec.lua"
    required: true
  - id: C9
    statement: "With probation.lua present the next run restores plugins_disabled (or its absence) first, then the previous plugin folder and settings file (or its absence, with any settings.lua.old the new install made removed), clears boot_pending, purges any stage and the rollback set and ends rolled_back; a restore started after the run was cut short at each apply step leaves the device as before the apply; a restore step that fails ends restore_failed after the other steps are tried, with plugins_disabled equal to the record's, and keeps probation so the next run tries again; a failed purge of discard/ after the swap is only logged; no rename made by the patch's own move targets an existing path"
    polarity: introduce
    binding:
      type: test
      ref: "spec/unit/push_apply_spec.lua"
      run: "bin/check spec/unit/push_apply_spec.lua"
    required: true
  - id: C10
    statement: "Home.show calls finished(true) only after a first paint that succeeded, and finished(false) after a failed paint and after a caught build or show failure; on a painted first home the plugin removes probation.lua and then shows result.lua's notice over the home and removes it; a failed paint, build or show leaves probation.lua and result.lua; refused, with no probation it shows the result's notice and removes it, and with probation it leaves both; each of applied, rolled_back, failed and restore_failed shows its wording; the boot guard behaves as before"
    polarity: introduce
    binding:
      type: test
      ref: ["spec/unit/push_notice_spec.lua", "spec/unit/failsafe_spec.lua"]
      run: "bin/check spec/unit/push_notice_spec.lua spec/unit/failsafe_spec.lua"
    required: true
  - id: C11
    statement: "In the emulator on one scratch KO_HOME with a fixture shell named ennui enabled: a first start pulls a bundle from the background file server through the plugin's pull code while KoPanda is refused, stages, arms and exits 85; the second start applies, lands on KoPanda's home (captured), with plugins_disabled.ennui true and ennui absent from the loaded plugins, the served plugin and settings in place, the previous ones in the rollback set, no probation, and the applied notice shown"
    polarity: introduce
    binding:
      type: test
      ref: "spec/emulator/push_spec.lua"
      run: "bin/check spec/emulator/push_spec.lua"
    required: true
  - id: C12
    statement: "In the emulator on one scratch KO_HOME: a pulled bundle whose plugin main.lua raises leaves the second start without KoPanda's home and probation set; the third start restores the previous plugin folder and settings, lands on KoPanda's home (captured) and shows the rolled-back notice, with no probation and no rollback set left"
    polarity: introduce
    binding:
      type: test
      ref: "spec/emulator/push_spec.lua"
      run: "bin/check spec/emulator/push_spec.lua"
    required: true
  - id: C13
    statement: "The studio's typecheck, lint and tests pass"
    polarity: introduce
    binding: { type: command, run: "npm --prefix studio run check" }
    required: true
  - id: C14
    statement: "bin/check passes: luacheck, the studio stage, every unit spec and every emulator spec, HOOKS.md naming every module and key the new plugin files use"
    polarity: introduce
    binding: { type: command, run: "bin/check" }
    required: true
  - id: C15
    statement: "The owner installs KoPanda by hand on the Kindle (SimpleUI and Bookshelf still enabled), reads /mnt/us/koreader/git-rev, starts the studio with KOPANDA_STUDIO_HOST=0.0.0.0, enters the address and chooses the Colorsoft profile from Tools › KoPanda › Studio, pulls, restarts, and sees KoPanda's home with the applied notice, SimpleUI and Bookshelf off in Plugin management, and the profile's settings in effect; then, with the working tree's kopanda.koplugin/main.lua made to raise, pulls again, restarts twice, and sees the previous KoPanda back with the rolled-back notice"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C16
    statement: "The capture driver's single-start captures and the boot guard survive the driver's multi-start mode and the finished(painted) change: every emulator spec present at the baseline, the driver's unit spec, the boot-guard specs and the coexistence specs pass, every golden matching as before"
    polarity: preserve
    binding:
      type: test
      ref:
        - "spec/emulator/book_close_spec.lua"
        - "spec/emulator/capture_spec.lua"
        - "spec/emulator/gesture_forward_spec.lua"
        - "spec/emulator/golden_spec.lua"
        - "spec/emulator/home_capture_spec.lua"
        - "spec/emulator/home_golden_spec.lua"
        - "spec/emulator/night_golden_spec.lua"
        - "spec/emulator/night_toggle_spec.lua"
        - "spec/emulator/sheet_golden_spec.lua"
        - "spec/emulator/swatch_golden_spec.lua"
        - "spec/unit/driver_spec.lua"
        - "spec/unit/failsafe_spec.lua"
        - "spec/unit/guards_spec.lua"
      run: >-
        bin/check spec/emulator/book_close_spec.lua spec/emulator/capture_spec.lua
        spec/emulator/gesture_forward_spec.lua spec/emulator/golden_spec.lua
        spec/emulator/home_capture_spec.lua spec/emulator/home_golden_spec.lua
        spec/emulator/night_golden_spec.lua spec/emulator/night_toggle_spec.lua
        spec/emulator/sheet_golden_spec.lua spec/emulator/swatch_golden_spec.lua
        spec/unit/driver_spec.lua spec/unit/failsafe_spec.lua spec/unit/guards_spec.lua
    baseline:
      surface: "spec"
      captured_at: { kind: git_tree, value: "git:f3f3bb6", path: spec, observed_at: "2026-10-16T00:00:00Z" }
    required: true
---

# Acceptance

The push is accepted when the studio builds and serves a profile's bundle with a verifiable manifest
(C1, C2), opens to the LAN only on request and then only for the push routes (C3), and shows the
address and bundle on the profile screen (C4); the device agrees with the studio's format through the
shared vectors (C5), refuses every bad bundle leaving no stage (C6), and stages, arms and offers the
restart from both menus (C7); the next start applies, undoes a failed apply (C8), and rolls back an
install whose home never painted (C9), with probation cleared only by a painted home and every outcome
reported (C10); the emulator proves the switch-over (C11) and the rollback (C12) end to end; the
studio's and the repo's checks pass (C13, C14); the dev loop's captures and the boot guard survive
(C16); and the owner has pulled to the Kindle and seen both outcomes (C15).
