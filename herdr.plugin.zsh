# herdr.plugin.zsh - Oh My Zsh plugin for Herdr <https://herdr.dev>
#
# In any terminal this installs completions for the `herdr` CLI.
# Inside a Herdr pane (HERDR_ENV=1) it also:
#   - shows slow commands in the Herdr sidebar as working, then done
#   - sends a Herdr notification when a slow command finishes in a pane
#     you are not looking at
#   - adds the hsplit, htab, hagent, hworktree and hreload helpers
#
# Settings are documented in README.md.

typeset -g _herdr_omz_root="${0:A:h}"
typeset -g _herdr_omz_bin="${HERDR_BIN_PATH:-herdr}"

# --- Completions (any terminal) ----------------------------------------------

if (( $+commands[herdr] )) && [[ -n "$ZSH_CACHE_DIR" ]]; then
  # If the completion file doesn't exist yet, we need to autoload it and
  # bind it to `herdr`. Otherwise, compinit will have already done that.
  if [[ ! -f "$ZSH_CACHE_DIR/completions/_herdr" ]]; then
    typeset -g -A _comps
    autoload -Uz _herdr
    _comps[herdr]=_herdr
  fi

  # Regenerate in the background so a herdr upgrade is picked up next shell.
  # The temp name carries $RANDOM as well as $$ so two jobs from the same
  # shell (the plugin sourced twice) cannot collide on it, and the job is
  # fully silent so nothing lands on the terminal after the prompt.
  zmodload -F zsh/files b:zf_mv b:zf_mkdir b:zf_rm
  () {
    zf_mkdir -p "$ZSH_CACHE_DIR/completions"
    local tmp="$ZSH_CACHE_DIR/completions/_herdr.$$.$RANDOM"
    if herdr completion zsh >| "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
      zf_mv -f -- "$tmp" "$ZSH_CACHE_DIR/completions/_herdr"
    else
      zf_rm -f -- "$tmp"
    fi
  } >/dev/null 2>&1 &|
fi

# --- Everything below needs a live Herdr pane --------------------------------

[[ "$HERDR_ENV" == 1 && -n "$HERDR_PANE_ID" ]] || return 0

zmodload zsh/datetime
autoload -Uz add-zsh-hook

# Settings. Set them in .zshrc before Oh My Zsh loads, or change them later.
: ${HERDR_OMZ_THRESHOLD:=10}           # seconds before a command counts as slow
: ${HERDR_OMZ_REPORT:=true}            # show slow commands in the sidebar
: ${HERDR_OMZ_NOTIFY:=true}            # notify when a slow command finishes
: ${HERDR_OMZ_NOTIFY_FOCUSED:=false}   # notify even when this pane is focused
: ${HERDR_OMZ_DEFAULT_AGENT:=claude}   # agent kind used by hagent
: ${HERDR_OMZ_IDLE_TIMEOUT:=30}        # seconds before a finished command's idle badge auto-releases

# Commands that are never reported: agents Herdr already tracks on its own,
# and interactive programs where "finished" carries no information.
typeset -ga HERDR_OMZ_IGNORE
(( ${#HERDR_OMZ_IGNORE} )) || HERDR_OMZ_IGNORE=(
  pi claude codex gemini cursor devin agy cline omp mastracode opencode copilot
  kimi kiro droid amp grok hermes kilo qodercli maki
  vim vi nvim emacs nano less more man ssh mosh tmux screen zellij htop top btop
  lazygit tig fzf python python3 irb pry node psql mysql sqlite3 herdr
)

typeset -g  _herdr_omz_cmd=
typeset -g  _herdr_omz_label=
typeset -gF _herdr_omz_start=0
typeset -gi _herdr_omz_watcher=0
typeset -gi _herdr_omz_registered=0
typeset -g  _herdr_omz_genfile="${TMPDIR:-/tmp}/herdr-omz-release-${HERDR_PANE_ID}"

# Herdr drops a report whose --seq is not above the last one it saw for this
# pane and source, and that memory outlives the shell. A clock in microseconds
# stays monotonic across shells, so a fresh shell in a reused pane is heard.
function _herdr_omz_seq {
  REPLY=$(( EPOCHREALTIME * 1000000 ))
  REPLY=${REPLY%.*}
}

# Run herdr and ignore both its output and its failures: a hook must never
# break the prompt because the socket went away.
function _herdr_omz_call {
  "$_herdr_omz_bin" "$@" >/dev/null 2>&1
  return 0
}

# Set REPLY to the program a command line runs, skipping env assignments and
# wrappers such as sudo or time. Returns 1 when there is nothing to report.
function _herdr_omz_program {
  local -a words
  local w
  words=(${(z)1})
  for w in $words; do
    case "$w" in
      *=*) continue ;;
      sudo|doas|command|builtin|exec|nohup|time|nice|env|caffeinate) continue ;;
      -*) continue ;;
      *) REPLY="${w:t}"; return 0 ;;
    esac
  done
  return 1
}

# Set REPLY to a sidebar label Herdr accepts: lowercase, [a-z0-9_-], 32 chars.
function _herdr_omz_sanitize {
  local l="${(L)1}"
  l="${l//[^a-z0-9_-]/-}"
  [[ "$l" == [a-z]* ]] || l="shell"
  REPLY="${l[1,32]}"
}

# Set REPLY to a short human duration for a number of seconds.
function _herdr_omz_human {
  local -i s=$1
  if (( s < 60 )); then
    REPLY="${s}s"
  elif (( s < 3600 )); then
    REPLY="$(( s / 60 ))m $(( s % 60 ))s"
  else
    REPLY="$(( s / 3600 ))h $(( (s % 3600) / 60 ))m"
  fi
}

function _herdr_omz_kill_watcher {
  (( _herdr_omz_watcher )) || return 0
  # The watcher is its own process group under job control; fall back to the
  # bare pid when it is not (non-interactive shells, tests).
  kill -TERM -- -$_herdr_omz_watcher 2>/dev/null || kill -TERM $_herdr_omz_watcher 2>/dev/null
  _herdr_omz_watcher=0
}

function _herdr_omz_release {
  (( _herdr_omz_registered )) || return 0
  # Invalidates any pending idle-timeout job scheduled by _herdr_omz_precmd,
  # whether we got here from the next preexec or from a fired timeout itself.
  : >| "$_herdr_omz_genfile" 2>/dev/null
  local REPLY
  _herdr_omz_seq
  _herdr_omz_call pane release-agent "$HERDR_PANE_ID" \
    --source ohmyzsh --agent "$_herdr_omz_label" --seq $REPLY
  _herdr_omz_registered=0
}

function _herdr_omz_preexec {
  # $2 is the command with aliases expanded; $1 is the raw line, used when
  # history is off and $2 is empty.
  local cmd="${2:-$1}"
  local REPLY

  # The previous slow command's "done" badge retires once you move on.
  _herdr_omz_release

  _herdr_omz_cmd=
  _herdr_omz_start=0
  _herdr_omz_program "$cmd" || return 0
  (( ${HERDR_OMZ_IGNORE[(Ie)$REPLY]} )) && return 0

  _herdr_omz_sanitize "$REPLY"
  _herdr_omz_label="$REPLY"
  _herdr_omz_cmd="$cmd"
  _herdr_omz_start=$EPOCHREALTIME

  [[ "$HERDR_OMZ_REPORT" == true ]] || return 0

  # Wait out the threshold in the background, then report "working". precmd
  # kills this for commands that finish sooner, so quick commands never
  # flicker in the sidebar. zselect sleeps without forking a child.
  _herdr_omz_seq
  local seq=$REPLY
  local -i cs=$(( HERDR_OMZ_THRESHOLD * 100 ))
  (
    zmodload zsh/zselect 2>/dev/null && zselect -t $cs
    "$_herdr_omz_bin" pane report-agent "$HERDR_PANE_ID" \
      --source ohmyzsh --agent "$_herdr_omz_label" --state working \
      --message "$cmd" --seq $seq
  ) >/dev/null 2>&1 &!
  _herdr_omz_watcher=$!
}

function _herdr_omz_precmd {
  # Must be the first statement: $? is the finished command's status.
  local -i code=$?
  (( _herdr_omz_start )) || return 0

  local -F elapsed=$(( EPOCHREALTIME - _herdr_omz_start ))
  local cmd="$_herdr_omz_cmd" label="$_herdr_omz_label"
  local REPLY
  _herdr_omz_cmd=
  _herdr_omz_start=0
  _herdr_omz_kill_watcher

  (( elapsed >= HERDR_OMZ_THRESHOLD )) || return 0

  _herdr_omz_human ${elapsed%.*}
  local summary="exit $code, took $REPLY"

  if [[ "$HERDR_OMZ_REPORT" == true ]]; then
    # A later --seq wins, so this lands after the watcher's "working" report
    # even when the two race at the threshold boundary.
    _herdr_omz_seq
    _herdr_omz_call pane report-agent "$HERDR_PANE_ID" \
      --source ohmyzsh --agent "$label" --state idle \
      --message "$cmd ($summary)" --seq $REPLY
    _herdr_omz_registered=1

    # Auto-release the idle badge if no new command starts within
    # HERDR_OMZ_IDLE_TIMEOUT seconds, so a finished command does not linger
    # in the sidebar forever once the pane sits idle. The genfile holds this
    # report's own seq; if _herdr_omz_release ran in the meantime (a new
    # preexec, or an earlier timeout already firing), the file no longer
    # matches and this job is a no-op.
    if (( HERDR_OMZ_IDLE_TIMEOUT > 0 )); then
      local gen=$REPLY genfile=$_herdr_omz_genfile pane=$HERDR_PANE_ID
      local agentlabel=$label bin=$_herdr_omz_bin
      print -r -- "$gen" >| "$genfile" 2>/dev/null
      (
        zmodload zsh/zselect zsh/datetime 2>/dev/null
        zselect -t $(( HERDR_OMZ_IDLE_TIMEOUT * 100 ))
        local current
        current=$(<"$genfile" 2>/dev/null)
        [[ "$current" == "$gen" ]] || exit 0
        local -F now=$EPOCHREALTIME
        local -i seqv=$(( now * 1000000 ))
        "$bin" pane release-agent "$pane" \
          --source ohmyzsh --agent "$agentlabel" --seq $seqv
      ) >/dev/null 2>&1 &!
    fi
  fi

  if [[ "$HERDR_OMZ_NOTIFY" == true ]]; then
    _herdr_omz_focused && return 0
    local title="Finished: $cmd" sound=done
    if (( code != 0 )); then
      title="Failed: $cmd"
      sound=request
    fi
    _herdr_omz_call notification show "${title[1,80]}" --body "$summary" --sound $sound
  fi
  return 0
}

# True when this pane is the focused one in the Herdr UI.
function _herdr_omz_focused {
  [[ "$HERDR_OMZ_NOTIFY_FOCUSED" == true ]] && return 1
  local json
  json="$("$_herdr_omz_bin" pane current --current 2>/dev/null)" || return 1
  [[ "$json" == *'"focused":true'* ]]
}

function _herdr_omz_zshexit {
  _herdr_omz_kill_watcher
  _herdr_omz_release
}

add-zsh-hook preexec _herdr_omz_preexec
add-zsh-hook precmd  _herdr_omz_precmd
add-zsh-hook zshexit _herdr_omz_zshexit

# --- Helpers -----------------------------------------------------------------

# Set REPLY to the pane id in a herdr JSON response.
function _herdr_omz_pane_id {
  [[ "$1" =~ '"pane_id":"([^"]+)"' ]] || return 1
  REPLY="$match[1]"
}

# hsplit [right|down] [command...]
# Split the current pane keeping the working directory; run a command in it.
function hsplit {
  local direction=right REPLY out
  case "$1" in
    right|down) direction=$1; shift ;;
  esac
  out="$("$_herdr_omz_bin" pane split --current --direction $direction --cwd "$PWD" --focus)" || return 1
  (( $# )) || return 0
  _herdr_omz_pane_id "$out" || { print -u2 "hsplit: could not read the new pane id"; return 1 }
  "$_herdr_omz_bin" pane run "$REPLY" "$@" >/dev/null
}

# htab [label]
# Open a new tab in this workspace, keeping the working directory.
function htab {
  local -a args
  args=(--cwd "$PWD" --focus)
  [[ -n "$1" ]] && args+=(--label "$1")
  "$_herdr_omz_bin" tab create "${args[@]}" >/dev/null
}

# hagent NAME [KIND] [-- agent args...]
# Split right without stealing focus and start a named agent there.
function hagent {
  local name="$1" kind="$HERDR_OMZ_DEFAULT_AGENT" REPLY out
  local -a extra
  [[ -n "$name" ]] || { print -u2 "usage: hagent NAME [KIND] [-- AGENT_ARGS...]"; return 1 }
  shift
  if [[ -n "$1" && "$1" != -- ]]; then
    kind="$1"
    shift
  fi
  [[ "$1" == -- ]] && shift
  (( $# )) && extra=(-- "$@")

  out="$("$_herdr_omz_bin" pane split --current --direction right --cwd "$PWD" --no-focus)" || return 1
  _herdr_omz_pane_id "$out" || { print -u2 "hagent: could not read the new pane id"; return 1 }
  "$_herdr_omz_bin" agent start "$name" --kind "$kind" --pane "$REPLY" "${extra[@]}" >/dev/null &&
    print "hagent: $kind started as '$name' in pane $REPLY"
}

# hworktree BRANCH [BASE]
# Create a git worktree for BRANCH and open it as a Herdr workspace.
function hworktree {
  local -a args
  [[ -n "$1" ]] || { print -u2 "usage: hworktree BRANCH [BASE]"; return 1 }
  args=(--branch "$1" --cwd "$PWD" --focus)
  [[ -n "$2" ]] && args+=(--base "$2")
  "$_herdr_omz_bin" worktree create "${args[@]}" >/dev/null
}

# hreload [--dry-run]
# Reload Oh My Zsh in every pane that is sitting at an idle zsh prompt.
function hreload {
  zsh "$_herdr_omz_root/bin/reload-all" "$@"
}
