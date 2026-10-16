#!/usr/bin/env bash
# A fake bin/layout-fit that never answers in time. Its sleep is a child process, as the real
# script's luajit is, holding the output open; its pid goes to $KOPANDA_FAKE_FIT_DIR/sleep-pid.
sleep 10 &
echo $! > "$KOPANDA_FAKE_FIT_DIR/sleep-pid"
wait
echo '{"overflow":[0,0],"screen":{"height":1680,"width":1264}}'
