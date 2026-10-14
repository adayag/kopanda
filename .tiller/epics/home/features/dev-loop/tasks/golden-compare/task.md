# Golden comparison with masks, deliberate regeneration and committed probe goldens

## Approach

A pure comparison module proven on synthetic images, a golden helper that wraps it with the file
conventions and the regeneration flag, and the first two committed goldens.

1. **`spec/emulator/compare.lua`**, `compare(actual_png, golden_png, opts)` with
   `opts = { masks = { {x=,y=,w=,h=}, ... }, tolerance = 16, max_fraction = 0.0005, diff_png = <path> }`:
   - Load both PNGs with `require("ffi/png").decodeFromFile(path, 3)` (`base/ffi/png.lua:43`), which
     returns `ok, { width, height, data, ncomp = 3 }` on success and `false, <lodepng error>` otherwise
     (`png.lua:46–47, 110–115`), with every PNG forced to RGB (`png.lua:97–100`), so
     the RGBA captures and any grey fixture read the same way and alpha never enters. Pixels are read
     straight from the `unsigned char*` as `data[(y * width + x) * 3 + c]`. The buffer is lodepng's; it
     is owned and freed by wrapping it as `BB.new(w, h, BB.TYPE_BBRGB24, data)` with `setAllocated(1)`
     and calling `free()` when done, the way `Pic.openPNGDocument` does (`base/ffi/pic.lua:341–347`).
   - Size mismatch: return `{ ok = false, reason = "size", actual = {w,h}, golden = {w,h} }` before any
     pixel is read.
   - Pixel loop over every pixel not inside a mask: differs when `|Δr|, |Δg| or |Δb| > tolerance`.
     Count differing pixels and compared pixels. `ok = differing / compared <= max_fraction`.
   - When not ok and `diff_png` is set, write a diff image: the golden in light grey with differing
     pixels in solid red, from an FFI RGB buffer through `Png.encodeToFile(path, mem, w, h, 3)`
     (`base/ffi/png.lua:16`).
   - Return `{ ok, differing, compared, fraction, diff_png }`.
   - Performance: 1264×1680 is 2.1 M pixels; a Lua loop over an FFI byte array compiles to a tight
     trace on LuaJIT and runs in well under a second. The spec asserts a 2 s ceiling on the full-size
     compare.
2. **`spec/emulator/golden.lua`**, `check(name, profile, capture_result, opts)` with
   `opts = { golden_dir = "spec/goldens", update = os.getenv("KOPANDA_UPDATE_GOLDENS") == "1" }`:
   - Paths: `<golden_dir>/<name>-<profile>.png` and `.json`.
   - `update`: copy the capture to the golden path, write the sidecar
     `{ name, profile, width, height, paint_ms, koreader = "e1fe1ac", captured_at = <ISO date>, masks = {} }`
     (preserving `masks` from an existing sidecar), print both paths, return `{ updated = true }`.
   - Otherwise: a missing golden is `error("no golden at <path>; run KOPANDA_UPDATE_GOLDENS=1 bin/check
     <spec> to create it, then look at it before committing")`. Else `compare` with the sidecar's masks,
     `diff_png = <capture dir>/<name>-<profile>.diff.png`; a failure is `error()` naming the capture, the
     golden, the diff and the differing fraction.
   - `assert_golden(...)` wraps `check` so a spec reads as one line.
3. **Goldens**: run `KOPANDA_UPDATE_GOLDENS=1 bin/check spec/emulator/golden_spec.lua`, open both PNGs,
   confirm the probe's frame, label and corner marks, commit them with their sidecars. This is contract
   criterion C11, the one manual check.
4. **`.env.example`**: document `KOPANDA_UPDATE_GOLDENS`.
5. **`AGENTS.md`**: Commands section gains the regeneration line.

## Surfaces

- `spec/emulator/compare.lua`, `spec/emulator/golden.lua` (new)
- `spec/unit/compare_spec.lua`, `spec/emulator/golden_spec.lua` (new)
- `spec/fixtures/png/` (new): tiny PNGs the compare spec uses, generated once by a helper in the spec
  from blitbuffers and committed (4×4 images: a base, a one-pixel change, a mask-sized change, a 5×4)
- `spec/goldens/probe-colorsoft.png`, `.json`, `spec/goldens/probe-paperwhite.png`, `.json` (new)
- `.env.example`, `AGENTS.md`

## Tests

Written first, each seen failing before its implementation.

- `spec/unit/compare_spec.lua` (no emulator run):
  - identical 4×4 images: `ok`, `differing == 0`, `compared == 16`.
  - one pixel changed by more than `tolerance`: `differing == 1`, and with `max_fraction = 0.0005` not
    ok; with `max_fraction = 0.1` ok.
  - one pixel changed by less than `tolerance`: `differing == 0`.
  - the changed pixel inside a mask rectangle: `differing == 0`, `compared == 16 - mask area`.
  - 5×4 against 4×4: `reason == "size"`, both sizes reported, no diff written.
  - a failing compare with `diff_png` set writes a PNG of the compared size.
  - a full-size 1264×1680 synthetic pair (built in the spec, not committed) compares in under 2 s.
  - a grey 4×4 (8-bit PNG) against the same image saved as RGBA: `differing == 0` (both forced to RGB).
- `spec/emulator/golden_spec.lua` (runs the emulator): for each profile, capture the probe and
  `assert_golden("probe", profile, result)`. Plus two cases that pass `update` and `golden_dir`
  explicitly so they behave the same under the regeneration run: `check` with `update = false` and an
  empty temporary `golden_dir` errors naming the flag and the path; `check` with `update = true` and
  that `golden_dir` writes a golden and sidecar there and returns `{ updated = true }`.

## Edge cases

- Regeneration never runs as part of a plain `bin/check`: only the explicit variable writes into
  `spec/goldens/`.
- A sidecar with masks outside the image: the compare clips masks to the image and the sidecar is left
  as written.
- A capture of the wrong size (someone changed a profile) fails on size, not on pixels, so the message
  points at the profile.
- Font rendering differences between macOS versions could move antialiased edges; the tolerance and
  the 0.05 % limit absorb edge noise, not a moved element. If the probe golden flakes on this Mac, the
  task raises `tolerance` and records the measured noise in the sidecar's `notes`, not the limit.
- The diff PNG is written next to the capture under `KO_HOME` and so is removed with it on a passing
  rerun; a failing emulator spec leaves its scratch dir, so the diff survives for inspection.
