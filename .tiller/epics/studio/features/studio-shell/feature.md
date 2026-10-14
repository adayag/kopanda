# Studio app, device profiles and the schema contract

## Summary

The studio's skeleton: server and UI, device profiles with a settings file each, and the contract with
the plugin, the schema as JSON (design §3, §6).

## Behavior

- `npm run dev` serves the UI with the API proxied; `npm start` serves a build. Config is env vars with
  one prefix and defaults, every one listed in `.env.example`.
- A device profile names a device (Colorsoft, Paperwhite), its resolution and DPI, whether it has colour,
  and owns one settings file in the plugin's format. Profiles are files under a configured directory;
  a person is a profile (design §1b).
- The schema JSON is produced from `schema.lua` by running KOReader's LuaJIT at build time; a test
  asserts the checked-in JSON equals a fresh dump, so the form and the device menus cannot drift.
- `bin/check` gains the studio's typecheck, lint and tests.
- The first screen lists profiles and opens one.

## Notes

The theme studio's `src/server/config.ts`, `lan-guard.ts` and its Express and Vite setup are the
reference shape; copy what fits, it's the owner's code. Whether profiles live in the repo or beside it is
a specify-time choice.
