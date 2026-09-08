#!/usr/bin/env zsh
# preexec/precmd behaviour inside a Herdr pane, against the mock CLI.
source "${0:A:h}/lib.zsh"
setup_sandbox
export HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_OMZ_THRESHOLD=0

# --- a slow, successful command --------------------------------------------
run_case '
  _herdr_omz_preexec "make test" "make test"
  _wait_log -- "--state working" || print "watcher never reported"
  true; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check_contains "watcher reports working with the program as label" 'pane report-agent w1:p1 --source ohmyzsh --agent make --state working --message make test --seq ' "$log"
check_contains "precmd reports idle with exit code and duration" 'pane report-agent w1:p1 --source ohmyzsh --agent make --state idle --message make test (exit 0, took 0s) --seq ' "$log"
check_contains "precmd asks whether the pane is focused" 'pane current --current' "$log"
check_contains "finished notification with done sound" 'notification show Finished: make test --body exit 0, took 0s --sound done' "$log"

# --- a slow, failing command -------------------------------------------------
run_case '
  _herdr_omz_preexec "rspec spec/models" "rspec spec/models"
  _wait_log -- "--state working"
  false; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check_contains "failed notification uses the request sound" 'notification show Failed: rspec spec/models --body exit 1, took 0s --sound request' "$log"
check_contains "idle report carries the non-zero exit" '--state idle --message rspec spec/models (exit 1, took 0s)' "$log"

# --- the next command retires the done badge ---------------------------------
run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
  _herdr_omz_preexec "ls" "ls"
' >/dev/null
log="$(mock_log)"
check_contains "release-agent sent when the next command starts" 'pane release-agent w1:p1 --source ohmyzsh --agent make --seq ' "$log"
seqs=(${(f)"$(print -r -- "$log" | grep -o -- '--seq [0-9]*' | cut -d' ' -f2)"})
check "working, idle and release carry strictly increasing seqs" "3 yes" \
  "${#seqs} $( (( seqs[1] < seqs[2] && seqs[2] < seqs[3] )) && print yes || print no)"
check_match "seq is a microsecond clock, not a per-shell counter" '[0-9](#c16,)' "$seqs[1]"

# --- quick commands never reach herdr ----------------------------------------
HERDR_OMZ_THRESHOLD=1 run_case '
  _herdr_omz_preexec "ls -la" "ls -la"
  true; _herdr_omz_precmd
  sleep 1.5
' >/dev/null
log="$(mock_log)"
check "no calls at all for a quick command" "" "$log"

# --- ignored programs ---------------------------------------------------------
run_case '
  _herdr_omz_preexec "claude --resume" "claude --resume"
  _herdr_omz_preexec "vim README.md" "vim README.md"
  sleep 0.3
  true; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check "agents and editors are never reported" "" "$log"

HERDR_OMZ_IGNORE="bundle" run_case '
  HERDR_OMZ_IGNORE=(bundle)
  _herdr_omz_preexec "bundle exec rspec" "bundle exec rspec"
  sleep 0.3
  true; _herdr_omz_precmd
' >/dev/null
check "user-supplied ignore list is honoured" "" "$(mock_log)"

# --- wrappers, env assignments and paths are skipped when picking the label ---
run_case '
  _herdr_omz_preexec "sudo -E RAILS_ENV=test ./bin/rails test" "sudo -E RAILS_ENV=test ./bin/rails test"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
' >/dev/null
check_contains "label is the real program name" '--agent rails --state working' "$(mock_log)"

run_case '
  _herdr_omz_preexec "My_Weird.Tool@2 run" "My_Weird.Tool@2 run"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
' >/dev/null
check_contains "label is lowercased and sanitised" '--agent my_weird-tool-2 --state working' "$(mock_log)"

# --- alias-expanded command ($2) wins over the raw line ($1) -----------------
run_case '
  _herdr_omz_preexec "cc" "claude --continue"
  sleep 0.3
  true; _herdr_omz_precmd
' >/dev/null
check "alias expanding to an agent is ignored" "" "$(mock_log)"

# --- focused pane: report but stay quiet ------------------------------------
print '{"result":{"pane":{"pane_id":"w1:p1","focused":true}}}' >"$HERDR_MOCK_DIR/current.json"
run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check_contains "focused pane still gets the idle report" '--state idle' "$log"
check_lacks "focused pane gets no notification" 'notification show' "$log"

HERDR_OMZ_NOTIFY_FOCUSED=true run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
' >/dev/null
check_contains "HERDR_OMZ_NOTIFY_FOCUSED forces the notification" 'notification show Finished: make' "$(mock_log)"
rm -f "$HERDR_MOCK_DIR/current.json"

# --- feature toggles ----------------------------------------------------------
HERDR_OMZ_REPORT=false run_case '
  _herdr_omz_preexec "make" "make"
  sleep 0.3
  true; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check_lacks "HERDR_OMZ_REPORT=false sends no agent reports" 'report-agent' "$log"
check_contains "HERDR_OMZ_REPORT=false still notifies" 'notification show Finished: make' "$log"

HERDR_OMZ_NOTIFY=false run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
' >/dev/null
log="$(mock_log)"
check_contains "HERDR_OMZ_NOTIFY=false still reports" '--state idle' "$log"
check_lacks "HERDR_OMZ_NOTIFY=false sends no toast" 'notification show' "$log"

# --- a dead socket must not break the prompt ---------------------------------
HERDR_MOCK_FAIL=1 run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd; print "prompt survived: $?"
' | tail -1 | read out
check "hooks swallow herdr failures" "prompt survived: 0" "$out"

# --- shell exit releases a registered badge ----------------------------------
run_case '
  _herdr_omz_preexec "make" "make"
  _wait_log -- "--state working"
  true; _herdr_omz_precmd
  _herdr_omz_zshexit
' >/dev/null
check_contains "zshexit releases the agent" 'pane release-agent w1:p1 --source ohmyzsh --agent make' "$(mock_log)"

finish
