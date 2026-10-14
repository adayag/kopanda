# Emulator preview per profile and look

## Summary

The studio shows the real thing: the home screen rendered headless by the emulator for the open profile,
in both looks, re-rendered when settings change (design §6 Preview).

## Behavior

- The server materialises the profile's settings into a scratch `KO_HOME`, with the plugin from the
  working tree, and runs the capture from `home/dev-loop` at the profile's resolution.
- The UI shows the render beside the form, with its profile and look named, a status line (rendering,
  rendered in n s, stale, failed with the last log lines), and a re-render button; on-change
  re-rendering debounces.
- Both looks can be shown side by side for the same settings.
- Night mode can be toggled for the preview.
- A test proves a settings change produces a different render and that a failed render keeps the last
  good image.

## Notes

The theme studio's preview states (rendering, stale, failed) carry over from its direction doc. Render
time is whatever the emulator takes (about ten seconds today); a faster path is not this feature.
