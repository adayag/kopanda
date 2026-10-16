#!/usr/bin/env bash
# A fake bin/layout-fit refusing to run, as the real one does without a luajit.
printf '%s\n' "bin/layout-fit: no luajit at /nonexistent/luajit" \
    "    set KOPANDA_EMULATOR to the emulator's koreader directory" >&2
exit 2
