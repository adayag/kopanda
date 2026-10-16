#!/usr/bin/env bash
# A fake bin/layout-fit failing after KOReader's library-loading chatter, as the real one does
# for a row list the plugin's validator refuses.
cat > /dev/null
printf '%s\n' "has monolibtic? yes" "ffi.load: libs/libkoreader-lfs.dylib" \
    "bin/layout-fit: row list 2 is not a layout the plugin accepts" >&2
exit 1
