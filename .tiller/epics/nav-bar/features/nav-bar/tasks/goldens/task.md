# File-browser goldens in both looks on both profiles and their paint budget

## Approach

Four goldens of KOReader's file browser with the bar, Diner and Editorial on the Colorsoft and the
Paperwhite, and their paint tripwire. Starts after `nav-bar/nav-bar/file-browser`, whose frame sends the
`file_browser` settled signal. Repo lines on `main` at `fa0e7dd`; KOReader relative to
`~/Projects/kodev/koreader/` at `e1fe1ac`. The home's goldens are `home-band`'s.

1. **Open fact F3 first: does the file browser's subtitle depend on the checkout?** The title bar's subtitle
   is `folder_shortcuts:getShortcutFullName(path) or abbreviate(path)` (`frontend/apps/filemanager/filemanager.lua:108-112`);
   `abbreviate` gives "Home" for the home folder and a path relative to it below it, else the absolute path
   (`frontend/apps/filemanager/filemanagerutil.lua:29-43`). The driver starts KOReader on the library's
   absolute path (`spec/emulator/driver.lua:203`, `:241-243`) and stores no `home_dir`, but it sets
   `XDG_DOCUMENTS_DIR` to the scratch profile (`driver.lua:264-265`), which the emulator takes as its
   `Device.home_dir` (`frontend/device/sdl/device.lua:70`) and `getHomeFolder` falls back to
   (`filemanagerutil.lua:25-27`); the library is not under it. The subtitle is truncated on the left
   (`subtitle_truncate_left`, `filemanager.lua:125`).
   - Candidates: (a) the subtitle shows enough of the library's absolute path to differ between the primary
     checkout and a Tiller worktree; (b) it is "Home" or a short path, because the home folder resolves to
     the library; (c) it is the absolute path but cut on the left to a tail that is the same in every
     checkout.
   - How to tell: in a scratch run, log `filemanagerutil.getHomeFolder()` and the subtitle from the scenario,
     and capture once with the fixture library and once with a copy of it under another directory, comparing
     the title bar's rows.
   - If (a): either the scenario stores the library as `home_dir` before the file browser first shows, so the
     subtitle reads "Home", or the subtitle's rows are masked in the sidecars with a note. Pick one, say why in
     the PR, and keep the golden independent of where the repo lives. If (b) or (c): nothing changes, and the
     scenario's header says which held.
2. **Open fact F4: is CoverBrowser's list deterministic in the capture?** On a fresh profile CoverBrowser sets
   the file manager's display mode to `list_image_meta` (`plugins/coverbrowser.koplugin/main.lua:84-95`), whose
   covers are extracted into its cache; the populated fixture extracts only the featured book's cover before
   the home builds (`spec/emulator/scenarios/2-scenario-home-fixture.lua:8-13`).
   - Candidates: (a) every row's cover or placeholder is the same on every run; (b) some rows show a cover on
     one run and a placeholder on another.
   - How to tell: three plain captures per profile, compared with `compare.lua` and with empty masks.
   - If (b): stop and bring the choice to the lead with the diff: extract every fixture cover in the scenario
     before the file browser shows, or mask the cover column with a note.
3. **The scenario userpatch**, `spec/emulator/scenarios/2-scenario-file-browser.lua`, which sorts before
   `2-scenario-home-fixture.lua` (`frontend/userpatch.lua:60-61`, alphanumeric). That order is harmless: it
   registers a hook at patch time, and a `home_dir` it might write for F3 is a key the fixture never touches
   (the fixture's `G_reader_settings` writes are `document_metadata_folder` and `plugins_disabled`,
   `2-scenario-home-fixture.lua:89`, `:127-129`). A patch that must run after the fixture is named to sort
   after it, as `2-scenario-screens.lua` is (its header, `:2-3`). Modelled on `2-scenario-screens.lua`: on the
   first `KoPandaSettled` with `screen = "home"`, from the next tick, `Home.close()` (`home.lua:226-230`),
   which leaves the file browser on top on the fixture library; any failure is reported as a `scenario` signal
   with `error`. Its header says what it does and what F3 and F4 settled.
4. **`spec/emulator/nav_golden_spec.lua`**, modelled on `screens_golden_spec.lua` and `home_golden_spec.lua`
   (`:9-70`): for `filebrowser-diner` and `filebrowser-editorial` on `colorsoft` and `paperwhite`,
   `driver.capture{ profile, plugin_dir, patches = { fixture, scenario }, shot_screen = "file_browser", env =
   { TZ = "America/Chicago", KOPANDA_HOME_FIXTURE = "populated", KOPANDA_HOME_LOOK = look or "" } }`
   (`driver.lua:221-231`); assert the sidecar's `screen` is `file_browser` and it has no `error`; **the
   budget:** `0 < paint_ms <= 250` (`home_capture_spec.lua:7-10`), printed as `home_capture_spec.lua:54`
   prints it; exactly one "KOPANDA_SHOT: saved" and no "settle cap" in the log; then
   `golden.assert_golden(name, profile, result)`.
5. **Generate** with `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/nav_golden_spec.lua`, open each PNG
   (`open <png>`) beside NavBar and NavBarC, and list the deliberate differences in the PR: KOReader's own list
   and title bar above the bar (no board draws the file browser), Library active, the registry's stroke-2
   icons. A second plain run passes.

## Surfaces

`spec/emulator/scenarios/2-scenario-file-browser.lua` (new), `spec/emulator/nav_golden_spec.lua` (new),
`spec/goldens/filebrowser-diner-colorsoft.{png,json}`, `filebrowser-editorial-colorsoft.*`,
`filebrowser-diner-paperwhite.*`, `filebrowser-editorial-paperwhite.*` (new). The driver, the capture patch and
the home fixture change only if F3 or F4 needs it; if so, say why in the PR first.

## Tests

- `nav_golden_spec.lua` (C8, C11): fails first, the scenario and goldens missing; then the goldens are
  generated, eyeballed and committed, and a second plain run passes.
  - Prove the budget can fail: in a scratch run, lower it to 1 ms and see the figure in the failure.
  - Prove the shot is the file browser's: in a scratch run without the scenario patch, see the capture reach
    its settle cap (the home covers the file browser, so no `file_browser` signal comes).
- `home_capture_spec.lua` (C11) and every other emulator spec run unchanged and pass.

## Edge cases

- The fixture's weather fetch never runs (the driver turns the fake Wi-Fi off, `driver.lua:80`, `:112`), so nothing
  refreshes the home before it closes.
- The populated fixture freezes the clock (`2-scenario-home-fixture.lua:5-7`), so the list's dates, if any
  show, are the same on every run.
- The featured book's 62 % in the reading history may show in the list's progress; it is fixed by the
  fixture, the same on every run.
