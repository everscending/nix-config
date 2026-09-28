# .nix-config

Declarative macOS setup for an Apple Silicon Mac, built with
[nix-darwin](https://github.com/nix-darwin/nix-darwin),
[home-manager](https://github.com/nix-community/home-manager) and
[nix-homebrew](https://github.com/zhaofengli/nix-homebrew). One command rebuilds
the whole machine: packages, shell, editor config and macOS system settings.

Inspired by [Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles).

## Setup

1. Install Nix — https://github.com/DeterminateSystems/nix-installer
2. Run `./build.sh`

That runs `sudo nix run nix-darwin -- switch --flake .#mac`. Open a **new** shell
afterwards; PATH and environment changes are only picked up at shell startup.

On a machine whose macOS username isn't `jordanphillips`, change the single
`user = ` line in `flake.nix`.

> **Rebuilds remove undeclared Homebrew packages.**
> `homebrew.onActivation.cleanup = "zap"` is set, so anything you `brew install`
> ad-hoc gets uninstalled on the next rebuild. Add it to `configuration.nix`
> instead. This is deliberate — it keeps the machine reproducible.

## Manifest

Everything below is installed or configured by a rebuild. Nix versions are what
nixpkgs 26.05 currently pins and move when the channel is bumped; Homebrew
packages always track whatever Homebrew has today. The one exception is
`ccstatusline`, which is pinned by hand in `ccstatusline.nix` because it isn't in
nixpkgs — a channel bump won't move it.

### Languages and CLI tools — Nix

| Package | Version | Notes |
| --- | --- | --- |
| `python3` | 3.13.15 | Tracks the nixpkgs default, so other Python packages share one interpreter |
| `uv` | 0.11.21 | Venvs and package installs — `pip` can't write into the read-only Nix store |
| `nodejs` | 24.19.0 | The LTS line, again the nixpkgs default |
| `pnpm` | 11.25.0 | Installed directly rather than through corepack |
| `ccstatusline` | 2.2.30 | Claude Code status line. Not in nixpkgs — packaged from the npm tarball by `ccstatusline.nix` |

`ripgrep`, `fd`, `fzf`, `jq` and `lazygit` are listed but commented out in
`home.nix` — uncomment to pick them up.

### CLI tools — Homebrew

| Package | What it is |
| --- | --- |
| `herdr` | Agent multiplexer that lives in your terminal |

### GUI apps — Homebrew casks

| Cask | What it is |
| --- | --- |
| `claude` | Claude desktop app |
| `claude-code` | Claude Code desktop app |
| `ghostty` | Terminal emulator |
| `karabiner-elements` | Keyboard remapper |
| `slack` | Chat |
| `zed` | Code editor |

### Claude Code status line

A rebuild points Claude Code at `ccstatusline` by merging a `statusLine` block
into `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "/nix/store/…/bin/ccstatusline" }
```

This runs during home-manager activation, which the generated activate script
sequences after the Homebrew bundle — so the `claude-code` cask is already
installed by the time the status line is wired up.

That settings file is shared with Claude Code and edited by hand, so
`claude-statusline.py` merges rather than writes. It sets only `type` and
`command` — where the binary lives, which is the part Nix knows — and leaves
everything else untouched, including unrelated keys like `hooks` and `theme` and
the cosmetic `statusLine` keys (`padding`, `refreshInterval`) that ccstatusline's
own TUI manages. A malformed `settings.json` is left alone with a warning rather
than replaced, and a failure there won't abort the rest of the rebuild.

Run `ccstatusline` to open its configuration TUI. Its own settings live in
`~/.config/ccstatusline/settings.json`, which this config does not manage.

### Fonts

`nerd-fonts.hack` (3.4.0+3.003), with `fontconfig` enabled.

### Shell — zsh

Autosuggestions (ghost text from history, accept with **Ctrl-F**), syntax
highlighting, and oh-my-zsh on the `gnzh` theme.

Aliases: `..` (up a directory), `add` (`git add .`), `push`, `pull`,
`m` (`git switch main`), `co` (`codex --full-auto`).

`EDITOR` is set to `zed`.

### Global package prefixes

The Nix store is read-only, so `npm -g` and `pnpm add -g` are pointed at
writable directories and both are added to `PATH`:

| Variable | Path |
| --- | --- |
| `npm_config_prefix` | `~/.npm-global` |
| `PNPM_HOME` | `~/Library/pnpm` (pnpm's own default on macOS) |

Don't run `pnpm setup` — it appends `PATH` lines to the `.zshrc` that Nix now
manages. The config above already does that job.

### Editor — Zed

Zed itself comes from the Homebrew cask; home-manager only manages its config,
merging into `~/.config/zed/settings.json` on each rebuild. Nix values win, and
anything you change in Zed's UI that isn't listed here is kept.

Managed: the `nix` extension, project panel docked left, agent sidebar right,
CLI opens a new window, UI font 16 / buffer font 15, and a system-following
theme (One Light / Gruvbox Dark Hard).

### macOS system settings

Dark mode · fast key repeat (short initial delay) · auto-hiding Dock · menu bar
always visible · show all file extensions · Finder list view by default · tap to
click · Accessibility text size 16pt.

The text-size setting writes to the protected `com.apple.universalaccess`
domain. It needs Full Disk Access for the terminal running the rebuild; without
it the switch prints a warning and continues rather than failing.

## Where things are defined

| File | Scope |
| --- | --- |
| `flake.nix` | Inputs pinned to the 26.05 release line, the `user` name, and the `mac` system output |
| `configuration.nix` | System-wide: macOS defaults, Homebrew packages, activation scripts |
| `home.nix` | Per-user: packages, fonts, environment, zsh, Zed, Claude Code status line |
| `ccstatusline.nix` | Packages `ccstatusline` from npm; bump the version and hash here |
| `claude-statusline.py` | Merges the `statusLine` block into `~/.claude/settings.json` on activation |
| `build.sh` | Applies the config |
| `flake.lock` | Exact input revisions — commit changes to this |

`nix.enable = false` because the Determinate installer already manages the Nix
daemon. Update pinned inputs with `nix flake update`.
