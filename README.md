# herdr-ohmyzsh

[![CI](https://github.com/robbyrussell/herdr-ohmyzsh/actions/workflows/ci.yml/badge.svg)](https://github.com/robbyrussell/herdr-ohmyzsh/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/robbyrussell/herdr-ohmyzsh)](LICENSE)

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

There is a second half to this. I have a `herdr` plugin waiting to be merged
into Oh My Zsh itself, [ohmyzsh/ohmyzsh#14079](https://github.com/ohmyzsh/ohmyzsh/pull/14079).
That one is the plain-terminal side: completions, `hrdr` aliases for the daily
commands, a session picker, and a prompt segment showing the current pane.
This repository is the Herdr-side experiment, the pieces that only make sense
inside a pane. Both are named `herdr` for now, and Oh My Zsh loads a custom
plugin ahead of an in-tree one with the same name, so once that PR lands I
will sort out how the two fit together.

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

## The muscle memory it saves

Herdr can do all of the pane, tab and worktree work already, from the UI or
the CLI. I wander between projects from a zsh prompt all day, and I did not
want to remember the argv. This is what I type versus what I would otherwise
have to remember.

| I type | Without the plugin I would need |
|---|---|
| `hsplit` | `herdr pane split --current --direction right --cwd "$PWD" --focus` |
| `hsplit down tail -f log/development.log` | The split above with `--direction down`, then read the new pane id out of the JSON, then `herdr pane run w1:p9 tail -f log/development.log` |
| `htab server` | `herdr tab create --cwd "$PWD" --focus --label server` |
| `hagent reviewer` | `herdr pane split --current --direction right --cwd "$PWD" --no-focus`, copy the pane id from the JSON, then `herdr agent start reviewer --kind claude --pane w1:p9` |
| `hworktree feature/login main` | `herdr worktree create --branch feature/login --base main --cwd "$PWD" --focus` |
| `hreload` | `herdr pane list`, then for each pane `herdr pane get` and `herdr pane process-info` to find the idle zsh ones, then `herdr pane run <id> "omz reload"` on each |
| `herdr pane sp<tab>` | `herdr completion zsh > "$ZSH_CACHE_DIR/completions/_herdr"`, and remembering to do it again after every herdr upgrade |
| Nothing. The toast finds me. | Switching back to the pane to see whether `bin/rails test` is done, or `herdr pane wait-output <id> --match "runs,"` from somewhere else |

Two of these are not shortcuts, they are things Herdr does not do on its own:

- **A plain shell command in the sidebar.** Herdr tracks agents. A pane running
  your test suite shows as unknown until something inside the shell reports
  it. The plugin reports it, so the test run gets the same working and done
  lifecycle as an agent, and the toast when it finishes.
- **Reloading Oh My Zsh in every idle pane.** Nothing else does this. It is
  the one feature that only makes sense if you use both tools.

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
