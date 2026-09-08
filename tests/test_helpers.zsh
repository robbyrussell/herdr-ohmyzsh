#!/usr/bin/env zsh
# hsplit, htab, hagent, hworktree and hreload issue the expected CLI calls.
source "${0:A:h}/lib.zsh"
setup_sandbox
export HERDR_ENV=1 HERDR_PANE_ID=w1:p1
cwd="$SB"

run_case "cd '$cwd'; hsplit" >/dev/null
check "hsplit splits right, keeps cwd, focuses" \
  "pane split --current --direction right --cwd $cwd --focus" "$(mock_log)"

run_case "cd '$cwd'; hsplit down htop -d 5" >/dev/null
check "hsplit down runs the command in the new pane" \
  "pane split --current --direction down --cwd $cwd --focus
pane run w1:p9 htop -d 5" "$(mock_log)"

run_case "cd '$cwd'; htab" >/dev/null
check "htab keeps cwd" "tab create --cwd $cwd --focus" "$(mock_log)"

run_case "cd '$cwd'; htab 'Server logs'" >/dev/null
check "htab passes a label" "tab create --cwd $cwd --focus --label Server logs" "$(mock_log)"

out="$(run_case "cd '$cwd'; hagent reviewer")"
check "hagent splits without focus, then starts the default agent" \
  "pane split --current --direction right --cwd $cwd --no-focus
agent start reviewer --kind claude --pane w1:p9" "$(mock_log)"
check "hagent confirms" "hagent: claude started as 'reviewer' in pane w1:p9" "$out"

run_case "cd '$cwd'; hagent rev codex -- --model gpt-5" >/dev/null
check_match "hagent passes kind and native agent args" \
  "*agent start rev --kind codex --pane w1:p9 -- --model gpt-5" "$(mock_log)"

HERDR_OMZ_DEFAULT_AGENT=codex run_case "cd '$cwd'; hagent rev" >/dev/null
check_match "hagent honours HERDR_OMZ_DEFAULT_AGENT" "*--kind codex --pane w1:p9" "$(mock_log)"

out="$(run_case 'hagent; print "rc=$?"')"
check_contains "hagent without a name prints usage" 'usage: hagent' "$out"
check_contains "hagent without a name fails" 'rc=1' "$out"

run_case "cd '$cwd'; hworktree feature/login" >/dev/null
check "hworktree creates and focuses the worktree" \
  "worktree create --branch feature/login --cwd $cwd --focus" "$(mock_log)"

run_case "cd '$cwd'; hworktree feature/login main" >/dev/null
check "hworktree passes the base ref" \
  "worktree create --branch feature/login --cwd $cwd --focus --base main" "$(mock_log)"

out="$(run_case 'hreload --dry-run')"
check_contains "hreload runs bin/reload-all" "pane list" "$(mock_log)"
check_contains "hreload --dry-run reports without sending" "dry run: 0 shells reloaded, 0 skipped" "$out"

finish
