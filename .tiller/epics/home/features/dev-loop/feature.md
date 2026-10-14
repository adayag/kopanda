# Lua specs, emulator goldens and bin/check

## Summary

The project's one gate command and the two test layers everything else is built with (design §8): Busted
unit specs on KOReader's own LuaJIT under a fresh `KO_HOME`, and headless emulator goldens per device
profile. Lands first so the next feature's first test has somewhere to run.

## Behavior

- `bin/check` runs the Lua specs and luacheck and exits non-zero on any failure; Tiller's build and tests
  gates in `.tiller/tiller.yml` are wired to it by this feature.
- A spec can `require` a plugin module with KOReader's `frontend` on the path, using the rocks KOReader
  ships for its own tests (`koreader/kodev:911`, `spec/rocks` in the emulator build), with a temporary
  `KO_HOME` created and removed per run.
- An emulator run captures the home screen headless at a named profile's resolution (Colorsoft
  1264×1680, Paperwhite 1236×1648, both 300 DPI) and compares it to a committed golden with the status
  strip masked; goldens regenerate only through an explicit flag and are eyeballed before commit.
- The capture waits on a settled signal the plugin itself announces, not on KOReader internals.
- A paint-time measurement is recorded alongside the golden so later features can assert a budget.
- The emulator's own `plugins/` is checked for SimpleUI, Bookshelf and ennUI before a run and the run
  refuses, naming them, if any is enabled (design §1b, coexistence).
- Fixture books for goldens are public-domain EPUBs with known covers, pinned in the repo or by hash.

## Notes

Reuses the kodev capture recipe and the theme studio's driver pattern (`test/emulator/helpers.ts`,
`lua/patches/2-kts-capture.lua`) as references, not as code. Whether the driver is a shell script or
TypeScript is a specify-time choice; the studio epic will want to call the same capture, so the driver
should be callable from both.
