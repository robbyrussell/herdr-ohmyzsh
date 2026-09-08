# herdr-ohmyzsh

An experiment. I created [Oh My Zsh](https://ohmyz.sh), and I am still wrapping
my head around [Herdr](https://herdr.dev). I have twenty years of shortcut
habits in my zsh terminals, and I wanted them to carry over into a workspace
that is mostly about coding agents. This plugin is where I am collecting them.

```sh
herdr plugin install robbyrussell/herdr-ohmyzsh
```

Then add `herdr` to your plugins list in `~/.zshrc` and open a new shell.

It is safe to leave in your plugins list on every machine. Outside a Herdr
pane it only installs completions for the `herdr` command. Removing it is two
commands, listed at the bottom.

## What it does

**Tells you when the slow thing finished.** Any command that runs longer than
ten seconds shows in the Herdr sidebar as working, then done, just like an
agent. If you have switched to another pane, you get a toast with the exit
code and duration.

**Reloads Oh My Zsh everywhere.** You edited `.zshrc`, and now eleven panes
are stale. One keybinding sends `omz reload` to every pane sitting at an idle
zsh prompt, and leaves alone anything running a command, an editor, or an
agent.

**Short names for the things I type most.**

| Command | Does |
|---|---|
| `hsplit [right\|down] [cmd]` | Split the current pane, keep the directory, optionally run a command |
| `htab [label]` | New tab in this workspace, same directory |
| `hagent NAME [KIND]` | Split right and start a named agent there, without stealing focus |
| `hworktree BRANCH [BASE]` | New git worktree, opened as a workspace |
| `hreload [--dry-run]` | Reload Oh My Zsh in every idle pane |

## What it will not do

- Report agents. Herdr already tracks Claude, Codex, Gemini and the rest, and
  this stays out of the way. Editors, pagers and ssh are ignored too.
- Edit your `.zshrc`. The install step prints the one line to add.
- Break your prompt. If Herdr is gone, every call fails silently.

## Settings

All optional. Set them in `~/.zshrc` before Oh My Zsh loads.

| Variable | Default | Meaning |
|---|---|---|
| `HERDR_OMZ_THRESHOLD` | `10` | Seconds before a command counts as slow |
| `HERDR_OMZ_REPORT` | `true` | Show slow commands in the sidebar |
| `HERDR_OMZ_NOTIFY` | `true` | Toast when a slow command finishes |
| `HERDR_OMZ_NOTIFY_FOCUSED` | `false` | Toast even when the pane is focused |
| `HERDR_OMZ_DEFAULT_AGENT` | `claude` | Agent kind used by `hagent` |
| `HERDR_OMZ_IGNORE` | agents, editors, ssh | Programs never reported. Extend with `HERDR_OMZ_IGNORE+=(bundle)` after Oh My Zsh loads |

Keybinding for the reload action, in `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+shift+r"
type = "plugin_action"
command = "ohmyzsh.shell.reload-all"
description = "reload Oh My Zsh in idle panes"
```

## Without Herdr's installer

Clone it as a normal custom plugin. You get everything except the keybinding;
`hreload` still works.

```sh
git clone https://github.com/robbyrussell/herdr-ohmyzsh \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/herdr"
```

## Uninstall

```sh
herdr plugin uninstall ohmyzsh.shell
rm "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/herdr"
```

Then remove `herdr` from your plugins list.

## Development

Tests run against a fake `herdr` that records every call, so they need only
zsh and bash. CI runs them on Ubuntu and macOS.

```sh
zsh tests/run.zsh
```

MIT licensed. Ideas and pull requests welcome; this is a work in progress.
