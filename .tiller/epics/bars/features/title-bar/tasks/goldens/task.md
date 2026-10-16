# File-browser goldens with the title bar in both looks on both profiles

## Approach

Nav-bar's four file-browser goldens regenerated with KoPanda's title bar, the scenario showing the home folder
so the header reads as the boards draw it, and nav-bar's paint budget held. Starts after
`bars/title-bar/file-browser`. Repo lines on `main` at `6443f03`, and nav-bar's scenario and spec as nav-bar's
`goldens` task (T-1r8qb2) leaves them; KOReader relative to `~/Projects/kodev/koreader/` at `e1fe1ac`. The
feature's "Goldens and budget" is the spec.

1. **The home folder.** Read `spec/emulator/scenarios/2-scenario-file-browser.lua`'s header for how nav-bar
   settled its F3 (nav-bar task `goldens` step 1). Candidates: (a) it already stores the fixture library as
   `home_dir` before the file browser shows; (b) it doesn't. For (b), the scenario stores it then, through
   `G_reader_settings:saveSetting("home_dir", <the library's path>)`, the key `filemanagerutil.getHomeFolder`
   reads (`frontend/apps/filemanager/filemanagerutil.lua:25-27`) and one the home fixture never writes
   (nav-bar task `goldens` step 3). It is stored in the same tick that closes the home, before
   `Home.close()` (nav-bar task `goldens` step 3; `kopanda.koplugin/home.lua:226-230`), so the first paint
   with the file browser on top, the one the shot takes, reads it. The library's path comes from the
   directory the driver starts KOReader on (`spec/emulator/driver.lua:203`, `:241-243`), read in the
   scenario as `FileManager.instance.file_chooser.path`: the file manager is already beneath the home
   (`frontend/apps/filemanager/filemanager.lua:447`), and its path is a realpath (`:1320`). Either way the
   header's title is "Library" (D1), and the scenario's header comment says so.
2. **Regenerate** with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/nav_golden_spec.lua`. The spec itself
   is nav-bar's and needs no change: it already asserts the `file_browser` screen, one shot, no settle cap and
   `0 < paint_ms <= 250` (nav-bar task `goldens` step 4). Open each of the four PNGs (`open <png>`) beside
   `Library.dc.html` and `LibraryC.dc.html` and list the deliberate differences in the PR: KOReader's list
   under the header (the boards draw a cover grid, stage 5), the counts and labels of the fixture ("3 books",
   "Name", "All" against the boards' "142 books", "Recent", "Reading"), the plus icon no board draws, the
   down mark F1 chose. A second plain run passes.
3. **The budget:** if a capture's `paint_ms` exceeds 250 ms with the bar, stop and bring the figures to the
   lead with a per-step timing (the setupLayout duration against the first paint), rather than raising the
   budget.

## Surfaces

`spec/emulator/scenarios/2-scenario-file-browser.lua` (only for candidate (b)),
`spec/goldens/filebrowser-diner-colorsoft.{png,json}`, `filebrowser-editorial-colorsoft.*`,
`filebrowser-diner-paperwhite.*`, `filebrowser-editorial-paperwhite.*` (regenerated). The driver, the capture
patch and the home fixture don't change.

## Tests

- `nav_golden_spec.lua` (C9): fails first against nav-bar's goldens (the header differs); then the goldens
  are regenerated, eyeballed and committed, and a second plain run passes.
  - Prove the shot carries the bar: in a scratch run with the swap disabled (`KoTitleBar.new` stubbed to
    raise in a scratch userpatch), see the capture differ from the new goldens in the header's rows only.
- `home_golden_spec.lua`, `night_golden_spec.lua`, `sheet_golden_spec.lua`, `screens_golden_spec.lua` and
  `golden_spec.lua` (C11) run unchanged and pass; `swatch_golden_spec.lua` passes on the goldens `bar`
  regenerated (C10).

## Edge cases

- Storing `home_dir` for the capture changes where the nav bar's Library tab and `fm:onHome()` go in that
  run only; the scenario's profile is a scratch `KO_HOME` (`spec/emulator/driver.lua:256-264`).
- With `home_dir` the library, KOReader still shows the go-up entry unless `lock_home_folder` is set
  (`frontend/ui/widget/filechooser.lua:265-276`); it is not counted (D2), so the count stays three.
- CoverBrowser's list covers are nav-bar's F4 (nav-bar task `goldens` step 2): whatever nav-bar settled holds
  here unchanged, since the bar doesn't touch the rows' content.
- The Paperwhite capture is the grey look (`spec/emulator/profiles.lua`; `Looks.variant`,
  `kopanda.koplugin/looks.lua:30-43`); Diner's mustard band, paper and pink chips are its greys
  (`kopanda.koplugin/looks/diner.lua:57-75`), kept apart by `looks_spec.lua`'s grey-distinctness rule (`spec/unit/looks_spec.lua:171-180`).
