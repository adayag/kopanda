---
node: F-29oj9m
criteria:
  - id: C1
    statement: "driver.capture with device = { width, height, dpi, color } captures at that size and that colour flag under any profile name matching ^[a-z0-9-]+$, refusing another name; with settings_file the scratch KO_HOME holds that file at settings/kopanda/settings.lua before the run, and a settings_file that is not a file is an error naming it; the home fixture with KOPANDA_HOME_WEATHER_LATITUDE, _LONGITUDE and _UNITS set writes its reading for them (16.3 in celsius), so a home whose settings store that location and units shows a reading where the same home without the variables shows none; one or two of the three set, a non-number coordinate or a unit outside the schema's ends the run with status 4; a copied settings file returning a non-table renders as all defaults with the look stored"
    polarity: introduce
    binding:
      type: test
      ref: "spec/emulator/capture_inputs_spec.lua"
      run: "bin/check spec/emulator/capture_inputs_spec.lua"
    required: true
  - id: C2
    statement: "bin/preview 1264 1680 300 color diner day <out.png> with no settings file writes a PNG that passes golden.check against home-diner-colorsoft at the home goldens' max_fraction (0.00002), and bin/preview 1264 1680 300 color editorial night <out.png> one that passes against home-night-editorial-colorsoft at the night goldens' default; neither run regenerates a golden, KOPANDA_UPDATE_GOLDENS set or not; each prints exactly one JSON line with png, width, height and paint_ms on stdout and nothing on stderr"
    polarity: introduce
    binding:
      type: test
      ref: "spec/emulator/preview_spec.lua"
      run: "bin/check spec/emulator/preview_spec.lua"
    required: true
  - id: C3
    statement: "A settings change produces a different render: a settings file storing another text_size renders differently from no settings file; a file storing a non-default weather.location in celsius renders differently from the same location in fahrenheit; a settings file storing look = editorial rendered as diner equals the default diner render's golden; and a grey 1072x1448 @ 300 device renders a 1072x1448 PNG"
    polarity: introduce
    binding:
      type: test
      ref: "spec/emulator/preview_spec.lua"
      run: "bin/check spec/emulator/preview_spec.lua"
    required: true
  - id: C4
    statement: "bin/preview refuses with exit 2 and its usage for a wrong argument count, a size that is not a positive integer, a colour, look or variant outside its list, and a settings file argument that is not a file; with no luajit at KOPANDA_EMULATOR it exits 2 naming the path; a failed render exits 1 with the failure's message, log lines included, on stderr and nothing on stdout; its scratch directory is removed on success and on failure"
    polarity: introduce
    binding:
      type: test
      ref: "spec/unit/preview_cli_spec.lua"
      run: "bin/check spec/unit/preview_cli_spec.lua"
    required: true
  - id: C5
    statement: "POST /api/profiles/:id/preview with { look, night } runs the preview command with the profile's width, height, dpi, color or grey, the look, day or night, a temporary PNG path and the settings path only when the file exists, and answers 200 image/png with Cache-Control no-store and the temporary file removed; a look outside the schema's choices or a non-boolean night is 400, an unknown or invalid profile 404; exit 2 is 503 and any other failure 502, each { error, log } with error the first stderr line and log at most the last 40 of the rest; a run past the time limit (150 s by default) is killed with its process group and answers 502 No render within <limit> s; renders run one at a time in arrival order, and a queued request whose client has gone never runs"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/server/preview.test.ts"
      run: "npm --prefix studio test -- test/server/preview.test.ts"
    required: true
  - id: C6
    statement: "The preview pane shows the profile's name, device and resolution, one frame named for the profile's look that follows a look change, and with Both looks a Diner and an Editorial frame side by side; Night switches the frames to night images, each frame keeping its last good image for the open profile; a shown frame with no image renders at once, and after a failed first render makes no further request until a landed write or Re-render; a landed write marks each image stale and renders each shown frame 1.5 s after the last write, a write in the pause restarting it; a frame rendering when the write lands renders at the pause's end if its render ended first, and as soon as its render ends if the pause ended first; Re-render renders every shown frame now and is disabled while one renders; the states read Rendering in the emulator… over the dimmed previous image, Rendered in <n> s, a stale badge with Settings changed · re-rendering in 1.5 s, and a failure as an amber panel with the error, Showing the last good render. or No earlier render to show., and the log lines, the last good image kept"
    polarity: introduce
    binding:
      type: test
      ref: "studio/test/ui/preview.test.tsx"
      run: "npm --prefix studio test -- test/ui/preview.test.tsx"
    required: true
  - id: C7
    statement: "The studio's typecheck, lint and tests pass"
    polarity: introduce
    binding: { type: command, run: "npm --prefix studio run check" }
    required: true
  - id: C8
    statement: "The owner opens the Colorsoft profile in npm start, sees its home rendered in about ten seconds, changes a setting in the form and in the layout editor and sees the image go stale and re-render with the change, turns on Both looks and Night and sees all four renders, opens the Paperwhite profile and sees its greyscale home at its own size, and, after restarting the server with KOPANDA_EMULATOR pointing at a missing directory and without reloading the tab, presses Re-render and sees the failure keep the last good image"
    polarity: introduce
    binding: { type: manual }
    required: true
  - id: C9
    statement: "The dev loop's captures survive the driver's and the home fixture's new inputs: every emulator spec present at the baseline and the driver's unit spec pass, every golden matching as before"
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
      run: >-
        bin/check spec/emulator/book_close_spec.lua spec/emulator/capture_spec.lua
        spec/emulator/gesture_forward_spec.lua spec/emulator/golden_spec.lua
        spec/emulator/home_capture_spec.lua spec/emulator/home_golden_spec.lua
        spec/emulator/night_golden_spec.lua spec/emulator/night_toggle_spec.lua
        spec/emulator/sheet_golden_spec.lua spec/emulator/swatch_golden_spec.lua
        spec/unit/driver_spec.lua
    baseline:
      surface: "spec/emulator"
      captured_at: { kind: git_tree, value: "git:8bbff12", path: spec/emulator, observed_at: "2026-10-15T00:00:00Z" }
    required: true
---

# Acceptance

The preview is accepted when the capture takes a profile's screen and settings (C1), `bin/preview`
renders the real home, equal to the goldens for default settings (C2) and different for different
settings at the profile's own size (C3), and refuses or fails plainly (C4); the server runs it one at a
time and reports failures with their log (C5); the pane shows both looks, night and every state, and
keeps the last good image through a failure (C6); the studio's own checks pass (C7); the dev loop's
captures and goldens survive (C9); and the owner has seen it work on both profiles (C8).
