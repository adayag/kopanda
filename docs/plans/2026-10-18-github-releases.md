# GitHub releases and device updates: implementation plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** every plugin-changing push to main publishes a GitHub release holding a plugin-only bundle, and the Kindle installs it from a "Check for update" item through the existing staged apply.

**Architecture:** two independent halves joined by one contract, the release bundle below. The studio half (`studio/`, `bin/bundle`, `.github/workflows/release.yml`) builds and publishes. The device half (`kopanda.koplugin/`) adds a release source beside the studio source and feeds the existing verify → stage → arm → apply path. Design: `docs/plans/2026-10-18-github-releases-design.md`.

**Tech Stack:** Lua on KOReader's LuaJIT with LuaSocket + LuaSec (`socket.http` handles `https://` URLs and follows redirects; proven against api.github.com and a GitHub asset redirect from the emulator's luajit on 2026-10-18), `ffi/archiver` (libarchive) for the zip; TypeScript/Node 22 with `tsx` for the bundle script, the `zip` CLI, `gh` in Actions; Busted and Vitest.

---

## The contract: a release bundle

Two assets on a GitHub release tagged `vX.Y.Z`:

1. `manifest.json`:
   ```json
   {"format":1,"profile":"release","hash":"<64 hex>","settings":false,
    "files":[{"path":"plugin/_meta.lua","size":123,"sha256":"<64 hex>"}, ...]}
   ```
   Every path starts with `plugin/`, in byte order, no `settings.lua`. `hash` is the studio's `hashTree` over exactly these files (`studio/src/server/bundle.ts:62-76`). The bundled `plugin/_meta.lua` has `version = "X.Y.Z"` (the tag without `v`); its bytes and sha256 are those of the rewritten file, not the repo's.
2. `kopanda.koplugin.zip`: one top-level folder `kopanda.koplugin/` holding the same files with the same bytes (`kopanda.koplugin/_meta.lua` etc.), nothing else, no `__MACOSX`, no directory entries required.

The LAN route's manifest is unchanged (no `settings` key, `settings.lua` present). On the device, `settings == false` means plugin-only: `settings.lua` not required, not downloaded, not touched by the apply or a rollback.

The repo's `kopanda.koplugin/_meta.lua` carries `version = "0.0.0-dev"`; the device treats a version that doesn't parse as `%d+.%d+.%d+` as older than any release.

Device version compare: numeric per component (`0.1.10 > 0.1.9`).

GitHub API: `GET https://api.github.com/repos/adayag/kopanda/releases/latest` (public repo, no token; 404 while no release exists). Fields used: `tag_name`, `body`, `assets[].name`, `assets[].browser_download_url`. Only asset URLs starting with `https://github.com/adayag/kopanda/releases/download/` are accepted.

Running checks: `bin/check spec/unit/<name>_spec.lua` (several allowed), `bin/check --lint`, `bin/check --unit` (whole unit gate, minutes), `npm --prefix studio run check` / `npm --prefix studio test -- <file>`. Filter `bin/check` output (KOReader chatter): `... 2>&1 | grep -E "FAILED|PASSED|tests from|Error|error:|expected|assert|Failure|\.lua:[0-9]+" | head -80`.

Rules: TDD (each test red first, report the red); minimal change; KOReader Lua style; every KOReader citation verified against `~/Projects/kodev/koreader/` at the pinned build; HOOKS.md names every new KOReader surface (`spec/unit/hooks_doc_spec.lua` checks required modules mechanically); no commits, no staging.

---

## Half A: the device (`kopanda.koplugin/`)

Files: new `release_source.lua`; modify `push_pull.lua`, `push_bundle.lua`, `push_apply.lua`, `studio_menu.lua`, `_meta.lua`, `HOOKS.md`; specs new `spec/unit/release_source_spec.lua`, modify `spec/unit/push_bundle_spec.lua`, `push_apply_spec.lua`, `push_pull_spec.lua`, `studio_menu_spec.lua`. Read first: all of `push_pull.lua` (277 lines), `push_bundle.lua`, `push_apply.lua`, `studio_menu.lua`, and the matching specs for their stubbing patterns (how `socket.http` and the file system are stubbed, how `harness` is used).

### A1: `push_bundle.check_manifest` accepts a plugin-only manifest
- Test first: a manifest with `settings = false` and only `plugin/` paths passes and returns `settings = false` on the result; one with `settings = false` that also lists `settings.lua` is refused ("a plugin-only manifest names settings.lua"); one without the key still requires `settings.lua`; `settings = true` or any other non-false value behaves as absent. `verify_files` is unchanged.
- Implement: `REQUIRED` splits into the plugin files and the settings file; the result carries `settings = (doc.settings ~= false)`.

### A2: `push_apply` applies and rolls back a plugin-only stage without touching settings
- Read `push_apply.lua` whole first: `run`, the stage validation (around :259, which requires `settings.lua` in the stage), the rollback record (`had_settings`, `had_settings_old`), `restore`'s settings step (around :330).
- Test first (in `push_apply_spec.lua`, using its existing scratch data-dir fixtures): a stage record with `settings = false` and a stage without `settings.lua` applies (plugin folder swapped), the settings file is byte-identical after the apply, the rollback record marks settings untouched, and a later `restore` leaves the settings file byte-identical and present (also when no settings file existed before: none is created or removed). A record with `settings = false` whose stage lacks `plugin/main.lua` is still refused.
- Implement: the record gains `settings` (boolean, default true when absent for old records); validation requires `settings.lua` only when true; the apply skips the settings swap and rollback copy when false and writes `settings_untouched = true` into the rollback record; `restore` skips its settings step when `settings_untouched`.

### A3: `push_pull.pull` takes a source
- Test first (`push_pull_spec.lua`): `PushPull.pull{ source = function(paths) ... end, profile = "release", ... }` stages whatever manifest the source returns after writing files into `paths.download`, with no address needed (`refusal` skips the address check when `source` is given); the stage record carries `settings` from the manifest; the studio path is unchanged (existing tests).
- Implement: `download(paths, base, profile)` becomes the default source; `pull` calls `opts.source or studio_source(base, profile)`; `stage` writes `settings = manifest.settings` into the record. Make `fetch_json` and `fetch_file` public on `PushPull` (same bodies) for the release source to reuse.

### A4: `release_source.lua`
- Test first (`release_source_spec.lua`, `socket.http` stubbed as `push_pull_spec.lua` stubs it):
  - `ReleaseSource.latest()` parses a release JSON fixture (tag `v0.2.0`, body, two assets) into `{ version = "0.2.0", notes = "...", manifest_url, zip_url }`; a 404 gives nil and "No release yet" wording; a release missing either asset or with an asset URL outside the allowed prefix gives nil and why; a malformed body gives nil and why.
  - `ReleaseSource.compare("0.1.10", "0.1.9") > 0`, equal → 0, `"0.0.0-dev"` older than `"0.0.1"`, both unparsable → 0.
  - `ReleaseSource.installed_version(plugin_dir)` reads `_meta.lua` from a scratch folder; a missing or broken file gives `"0.0.0-dev"`.
  - `ReleaseSource.source(release)` returns a function(paths) that: fetches `manifest_url` into `paths.download/manifest.json`, checks it with `PushBundle.check_manifest(doc, "release")`, requires `manifest.settings == false`, fetches `zip_url` to `paths.download/kopanda.koplugin.zip`, unpacks it with `ffi/archiver` (`Reader:open`, `iterate`, `extractToPath`; read `~/Projects/kodev/koreader/koreader-emulator-arm64-apple-darwin23.5.0-debug/koreader/ffi/archiver.lua:29-160` and cite it), refuses an entry whose path is not `kopanda.koplugin/<safe path>` (`PushBundle.safe_path`) or that is not a regular file, renames `download/kopanda.koplugin` to `download/plugin`, removes the zip and manifest.json, runs `PushBundle.verify_files(paths.download, manifest)` and returns the manifest. Test with a real small zip built in the spec by `ffi/archiver`'s `Writer` (`:197-360`) into a scratch dir: the happy path; a zip with an extra entry outside the folder refused; a zip whose file differs from the manifest refused by verify; a manifest without `settings = false` refused.
- The HTTP user agent: `socketutil.USER_AGENT` as a header on the API request (GitHub requires a UA).

### A5: the menu item
- Test first (`studio_menu_spec.lua`, `ReleaseSource` stubbed): "Check for update" appears in the Studio sub-menu; with the latest equal to or older than installed, one note "KoPanda 0.1.3 is the latest" (installed version in the text); newer: a ConfirmBox whose text holds the version and notes, with ok_text "Install"; its ok runs `PushPull.pull` with `source` and `profile = "release"` behind the painted "Installing v0.2.0…" note and then offers the restart ("Restart to apply v0.2.0?"); a `latest()` failure shows its message as a note and runs nothing; the network prompt path matches Pull's.
- Implement in `studio_menu.lua`, reusing `offer_restart` (give it the text to name), `note`, `guarded`, `network():runWhenConnected`.

### A6: `_meta.lua`, HOOKS.md, gates
- `_meta.lua` version `0.0.0-dev` (a spec in `release_source_spec` asserts the repo's own file parses as older than any release).
- HOOKS.md: `ssl.https` via `socket.http`'s scheme table (`common/socket/http.lua:30-41`, redirect following `:303-319`, no https downgrade `:312-313`), `ffi/archiver` Reader and Writer lines, GitHub's API fields and the asset URL prefix as assumptions, `socketutil.USER_AGENT`.
- Gates: `bin/check spec/unit/release_source_spec.lua spec/unit/push_bundle_spec.lua spec/unit/push_apply_spec.lua spec/unit/push_pull_spec.lua spec/unit/studio_menu_spec.lua spec/unit/hooks_doc_spec.lua`, `bin/check --lint`, `bin/check --unit`. Also `bin/check spec/emulator/push_spec.lua` (the studio pull's emulator spec; it must still pass).

## Half B: the studio and the workflow

Files: new `studio/src/server/release-bundle.ts`, `bin/bundle`, `.github/workflows/release.yml`, `studio/test/server/release-bundle.test.ts`; modify `studio/package.json` (a `bundle` script), `studio/src/server/bundle.ts` (a plugin-only build), `.env.example` only if a variable is added (none planned), `AGENTS.md` (one line under Commands for `bin/bundle`, and the "not published" sentence in the first paragraph becomes "The repo is public; the plugin is owner-only and unsupported."). Read first: `studio/src/server/bundle.ts` whole, `studio/test/server/bundle.test.ts`, `studio/test/server/push.test.ts`, `bin/schema-json` (the shape of a `bin/` wrapper), `bin/check:1-70`.

### B1: `buildReleaseBundle` in `bundle.ts`
- Test first (`release-bundle.test.ts`): given a plugin dir with `_meta.lua` containing `version = "0.0.0-dev"` and a version `1.2.3`, the result's files are every plugin file under `plugin/`, no `settings.lua`, `plugin/_meta.lua` bytes equal the source with `version = "1.2.3"` substituted (only the `version = "..."` line changes; a `_meta.lua` without a version line is an error naming it), `hash` equals `hashTree` of those files, and `manifest()` is `{format: 1, profile: "release", hash, settings: false, files}` with files in byte order. The existing `buildBundle` tests unchanged.
- Implement: `buildReleaseBundle({ pluginDir, version })` reusing `readFolder`, `hashTree`, `sha256Hex`, `sortedPaths`.

### B2: `release-bundle.ts` CLI and `bin/bundle`
- CLI: `tsx src/server/release-bundle.ts <version> <out_dir>` writes `<out_dir>/manifest.json` (JSON, sorted keys as `bin/schema-json` prints, trailing newline) and `<out_dir>/kopanda.koplugin.zip` built by spawning `zip -X -q -r kopanda.koplugin.zip kopanda.koplugin` inside a temp dir where the bundle's files were written under `kopanda.koplugin/` (so the zip's bytes are the rewritten ones); exits 2 with usage for a bad version (`^\d+\.\d+\.\d+$`) or missing out dir, 1 with the error otherwise.
- Test first: run the CLI on a temp plugin dir via `execFileSync` with `tsx`; `manifest.json` parses to the B1 manifest; `unzip -l` lists exactly `kopanda.koplugin/<rel>` entries; unzipping and hashing each file matches the manifest's sha256; a bad version exits 2.
- `bin/bundle <version> <out_dir>`: a bash wrapper like `bin/schema-json` that runs `npm --prefix studio run --silent bundle -- "$@"`, refusing with exit 2 without `studio/node_modules`. `package.json` gets `"bundle": "tsx src/server/release-bundle.ts"`.

### B3: the workflow `.github/workflows/release.yml`
```yaml
name: release
on:
  push:
    branches: [main]
    paths: ["kopanda.koplugin/**"]
concurrency: { group: release, cancel-in-progress: false }
permissions: { contents: write }
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm, cache-dependency-path: studio/package-lock.json }
      - run: npm ci --prefix studio
      - uses: lunarmodules/luacheck@v1
      - run: npm --prefix studio run typecheck && npm --prefix studio run lint
      - id: version
        run: |
          last="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo v0.1.0)"
          ... bump patch → next; echo "next=$next" >> "$GITHUB_OUTPUT"; echo "last=$last" ...
      - run: bin/bundle "${next#v}" release
      - run: |
          notes from `git log --format='- %s' $last..HEAD -- kopanda.koplugin` (all commits when no last tag)
          gh release create "$next" --target "$GITHUB_SHA" --title "$next" --notes-file notes.md release/manifest.json release/kopanda.koplugin.zip
        env: { GH_TOKEN: ${{ github.token }} }
```
`gh release create --target` creates the tag at that commit, so the tag exists only after the assets are built. Check `lunarmodules/luacheck@v1`'s current usage (it runs `luacheck .` honouring `.luacheckrc`; verify in its README via `gh api repos/lunarmodules/luacheck/contents/action.yml`), and that luacheck 1.2.0 matches the local version. Note: this workflow runs for the first time on the real push after merge; there is no local run. Validate the YAML with `node -e "require('yaml')"` only if `yaml` is already a dependency, else `python3 -c "import yaml"`, else skip and say so.

### B4: docs and gates
- `AGENTS.md`: the two edits above.
- Gates: `npm --prefix studio run check`, `bin/check --lint`, `bin/check spec/unit/studio_catalog_spec.lua spec/unit/schema_json_spec.lua` (unchanged, must stay green), and `bin/bundle 9.9.9 <scratch>` by hand with `unzip -l` of the result shown.

## Lead's closeout (not a builder's)
- Cross-check: run `bin/bundle 0.0.1 <scratch>`, unzip it into a scratch `download/`, rename to `plugin/`, and run the Lua `check_manifest` + `verify_files` on it through the emulator's luajit: the studio's release manifest must pass the device's checks.
- Commit, push (= first release), watch the workflow, then on the Kindle: Check for update.
