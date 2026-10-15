# Cover from CoverBrowser's cache, typographic placeholder and bounded extraction

## Approach

The cover box as a KOReader widget, plus the one extraction path. Paths into KOReader are relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`.

1. **Open fact first: is CoverBrowser enabled on the owner's Kindle?** Read
   `/mnt/us/koreader/settings.reader.lua` over USB (handoff §4: MTP, one session per plug) and look for
   `coverbrowser` in `plugins_disabled` (`frontend/pluginloader.lua:175`, `:212`). Record the answer in
   the PR. The widget works either way; the answer tells the owner whether C15's cover path is the one the
   Kindle takes.
2. **Tokens.** Add the palette roles `cover` and `on_cover` to all three palettes of both looks, with
   the feature's values and each value's board line in a comment. Add these `type` parts, each value
   from its board line:
   - `cover_title`: Editorial display 24, uppercase, tracking 0.04, line height 1.05, `on_cover`
     (Main:34); Diner display 22, the same (HomeRetro:29; the board's Georgia is not a Diner face).
   - `cover_authors`: text 11 (Editorial, Main:35) or 10 (Diner, HomeRetro:30), uppercase, tracking 0.12,
     `on_cover`.
   - `cover_empty`: Editorial text 12, uppercase, tracking 0.1, `muted` (EmptyStates:33); Diner `strong`
     12, the same.

   Add the `featured` block's cover entries:
   - `cover_w`, `cover_h`: Editorial 150/225 (Main:33); Diner 140/210 (HomeRetro:28);
   - `cover_padding { x, y }`: Editorial 14/18; Diner 12/16;
   - `dash`, `dash_gap`: 4/4.
3. **`kopanda.koplugin/featured_cover.lua`.**
   - **`FeaturedCover.box(width, ctx)`** returns `w, h`: the token size scaled by `Screen:scaleBySize`,
     with `w` at most `floor(0.4 × width)` and `h = floor(1.5 × w)`.
   - **`FeaturedCover.build(book, w, h, ctx)`** returns the framed box:
     - `book` nil: the dashed frame around "No book yet".
     - A usable cover: `ImageWidget{ image = info.cover_bb, width = w, height = h, scale_factor = 0 }`
       (`frontend/ui/widget/imagewidget.lua:88-89`), in a `CenterContainer` of `w × h` on `paper`.
     - Otherwise the typographic placeholder: a `cover`-filled box with the title (`TextBoxWidget`, four
       lines at most, `height_overflow_show_ellipsis`, `frontend/ui/widget/textboxwidget.lua:54`) at the
       top and the authors at the foot.
     - The frame: an outline at `stroke.outline` in `outline` when that role resolves in the variant, a
       shadow box offset by `shadow.cover` when its colour resolves, and `radius.cover` on the outline,
       shadow and placeholder fill only (`frontend/ui/widget/container/framecontainer.lua:124-139` rounds
       background and border, not content).
     - The dashed frame is drawn by a small widget whose `paintTo` paints `dash`-long rects with
       `dash_gap` gaps along each edge (`bb:paintRect`).
   - **The cover read.**
     - `pcall(require, "bookinfomanager")`; failure means no CoverBrowser, so the placeholder.
     - Then `getBookInfo(file, true)` (`plugins/coverbrowser.koplugin/bookinfomanager.lua:325-404`). A
       cover is usable when `has_cover` and `cover_bb` are set and
       `BookInfoManager.isCachedCoverInvalid(info, specs)` is false (`:1013-1030`), with
       `specs = { max_cover_w = w, max_cover_h = h }`.
     - An unusable result frees its `cover_bb` (`cover_bb:free()`, as `mosaicmenu.lua:478-479` does).
   - **`FeaturedCover.wants_extraction(info, specs)`** is false without CoverBrowser. Otherwise it decides
     in the feature's order, as `mosaicmenu.lua:471-488` does:
     1. `info` nil: true.
     2. `unsupported` or `ignore_cover` set, or `cover_fetched` set without `has_cover`: false.
     3. `cover_fetched` nil: true.
     4. `has_cover` set and `isCachedCoverInvalid(info, specs)`: true.

     The never-ask rows come before the size test, because `isCachedCoverInvalid` is true for any row
     without `cover_w` (`bookinfomanager.lua:1014-1015`).
   - **`FeaturedCover.after_show(home, file, specs)`** is called from the widget through the home's
     settled hook, the `nextTick` that `home-layout`'s weather task adds (its task.md §2, "Session
     triggers"):
     - When `wants_extraction` holds and `file` isn't in the module's `asked` set, it calls
       `BookInfoManager:extractInBackground({ { filepath = file, cover_specs = specs } })` (`:689-745`),
       adds `file` to `asked` and schedules `check` with `UIManager:scheduleIn(1, check)`.
     - `check` stops when `home` is no longer `Home.shown`, after 30 runs, or when
       `isExtractingInBackground()` (`:685-687`) is false. On stopping, if `getBookInfo` now gives a usable
       cover, it calls `home:refresh()` once. Otherwise it re-schedules itself.
     - The widget's close path calls `UIManager:unschedule(check)`, so a closed home leaves nothing
       queued.
   - `FeaturedCover.reset()` for specs.
4. **HOOKS.md:** `bookinfomanager` (its `require` path and why it is reachable only when CoverBrowser is
   enabled, `pluginloader.lua:283-287`), `getBookInfo` and its columns, `extractInBackground`,
   `isExtractingInBackground`, `isCachedCoverInvalid`, `ImageWidget` `scale_factor` and
   `image_disposable`, and the CoverBrowser polling precedent (`covermenu.lua:164-175`).

## Surfaces

`kopanda.koplugin/featured_cover.lua` (new), `looks/editorial.lua`, `looks/diner.lua`, `HOOKS.md`;
specs `spec/unit/featured_cover_spec.lua` (new), `spec/unit/looks_spec.lua`.

## Tests

Written first and run failing. `bookinfomanager` is stubbed in `package.loaded`, and so is
`UIManager.scheduleIn`/`unschedule` (recording calls); everything is restored in `finally`.

- `featured_cover_spec.lua` (C5):
  - A 300×600 stub `cover_bb` in a 150×225 box is drawn at its fitted size, centred, with `paper` on the
    long sides. A 600×300 one gets paper above and below.
  - Each `wants_extraction` row of the feature: true for nil, `cover_fetched` nil and a too-small cover;
    false for `unsupported`, `ignore_cover` and no cover, each with `cover_w` nil so the real
    `isCachedCoverInvalid` would say true.
  - `after_show` asks once for a file across two shows. `build` and `paintTo` never call
    `extractInBackground` (the stub fails the test if they do).
  - With `isExtractingInBackground` true for three checks and then false with a usable cover, `refresh`
    is called once and nothing stays scheduled. With it never false, checks stop at 30 with no refresh.
    Closing the home mid-way unschedules.
  - `bookinfomanager` unrequirable: the placeholder is built with `cover` and `on_cover`, and nothing is
    scheduled.
  - An unusable `cover_bb` is freed (the stub counts `free`).
  - The 40 % cap at a 300 px column.
- `looks_spec.lua` (C7, cover part): the identical-paths invariant covers the new roles and parts. The
  grey-distinctness check passes, since `on_cover` equals `paper` by day as well as in grey.

## Edge cases

- `extractInBackground` terminates earlier jobs, CoverBrowser's own among them, and closes the DB
  connection (`bookinfomanager.lua:689-745`). The home covers the file browser, so CoverBrowser is not
  extracting for a visible list then. Its next `updateItems` asks again (`covermenu.lua:109-131`).
- `isExtractingInBackground()` counts CoverBrowser's own jobs too. A check that sees it still true for
  someone else's job just waits, within the 30-check cap.
- A book whose extraction crashed three times reads nil from `getBookInfo` until the next ask. That ask
  writes the row as `unsupported`, with `cover_fetched = 'Y'` (`bookinfomanager.lua:463-479`), and from
  then on `wants_extraction` says never. `asked` keeps the widget to one ask per process.
- Night mode's pre-inversion of the cover is `night-mode`'s.
