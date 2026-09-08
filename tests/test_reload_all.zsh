#!/usr/bin/env zsh
# bin/reload-all reloads exactly the panes sitting at an idle zsh prompt.
source "${0:A:h}/lib.zsh"
setup_sandbox
F="$HERDR_MOCK_DIR"

# w1:p1 agent running, w1:p2 idle zsh, w1:p3 vim in the foreground,
# w2:p1 idle bash, w2:p2 idle zsh (Linux-style process info).
print '{"result":{"panes":[{"agent":"claude","agent_status":"idle","pane_id":"w1:p1","scroll":{"offset_from_bottom":0}},{"agent_status":"unknown","pane_id":"w1:p2"},{"pane_id":"w1:p3"},{"pane_id":"w2:p1"},{"pane_id":"w2:p2"}],"type":"pane_list"}}' >"$F/panes.json"
print '{"result":{"pane":{"agent":"claude","agent_session":{"agent":"claude","kind":"id"},"pane_id":"w1:p1"}}}' >"$F/pane_w1-p1.json"
print '{"result":{"pane":{"agent_status":"unknown","pane_id":"w1:p2"}}}' >"$F/pane_w1-p2.json"
print '{"result":{"pane":{"pane_id":"w1:p3"}}}' >"$F/pane_w1-p3.json"
print '{"result":{"pane":{"pane_id":"w2:p1"}}}' >"$F/pane_w2-p1.json"
print '{"result":{"pane":{"pane_id":"w2:p2"}}}' >"$F/pane_w2-p2.json"
print '{"result":{"process_info":{"foreground_process_group_id":100,"foreground_processes":[{"argv":["-zsh"],"argv0":"zsh","cmdline":"-zsh","name":"zsh","pid":100}],"pane_id":"w1:p2","shell_pid":100}}}' >"$F/procinfo_w1-p2.json"
print '{"result":{"process_info":{"foreground_process_group_id":201,"foreground_processes":[{"argv":["vim","x"],"argv0":"vim","cmdline":"vim x","name":"vim","pid":201}],"pane_id":"w1:p3","shell_pid":200}}}' >"$F/procinfo_w1-p3.json"
print '{"result":{"process_info":{"foreground_process_group_id":300,"foreground_processes":[{"argv":["-bash"],"argv0":"bash","cmdline":"-bash","name":"bash","pid":300}],"pane_id":"w2:p1","shell_pid":300}}}' >"$F/procinfo_w2-p1.json"
print '{"result":{"process_info":{"foreground_process_group_id":400,"foreground_processes":[{"argv":["zsh"],"argv0":"zsh","cmdline":"zsh","name":"zsh","pid":400}],"pane_id":"w2:p2","shell_pid":400}}}' >"$F/procinfo_w2-p2.json"

: >"$HERDR_MOCK_LOG"
out="$(zsh "$REPO/bin/reload-all" 2>&1)"; rc=$?
log="$(mock_log)"
check "reload-all exits 0" "0" "$rc"
check "only idle zsh panes receive omz reload" \
  "pane run w1:p2 omz reload
pane run w2:p2 omz reload" "$(print -r -- "$log" | grep '^pane run')"
check_contains "agent pane is skipped and explained" 'skipped  w1:p1 (agent running)' "$out"
check_contains "busy pane is skipped and explained" 'skipped  w1:p3 (busy)' "$out"
check_contains "bash pane is skipped and explained" 'skipped  w2:p1 (not zsh)' "$out"
check_contains "summary line" '2 shells reloaded, 3 skipped' "$out"
check_contains "toast summarises the run" 'notification show Oh My Zsh reloaded --body 2 shells reloaded, 3 skipped --sound none' "$log"

: >"$HERDR_MOCK_LOG"
out="$(zsh "$REPO/bin/reload-all" --dry-run 2>&1)"
log="$(mock_log)"
check_lacks "dry run sends nothing" 'pane run' "$log"
check_lacks "dry run shows no toast" 'notification show' "$log"
check_contains "dry run lists what it would do" 'reloaded w1:p2 (dry run)' "$out"

# A pane whose queries fail is skipped, not fatal.
rm "$F/procinfo_w1-p2.json"
out="$(zsh "$REPO/bin/reload-all" 2>&1)"; rc=$?
check "still exits 0 with an unreadable pane" "0" "$rc"
check_contains "pane without process info is skipped as busy" 'skipped  w1:p2 (busy)' "$out"

# Unreachable herdr fails loudly.
out="$(HERDR_BIN_PATH=/nonexistent/herdr zsh "$REPO/bin/reload-all" 2>&1)"; rc=$?
check "missing binary exits 1" "1" "$rc"
check_contains "missing binary is explained" 'herdr binary not found' "$out"

finish
