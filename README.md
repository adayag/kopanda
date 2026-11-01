# KoPanda

KoPanda is one person's own interface for [KOReader](https://koreader.rocks) e-readers: a plugin that replaces the shell (a home screen over the file browser, a navigation bar, a library with search, series, author and subject views, sheets and quick settings), and a desktop studio that edits the same settings the plugin's on-device menus edit, from one schema.

The repo is public so the work can be read. The plugin is built for its owner's devices (a Kindle Colorsoft and a Paperwhite) and is not supported for anyone else. There is no issue tracker and no help with installs.

## What's here

| Path | What it is |
|---|---|
| `kopanda.koplugin/` | The plugin: Lua on KOReader's LuaJIT. `schema.lua` is the only list of settings; `HOOKS.md` lists every KOReader internal it reads or patches. |
| `kopanda.koplugin/widgets/` | The home's widgets: date, clock, weather, quote, featured book, launcher, and the reading insights (reading, streak, forecast, hours, records). |
| `kopanda.koplugin/looks/` | The looks, each a token table inheriting from `base.lua`: Diner (the default), Editorial, Frosted. |
| `studio/` | The studio: TypeScript on Node 22, Express, React and Vite. A form over the schema, a preview rendered by the emulator, and a push of a profile's settings and the working-tree plugin to a device over the LAN. |
| `spec/` | Busted unit specs and emulator capture specs, with a fixture library of three public-domain EPUBs. |
| `bin/` | `check` (the test gate), `schema-json`, `catalog-json`, `layout-fit`, `preview`, `bundle`. |
| `.tiller/` | The project's specs, decisions and gates. |

## How it runs

- **On a device:** each push to `main` that changes the plugin publishes a GitHub release with `kopanda.koplugin.zip` and a manifest. The device installs it from Tools › KoPanda › Studio › Check for update.
- **In the emulator:** the KOReader emulator is pinned to one build and lives outside this repo (see `.env.example` for `KOPANDA_EMULATOR`). `bin/check` runs luacheck, the studio's checks, every unit spec, then every emulator spec under a fresh `KO_HOME`.
- **The studio:** `npm ci --prefix studio`, then `npm --prefix studio run dev`. It is a development tool, not a service: it runs on the owner's Mac and talks to a device on the same network.

## Installing from a local checkout

The plugin is the `kopanda.koplugin/` folder as it is; nothing is compiled.

- **Over Wi-Fi, through the studio.** On the Mac, build the studio once and start it on the LAN:

  ```
  npm ci --prefix studio
  npm --prefix studio run build
  KOPANDA_STUDIO_HOST=0.0.0.0 npm --prefix studio start
  ```

  Profiles are created at `~/.kopanda/profiles/` on the first start. On the device, Tools › KoPanda › Studio: set Address to the Mac's `host:4490`, pick a Profile, then Pull and take the restart it offers. The pull replaces the plugin on the device with the working tree and its settings with the profile's.
- **Over USB.** Copy `kopanda.koplugin/` into the device's `koreader/plugins/`. A Kindle is MTP-only and shows up only from its stock home screen, so exit KOReader first and finish the copy in one session. Restart KOReader.
- **In the emulator.** Copy `kopanda.koplugin/` into `<KO_HOME>/plugins/` and start the emulator with that `KO_HOME`. Don't also leave a copy in the emulator's own `plugins/`: a plugin present in both loads twice, and `bin/check` relies on that folder being empty of it.

## Reading the references

KoPanda is written from scratch. SimpleUI, ennUI and ZenOS were read for how they hook KOReader; MIT-licensed pieces of SimpleUI may be lifted with their notice, the others are read only. KOReader itself is AGPL-3.0.
