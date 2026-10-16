# The preview endpoint runs bin/preview one render at a time

## Approach

The server half of the preview. Starts after `studio/preview/preview-script` and `studio/studio-shell`;
read the built `studio/src/server/` first (the app factory, the profiles router and its 404 shape,
`studio-shell/feature.md:97-103`), and `studio/src/server/layout-fit.ts` if `settings-form` has built it,
for the command lookup and the `execFile` style to share.

1. **`studio/src/server/preview.ts`:**
   - `renderPreview({ command, width, height, dpi, color, look, night, settingsPath, timeoutMs = 150000 })`
     → `Promise<Buffer>`, or rejects with `PreviewError { status, error, log }`. It makes a temporary
     directory (`fs.mkdtemp` under `os.tmpdir()`), spawns `command` with `[width, height, dpi, color ?
     "color" : "grey", look, night ? "night" : "day", <tmp>/preview.png, settingsPath?]`, `detached:
     true` so the child leads its own process group, and collects stderr. Exit 0: read the PNG, parse
     stdout's JSON line (a parse failure is a 502 naming it), resolve. Exit 2: `503`. Any other exit or
     signal: `502`. `error` is stderr's first non-empty line, which `bin/preview` keeps to the failure's
     message (preview-script, step 2), or "bin/preview exited <n>" when there is none; `log` the
     remaining lines, the last 40. Past `timeoutMs`: `process.kill(-pid, "SIGTERM")`, then `SIGKILL`
     to the group 5 s later if it is still there, and `502` "No render within <timeoutMs in s> s". The
     temporary directory is removed in every case.
   - `command` defaults to the repo's `bin/preview`, resolved from `import.meta.url` as `layout-fit.ts`
     resolves `bin/layout-fit` (`settings-form/tasks/layout-fit/task.md:31-36`); the environment is the
     server's.
   - `createPreviewQueue()` → `{ run(job, signal) }`: one job at a time, in arrival order. A job whose
     `signal` aborts while it waits is removed and rejects with an abort; one that has started runs to
     its end.
2. **`studio/src/server/routes/preview.ts`:** `POST /api/profiles/:id/preview` on the profiles router.
   The body must be `{ look, night }` with `look` among `schema.keys`' `look` entry's choice values
   (`studio/src/schema.json`, built by `studio/studio-shell`, `studio-shell/feature.md:107-115`) and
   `night` a boolean, else `400 { error }`. The profile from the shell's loader (`404` for an unknown or invalid id). `settingsPath` is `settings_path` when `fs.stat` finds a
   file there. An `AbortController` aborts on the request's `close` before the answer is sent. Success:
   `200`, `Content-Type: image/png`, `Cache-Control: no-store`, the buffer. `PreviewError`: its status
   with `{ error, log }`. The command and the queue are injectable through `createApp`'s options, as
   `layout-fit`'s command is.

## Surfaces

- `studio/src/server/preview.ts`, `studio/src/server/routes/preview.ts` (new)
- `studio/src/server/app.ts` (mount, options)
- `studio/test/server/preview.test.ts` (new), with `studio/test/fixtures/fake-preview` (a small Node or
  shell script the tests point `command` at)

## Tests

`studio/test/server/preview.test.ts` (C5), Vitest with supertest, written first and run failing. The fake
command reads its arguments, records them to a file the test names through an environment variable, and
behaves by a mode variable: write a small PNG and the JSON line; exit 1 with stderr of 45 lines; exit 2
with one line; sleep past a short `timeoutMs` (the test passes 300 ms) after spawning a child that writes
its pid to a file; or print junk on stdout.

- A Colorsoft profile with no settings file: the arguments are `1264 1680 300 color diner day <png>`, no
  eighth; with a settings file, its absolute path last; a grey profile passes `grey`; `night: true`
  passes `night`. The answer is 200, `image/png`, `no-store`, the PNG's bytes; the temporary directory is
  gone.
- `{ look: "classic" }`, `{ look: "diner", night: "yes" }` and no body: 400. `/api/profiles/nope/preview`:
  404.
- Exit 1 with 45 lines: 502, `error` the first line, `log` lines 6–45 (the last 40 after it). Exit 2:
  503. Junk stdout: 502 naming the parse.
- The sleeper: 502 "No render within 0.3 s", and its child's pid
  is no longer alive afterwards (`process.kill(pid, 0)` throws).
- The queue: two requests sent together run one after the other (the fake records start and end times;
  the second starts after the first ends); a third request aborted while queued never starts (no record).

## Edge cases

- **The message for the timeout** is built from `timeoutMs`, so the test's 300 ms reads "No render within
  0.3 s"; the 150 s wording is the default's.
- **A client that leaves mid-render** gets nothing; the render finishes and its PNG is dropped with the
  temporary directory.
- **Two studio tabs** share the server's queue, so the emulator never runs twice at once.
- **`process.kill(-pid)`** needs the child to lead its group (`detached: true`); without it the
  emulator `bin/preview` started would outlive the kill. The test proves the group dies.
- **Loopback only:** the route adds no listener; the server still binds to `127.0.0.1`
  (`studio-shell/feature.md:41-42`).
