# Shared helpers for the test files. Source this first.
emulate -L zsh
setopt extended_glob

typeset -g REPO="${0:A:h:h}"
typeset -g MOCK="$REPO/tests/mocks/herdr"
typeset -gi _checks=0 _fails=0

# check NAME EXPECTED ACTUAL  - exact string equality
function check {
  (( _checks++ ))
  if [[ "$2" == "$3" ]]; then
    print "ok   - $1"
  else
    (( _fails++ ))
    print "FAIL - $1"
    print "       expected: ${(q)2}"
    print "       actual:   ${(q)3}"
  fi
}

# check_match NAME GLOB ACTUAL  - glob match against a (possibly multi-line) string
function check_match {
  (( _checks++ ))
  if [[ "$3" == ${~2} ]]; then
    print "ok   - $1"
  else
    (( _fails++ ))
    print "FAIL - $1"
    print "       pattern: ${(q)2}"
    print "       actual:  ${(q)3}"
  fi
}

# check_contains NAME SUBSTRING ACTUAL  - literal substring, no glob characters
function check_contains {
  (( _checks++ ))
  if [[ "$3" == *"$2"* ]]; then
    print "ok   - $1"
  else
    (( _fails++ ))
    print "FAIL - $1"
    print "       expected to contain: ${(q)2}"
    print "       actual:              ${(q)3}"
  fi
}

# check_lacks NAME SUBSTRING ACTUAL  - assert the literal substring is absent
function check_lacks {
  (( _checks++ ))
  if [[ "$3" != *"$2"* ]]; then
    print "ok   - $1"
  else
    (( _fails++ ))
    print "FAIL - $1 (unexpected match)"
    print "       must not contain: ${(q)2}"
    print "       actual:           ${(q)3}"
  fi
}

# check_absent NAME GLOB ACTUAL  - assert the glob does NOT match
function check_absent {
  (( _checks++ ))
  if [[ "$3" != ${~2} ]]; then
    print "ok   - $1"
  else
    (( _fails++ ))
    print "FAIL - $1 (unexpected match)"
    print "       pattern: ${(q)2}"
    print "       actual:  ${(q)3}"
  fi
}

# Fresh sandbox: mock on PATH as `herdr`, empty log, fixture dir, cache dir.
function setup_sandbox {
  typeset -g SB
  SB="$(mktemp -d "${TMPDIR:-/tmp}/herdr-omz.XXXXXX")"
  SB="$(cd "$SB" && pwd -P)"   # $TMPDIR may carry a trailing slash; cd normalises
  mkdir -p "$SB/bin" "$SB/fixtures" "$SB/cache/completions"
  ln -s "$MOCK" "$SB/bin/herdr"
  export HERDR_MOCK_DIR="$SB/fixtures"
  export HERDR_MOCK_LOG="$SB/herdr.log"
  export HERDR_BIN_PATH="$MOCK"
  export ZSH_CACHE_DIR="$SB/cache"
  export PATH="$SB/bin:$PATH"
  : >"$HERDR_MOCK_LOG"
}

function teardown_sandbox {
  [[ -n "$SB" && -d "$SB" ]] && rm -rf "$SB"
}

# Mock calls so far, minus the background completion job, which lands
# whenever it likes.
function mock_log {
  grep -v '^completion ' "$HERDR_MOCK_LOG" 2>/dev/null
}

# Run zsh code in a fresh `zsh -f` that has sourced the plugin. Stdout and
# stderr come back together. The log is cleared first.
function run_case {
  : >"$HERDR_MOCK_LOG"
  zsh -f -c "
    _wait_log() { local i; for i in {1..50}; do grep -q -- \"\$1\" \"\$HERDR_MOCK_LOG\" 2>/dev/null && return 0; sleep 0.1; done; return 1 }
    source '$REPO/herdr.plugin.zsh'
    $1
  " 2>&1
}

function finish {
  print "# $_checks checks, $_fails failed"
  teardown_sandbox
  (( _fails == 0 ))
}
