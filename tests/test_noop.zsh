#!/usr/bin/env zsh
# Outside a Herdr pane the plugin installs completions and nothing else.
source "${0:A:h}/lib.zsh"
setup_sandbox

out="$(env -u HERDR_ENV -u HERDR_PANE_ID zsh -f -c "
  source '$REPO/herdr.plugin.zsh'
  print -r -- \"preexec=\${preexec_functions[*]}\"
  print -r -- \"precmd=\${precmd_functions[*]}\"
  print -r -- \"helpers=\${+functions[hsplit]}\${+functions[htab]}\${+functions[hagent]}\${+functions[hworktree]}\${+functions[hreload]}\"
  print -r -- \"comps=\${_comps[herdr]}\"
" 2>&1)"

check        "no preexec hook outside herdr"   "preexec="  "${${(f)out}[1]}"
check        "no precmd hook outside herdr"    "precmd="   "${${(f)out}[2]}"
check        "no helper functions outside herdr" "helpers=00000" "${${(f)out}[3]}"
check        "completion is bound to herdr"    "comps=_herdr" "${${(f)out}[4]}"

# The completion file is generated in the background; give it a moment.
for i in {1..30}; do [[ -s "$ZSH_CACHE_DIR/completions/_herdr" ]] && break; sleep 0.1; done
check_contains "completion file written to cache" '#compdef herdr' "$(<"$ZSH_CACHE_DIR/completions/_herdr")"

# HERDR_ENV set but no pane id: still a no-op.
out="$(env -u HERDR_PANE_ID HERDR_ENV=1 zsh -f -c "
  source '$REPO/herdr.plugin.zsh'
  print -r -- \"\${+functions[hsplit]}\"
" 2>&1)"
check "no helpers without a pane id" "0" "$out"

# Sourcing twice in one shell must not add duplicate hooks.
out="$(env HERDR_ENV=1 HERDR_PANE_ID=w1:p1 zsh -f -c "
  source '$REPO/herdr.plugin.zsh'
  source '$REPO/herdr.plugin.zsh'
  print -r -- \"\${#preexec_functions} \${#precmd_functions}\"
" 2>&1)"
check "hooks registered once when sourced twice" "1 1" "$out"

finish
