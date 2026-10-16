# The preview pane beside the form, with both looks, night and its states

## Approach

The UI half. Starts after `studio/preview/preview-api` and after `studio/settings-form` has built the form
and both editors; read the built `ProfileScreen.tsx`, `App.tsx`, `api.ts` and the way the form and the
editors send their `PUT`s first (`settings-form/tasks/form/task.md`, steps 1 and 5).

1. **`api.ts`** gains `fetchPreview(id, { look, night }, signal)` → `Blob`, throwing `PreviewError {
   status, error, log }` from the JSON body on a non-200 answer (`0` and the message when the server is
   unreachable).
2. **The write signal.** `ProfileScreen.tsx` keeps `revision`, a counter it bumps when any `putSetting`
   the form or an editor sends succeeds. Thread one callback through the single path those `PUT`s share;
   if the built code has more than one path, wrap `putSetting` once in the profile screen and hand the
   wrapper down, rather than bumping in each control.
3. **`studio/src/ui/preview/usePreviewFrames.ts`**: state for the open profile, keyed by frame (`look` ×
   `night`). Each frame: `image` (blob URL of the last good render), `imageRevision` (the revision its
   request started at), `status` (`idle`, `waiting`, `rendering`, `failed`), `error`, `log`, `elapsed`.
   - Inputs: the profile id, the shown frames, `revision`. Stale is `image !== null && imageRevision <
     revision`.
   - Each frame also keeps `requestedRevision`, the revision of its last request. A shown frame with no
     image, not rendering, and `requestedRevision < revision` (or never requested) renders at once; so a
     failed first render waits for a landed write, Re-render or being shown again, and a missing
     emulator costs one request, not a loop.
   - A change of `revision` starts (or restarts) one 1.5 s timer; when it fires, each shown frame that is
     stale renders, or, if rendering, is marked to render again when its render ends. A frame whose
     render ends while the timer still runs waits for the timer. A shown frame becoming visible while
     stale renders at once.
   - `rerender()` renders every shown frame now.
   - A render records `revision` at its start; success replaces `image` (revoking the old URL) and
     `elapsed` (`performance.now()` from the request); failure keeps `image` and sets `error` and `log`.
   - Everything aborts and every URL is revoked on unmount or a profile change. The timer is the hook's
     only timer, cleared on the same.
4. **`studio/src/ui/preview/PreviewPane.tsx`** in `ProfileScreen.tsx` beside the form region, on every
   profile route. Header: name, `<device> · <width>×<height>`, Both looks and Night toggles, Re-render
   (disabled while any shown frame renders). Frames: off, `values.look`'s; on, the schema's `look`
   choices in order. Under each, the look's choice label from the schema and "· night" when on, then the
   status line; over the image, a "stale" badge when stale. The image at the profile's aspect ratio
   (`width / height` from the profile), scaled to the column; white frame, no chrome.
   - Status: rendering "Rendering in the emulator…", the previous image at about a third opacity;
     waiting "Settings changed · re-rendering in 1.5 s"; idle with an image "Rendered in <n> s" (one
     decimal); failed: an amber panel with `error`, "Showing the last good render." when an image exists
     else "No earlier render to show.", and `log` in mono.
5. **Styles** in the shell's stylesheet: the pane's column beside the form, two frames splitting it with
   Both looks on.

## Surfaces

- `studio/src/ui/api.ts`, `studio/src/ui/ProfileScreen.tsx`
- `studio/src/ui/preview/usePreviewFrames.ts`, `studio/src/ui/preview/PreviewPane.tsx` (new)
- `studio/src/ui/styles.css`
- `studio/test/ui/preview.test.tsx` (new)

## Tests

`studio/test/ui/preview.test.tsx` (C6), jsdom with Vitest's fake timers and `fetch` stubbed per case
(preview answers as blobs or `{ error, log }`, settings answers as the settings API's shape), written first
and run failing:

- Opening a profile whose `values.look` is `editorial` renders one Editorial day frame at once, shows
  "Rendering in the emulator…", then "Rendered in <n> s" with the image.
- Writing `look = diner` through the form moves the single frame to Diner, which renders.
- A landed write marks the image stale (badge shown, "Settings changed · re-rendering in 1.5 s"); no
  request before 1.5 s; a second write at 1.0 s pushes the request to 2.5 s; exactly one request follows.
- A write landing while a frame renders, both orders: the render ends at 1.0 s, so the frame (still
  stale) renders at 1.5 s; the render ends at 3.0 s, after the pause, so the frame renders again at
  3.0 s. Each case makes exactly one more request.
- A 502 on the first render makes exactly one request, however long the timers run, until Re-render.
- Both looks: two frames, Diner then Editorial, each requested with its look; Night: two night
  requests, labels "· night"; Night off again shows the day images kept, with no new request when no
  write landed since.
- Re-render requests every shown frame at once and is disabled until they end.
- A 502 with `{ error, log }` after a good render: the image stays, the amber panel shows the error,
  "Showing the last good render." and the log lines; a 502 on the first render shows "No earlier render to
  show." and no image.
- Unmount aborts the in-flight request (the stub sees the abort) and revokes the URLs
  (`URL.revokeObjectURL` spied).

Then C7 (`npm --prefix studio run check`) and the owner's C8 walk-through.

## Edge cases

- **A write that fails** (the form's 400 or 409) bumps nothing: only a landed write changes the file.
- **A look outside the schema's choices** stored on disk reads as the default
  (`settings-form/feature.md:121-122`), so `values.look` is always a choice.
- **An unreadable or read-only settings file** still previews: the image is what the plugin makes of the
  file, the form says why it can't write.
- **Hidden frames** never request, so Both looks off costs one render a change.
- **A reload** starts with no images; the frames render at once.
