# herdr-ohmyzsh

[Oh My Zsh](https://ohmyz.sh) plugin for [Herdr](https://herdr.dev), the terminal
workspace for coding agents. One repository, two halves:

- an Oh My Zsh plugin named `herdr` that hooks your shell into the Herdr sidebar
- a Herdr plugin that adds a "reload Oh My Zsh everywhere" action

Outside a Herdr pane the zsh plugin only installs completions for the `herdr`
CLI. It is safe to keep in your `plugins=(...)` list on every machine.

## What you get

**Slow commands show up in the sidebar.** Any command that runs longer than
the threshold (10 seconds by default) appears in the Herdr sidebar as
*working*, labelled with the program name, and flips to *done* when it
finishes. Your test suite or build gets the same treatment as an agent, rolls
up to the workspace, and another agent can `herdr agent wait` on it.

**Finished notifications.** When a slow command finishes in a pane you are not
looking at, Herdr shows a toast with the exit code and duration. Failures use
the attention sound.

**Helpers.**

| Command | Does |
|---|---|
| `hsplit [right\|down] [cmd...]` | Split the current pane, keep the directory, optionally run a command there |
| `htab [label]` | Open a tab in this workspace at the current directory |
| `hagent NAME [KIND] [-- args]` | Split right without stealing focus and start a named agent (default kind: `claude`) |
| `hworktree BRANCH [BASE]` | Create a git worktree for BRANCH and open it as a workspace |
| `hreload [--dry-run]` | Reload Oh My Zsh in every pane sitting at an idle zsh prompt |

**Reload Oh My Zsh in every idle pane.** After editing `.zshrc` you usually
have a dozen stale shells. The `reload-all` action sends `omz reload` to every
pane whose only foreground process is an idle zsh, and leaves panes running a
command, an editor, or an agent alone. Bind it to a key (see below) or run
`hreload`.

**Completions** for the `herdr` CLI, regenerated in the background so a herdr
upgrade is picked up by the next shell.

## Install

### Through Herdr (recommended when you use both)

```sh
herdr plugin install robbyrussell/herdr-ohmyzsh
```

The build step links the checkout into `$ZSH_CUSTOM/plugins/herdr`. Then add
`herdr` to the plugins list in `~/.zshrc` and open a new shell:

```sh
plugins=(git herdr)
```

If you use `herdr plugin link` for development, run the link step yourself:
`zsh bin/install-zsh-plugin`.

### As a plain Oh My Zsh custom plugin

```sh
git clone https://github.com/robbyrussell/herdr-ohmyzsh \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/herdr"
```

Then add `herdr` to `plugins=(...)`. You get everything except the Herdr-side
keybinding; `hreload` still works.

### Keybinding for reload-all

In `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+shift+r"
type = "plugin_action"
command = "ohmyzsh.shell.reload-all"
description = "reload Oh My Zsh in idle panes"
```

## Settings

Set these in `~/.zshrc` before Oh My Zsh loads. All are optional.

| Variable | Default | Meaning |
|---|---|---|
| `HERDR_OMZ_THRESHOLD` | `10` | Seconds before a command counts as slow |
| `HERDR_OMZ_REPORT` | `true` | Show slow commands in the sidebar |
| `HERDR_OMZ_NOTIFY` | `true` | Toast when a slow command finishes |
| `HERDR_OMZ_NOTIFY_FOCUSED` | `false` | Toast even when the pane is focused |
| `HERDR_OMZ_DEFAULT_AGENT` | `claude` | Agent kind used by `hagent` |
| `HERDR_OMZ_IGNORE` | see below | Programs that are never reported |

`HERDR_OMZ_IGNORE` is an array. The default covers every agent Herdr detects
on its own (`claude`, `codex`, `gemini`, ...) and interactive programs such as
`vim`, `ssh`, `less` and `htop`. To extend it rather than replace it:

```sh
plugins=(git herdr)
source $ZSH/oh-my-zsh.sh
HERDR_OMZ_IGNORE+=(bundle rails)
```

## Uninstall

```sh
herdr plugin uninstall ohmyzsh.shell
rm "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/herdr"
```

and remove `herdr` from `plugins=(...)`.

## Development

Tests need only zsh and bash. They run the plugin against a fake `herdr`
command that records every call, so no Herdr server is involved.

```sh
zsh tests/run.zsh          # everything
zsh tests/run.zsh hooks    # one file
```

CI runs the suite on Ubuntu and macOS.

## License

MIT
