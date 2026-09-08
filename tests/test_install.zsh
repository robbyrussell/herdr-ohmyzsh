#!/usr/bin/env zsh
# bin/install-zsh-plugin links the repo into $ZSH_CUSTOM/plugins/herdr.
source "${0:A:h}/lib.zsh"
setup_sandbox
export HOME="$SB/home"
mkdir -p "$HOME/.oh-my-zsh/custom" && : >"$HOME/.oh-my-zsh/oh-my-zsh.sh"
unset ZSH ZSH_CUSTOM ZDOTDIR HERDR_PLUGIN_ROOT
print 'plugins=(git\n  docker\n)' >"$HOME/.zshrc"

out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
link="$HOME/.oh-my-zsh/custom/plugins/herdr"
check "fresh install exits 0" "0" "$rc"
check "symlink points at the repo" "$REPO" "$(readlink "$link")"
check_match "tells the user to add the plugin" "*add 'herdr' to the plugins list*" "$out"

out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "second run is idempotent" "0:$REPO" "$rc:$(readlink "$link")"
check_contains "second run says it updated the link" 'updated link' "$out"

print 'plugins=(git\n  herdr\n)' >"$HOME/.zshrc"
out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check_contains "detects herdr already in a multi-line plugins list" "already in the plugins list" "$out"

# HERDR_PLUGIN_ROOT (set by herdr during build) wins over the script location.
out="$(HERDR_PLUGIN_ROOT="$SB/elsewhere" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check "HERDR_PLUGIN_ROOT is honoured" "$SB/elsewhere" "$(readlink "$link")"

# ZSH_CUSTOM elsewhere.
mkdir -p "$SB/custom"
out="$(ZSH_CUSTOM="$SB/custom" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"
check "ZSH_CUSTOM is honoured" "$REPO" "$(readlink "$SB/custom/plugins/herdr")"

# A real directory in the way is left alone.
rm "$link"; mkdir -p "$link"; : >"$link/keep"
out="$(zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "existing directory is not clobbered" "0:1" "$rc:$([[ -f $link/keep ]] && print 1 || print 0)"
check_contains "existing directory is explained" 'already exists and is not a symlink' "$out"

# No Oh My Zsh: succeed so the herdr plugin still registers, but say so.
out="$(ZSH="$SB/nowhere" zsh "$REPO/bin/install-zsh-plugin" 2>&1)"; rc=$?
check "missing Oh My Zsh exits 0" "0" "$rc"
check_contains "missing Oh My Zsh is explained" 'Oh My Zsh was not found' "$out"

finish
