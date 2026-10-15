# Static font instances shipped under the plugin and loaded by path

## Approach

1. Download, from each upstream repository at its current default-branch commit (record the commit),
   these static TTFs and the repository's `OFL.txt`, into `kopanda.koplugin/fonts/<family>/`:
   - Newsreader (github.com/productiontype/Newsreader): `fonts/static/ttf/Newsreader16pt-Medium.ttf`,
     `Newsreader16pt-MediumItalic.ttf`.
   - IBM Plex Sans (github.com/IBM/plex): `packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Regular.ttf`,
     `IBMPlexSans-Medium.ttf`.
   - Bricolage Grotesque (github.com/ateliertriay/bricolage): `fonts/ttf/BricolageGrotesque-Medium.ttf`,
     `-Bold.ttf`, `-ExtraBold.ttf`.
   - Caveat (github.com/googlefonts/caveat): `fonts/ttf/Caveat-Regular.ttf`.
   Paths and licences were read through the GitHub API on 2026-10-14, not at a pinned commit, so the
   task confirms each path exists before downloading and stops to ask if one has moved. About 1.3 MB in
   all. Downloads go to a fresh scratch directory first and are only copied in; nothing is executed
   from them.
2. `kopanda.koplugin/fonts/SOURCES.md`: per file, the repository, commit, path and `shasum -a 256`.
3. `kopanda.koplugin/fonts.lua`: `Fonts.path(rel)` joins the plugin directory and `rel` through a local
   `join(dir, rel)` (exposed as `Fonts._join` for the spec) that prefixes `./` when `dir` is relative;
   `Fonts.face(rel, size)` returns `Font:getFace(Fonts.path(rel), size)` inside a pcall, nil on failure.
   - `Font:getFace` treats a name starting with `/` or `./` as a path; anything else is looked up under
     `./fonts` and the font list (`frontend/ui/font.lua:307-327`). It returns nil after logging when
     nothing loads (`:329-332`) and scales `size` by `Screen:scaleBySize` (`:276`).
   - On the Kindle the plugin's path is relative, `plugins/kopanda.koplugin` (`frontend/pluginloader.lua:24`,
     `:204`, `:248`), so a bare relative path would resolve under `./fonts/` and fail; hence `./`.
   - The plugin directory: determine it from `debug.getinfo(1, "S").source` of `fonts.lua` (a `@path`
     as `require` found it), or from the plugin instance's `path` field set by the loader
     (`pluginloader.lua:248`) and handed to `Fonts` from `main.lua`'s `init`. Pick whichever the spec
     shows gives the same directory in the unit harness and the emulator; prefer the first if both do,
     since it needs no wiring.
4. `main.lua` requires `fonts` at load time. `HOOKS.md`: `ui/font` `getFace` path branch and its nil
   return, the plugin path lines above.

## Surfaces

`kopanda.koplugin/fonts/` (TTFs, `OFL.txt` per family, `SOURCES.md`), `kopanda.koplugin/fonts.lua`,
`main.lua` (require only), `HOOKS.md`, `spec/unit/fonts_spec.lua`.

## Tests

`fonts_spec.lua`, written first and failing with no fonts present (C6 in part; the looks task extends it
to "every face a look names"):

- Every `.ttf` under `kopanda.koplugin/fonts/` sits in a family folder holding `OFL.txt`, and is listed
  in `SOURCES.md` with a matching sha256.
- No TTF has an `fvar` table: read the table directory (offset 12, 16-byte records, tag first) and
  assert no `fvar` tag. KOReader's FreeType binding has no variation calls, so a variable file would
  render its default instance only (`base/ffi/freetype.lua:207-225`).
- Each loads through `Font:getFace` by absolute path, and by a `./`-relative path (with `../` steps)
  from the KOReader directory the specs run in (`bin/check` `cd`s there).
- The Kindle case: the unit harness's plugin directory is absolute (`spec/plugin_harness.lua:13`), so
  `Fonts._join("plugins/kopanda.koplugin", "fonts/x.ttf")` is asserted to give
  `./plugins/kopanda.koplugin/fonts/x.ttf`, and an absolute directory to stay unprefixed.
- `Fonts.face("fonts/nope/missing.ttf", 20)` returns nil and raises nothing.

## Edge cases

- Bricolage's unlabelled static set is believed to be its 14pt optical size (inferred from advance
  widths, not documented). If the owner wants another size after the panel check, that is a font swap
  in `panel-check`, not here.
- Font caches key on path and size (`frontend/ui/font.lua:288-291`); the absolute and `./` forms are
  different keys, which only costs memory in the spec.
