# Releases on GitHub, updates from the device

2026-10-18. Until today the only way to update KoPanda on the Kindle was a hand push over MTP or,
since this morning, a pull from the studio on the LAN, which needs the Mac on and the studio
running. The owner made the repo public (`adayag/kopanda`) so the device can update from GitHub
releases, as SimpleUI does, with no studio in between. The project doc's "not published" line
changes to: the repo is public, the plugin is owner-only and unsupported.

## What the owner sees

Nothing on the Mac. A push to `main` that changes anything under `kopanda.koplugin/` is a
release: GitHub Actions bumps the patch version, tags the commit, builds the bundle and publishes
the release. The agent asks before pushing, as it does now; the push is the release.

On the Kindle, Tools › KoPanda › Studio gains one item, **Check for update**. Tap it (Wi-Fi is
prompted as for a pull):

- Same or older release than the device's version: a note, "KoPanda 0.1.3 is the latest".
- Newer: a confirm box with the version and the release notes, Install or Cancel. Install
  downloads behind the pull's painted note, verifies, stages, and offers the restart that applies
  it. The next start swaps the plugin folder, keeps it on probation until the home paints, and
  rolls back if it doesn't, exactly as a studio pull does.
- Any failure (no network, GitHub unreachable or rate-limited, a bad download, a manifest that
  doesn't match): a note with the reason, the current install untouched.

No check at startup, no banner: the screen redraws only on input, and Wi-Fi is off most of the
time. The studio pull stays as it is, and stays the way to push profile settings.

Decisions taken with the owner:

- The owner never tags. Releases are cut by the workflow on every plugin-changing push to main,
  patch number incremented from the last tag (`v0.1.0` → `v0.1.1` → …). A push that touches only
  docs, specs or the studio makes no release.
- A release is plugin-only. It carries no settings; the device's `settings/kopanda/settings.lua`
  is left alone. The bundle manifest gains `settings = false` for this; the studio's bundles
  keep carrying settings.
- Decided 2026-10-19 alongside: no device profiles or registration. Code reaches the device
  through releases; settings live on the device and are edited in its menus; the studio is a
  development tool (form, preview, fit check, catalog). Its profile list and LAN pull remain only
  as the way to try a working-tree build on the device.
- Manual check only. Out of scope: automatic checks, pre-release channels, downgrade, signing
  beyond the manifest's sha256 per file.
- No emulator in CI. The goldens stay local and run before a push, as now. CI runs luacheck and
  the studio's typecheck and lint, then builds the bundle. A commit that fails those makes no
  release and the workflow fails loudly.

## How it works

### The release workflow (`.github/workflows/release.yml`)

On `push` to `main` with a path filter on `kopanda.koplugin/**`:

1. Check out with tags. Compute the next version: the highest `v*` tag's patch plus one, or
   `v0.1.0` when there is none.
2. Install Node 22 and `npm ci --prefix studio`; install luacheck (luarocks). Run `luacheck .`
   and `npm --prefix studio run typecheck` and `lint`.
3. Build the bundle with `bin/bundle <version> <out dir>`: a studio command that uses the same
   builder as the LAN route (`studio/src/server/bundle.ts`), with `_meta.lua`'s `version` set to
   the release's in the bundled copy only. It writes `manifest.json` (format 1, `settings =
   false`, the files with size and sha256, the tree hash) and `kopanda.koplugin.zip` (the plugin
   folder at its top level, the files exactly as hashed).
4. Tag the commit, create the release with `gh release create`, notes from the commit subjects
   since the previous tag, and upload the two assets.

The repo's own `_meta.lua` stays at `0.0.0-dev` so a hand-pushed copy never claims a release's
version; the device treats an unparsable version as older than any release.

### The device (`kopanda.koplugin/`)

- **`release_source.lua`** (new): `latest()` GETs
  `https://api.github.com/repos/adayag/kopanda/releases/latest` over `ssl.https` with the pull's
  timeouts and KOReader's user agent, and returns `{ version, notes, manifest_url, zip_url }` or
  nil and why. `compare(a, b)` orders dotted versions; an unparsable one is older than any.
  `download(release, paths)` fetches the manifest and the zip into the pull's download folder,
  following GitHub's redirect to its download host, unpacks the zip with `ffi/archiver`, and
  returns the manifest. `push_pull.lua`'s verify and stage then run unchanged. Every `https://`
  request verifies the server: its chain against KOReader's CA bundle (`data/ca-bundle.crt`)
  and its certificate's DNS names against the host, following one redirect at most; each file
  is then checked by size and sha256 against the manifest fetched that way, and the zip's files
  are read into memory and written by the plugin, never extracted through libarchive's disk
  writer.
- **`push_bundle.lua`**: `check_manifest` accepts `settings = false`, under which `settings.lua`
  is not required; `verify_files` is unchanged.
- **`push_apply.lua`**: a stage whose manifest has `settings = false` leaves the settings file
  alone and swaps only the plugin folder.
- **`studio_menu.lua`**: the "Check for update" item, between Pull and the address. It reuses
  the pull's Wi-Fi prompt, painted note and restart offer. The device's version comes from the
  installed `_meta.lua`.
- **HOOKS.md** gains `ssl.https`, `ffi/archiver` and the redirect handling, with the lines read.
- Assumption to verify first: LuaSocket's redirect following across `ssl.https` for the asset
  URL (GitHub answers 302 to `objects.githubusercontent.com`). If it doesn't follow, the source
  reads the `Location` header and requests once more.

## Tests

- `spec/unit/release_source_spec.lua`: the API's JSON parsed into a release; a release without
  the two assets refused; version compare (`0.1.10 > 0.1.9`, dev older than all); download with
  HTTP stubbed as `push_pull_spec.lua` stubs it, a real small fixture zip unpacked, a zip whose
  contents don't match the manifest refused by verify.
- `spec/unit/push_bundle_spec.lua` / `push_apply_spec.lua`: the plugin-only manifest accepted;
  the apply leaves the settings file byte-identical and swaps the plugin.
- `spec/unit/studio_menu_spec.lua`: the item's three outcomes (latest, newer with Install, a
  failure note) with the source stubbed.
- `studio/test/`: `bin/bundle` writes a manifest equal to the LAN route's for the same tree,
  with `settings = false` and the given version in `_meta.lua`; the zip's entries match.
- The workflow is exercised by the first real push after merge; `act` is not used.

## Failure handling

Every device step returns a value or nil and a message; the menu shows the message and nothing
else changes. The workflow fails on any step and publishes nothing partial: the tag is pushed
only after the bundle is built and the release created.
