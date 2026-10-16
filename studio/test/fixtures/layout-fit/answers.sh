#!/usr/bin/env bash
# A fake bin/layout-fit: records its arguments and stdin under $KOPANDA_FAKE_FIT_DIR and answers
# as the real one does, the two row lists counting 0 and 1.
printf '%s\n' "$@" > "$KOPANDA_FAKE_FIT_DIR/args"
cat > "$KOPANDA_FAKE_FIT_DIR/stdin"
echo "has monolibtic? yes" >&2
echo '{"overflow":[0,1],"screen":{"height":1680,"width":1264}}'
