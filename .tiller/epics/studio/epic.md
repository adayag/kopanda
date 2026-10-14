# Edit, preview and push from the Mac

Stage 2 of `design/2026-10-13-kopanda-design.md` §4 and §6. The owner's switch-over gate (§1b): once
this epic is done the Kindle moves from SimpleUI to KoPanda.

## Intent

A local web app that edits the same settings the device menus edit, from the same schema, shows the
result rendered by the real emulator for each device profile and look, and gets it onto the Kindle over
Wi‑Fi with a staged apply and rollback.

## Scope

The studio on the stack the theme studio used (TypeScript, Node, Express, React, Vite, Vitest): device
profiles (the owner's Colorsoft, the household member's Paperwhite), the schema contract (JSON dump,
equality test), the generated form with its layout and launcher editors, the emulator preview, and the
device push with the plugin-side Studio menu.

Out: a look editor (after the MVP, §1b), pulling settings back from a device, anything the plugin
doesn't already do.

## Definition of done

Every feature under this epic is done: the owner edits the Colorsoft profile in the form, sees both looks
rendered at both profiles, pushes to the Kindle, restarts, and the home screen is KoPanda's; a bad bundle
rolls back on its own. `bin/check` covers the studio's typecheck, lint and tests.

## Dependencies

`studio-shell` needs the schema (`home/looks-and-schema`); `preview` needs the capture driver
(`home/dev-loop`) and a home to render (`home/home-layout`); `device-push` needs the plugin
(`home/plugin-shell`). Recorded as `depends_on` edges.
