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

That resolves any new flake inputs, then runs
`sudo nix run nix-darwin -- switch --flake .#mac`. Open a **new** shell afterwards;
PATH and environment changes are only picked up at shell startup.

To update, run `./update.sh` (every input) or `./update.sh <input>` (just that
one), then `./build.sh`. It runs `nix flake update`, carries the new version
numbers into the manifest below, and commits both — it doesn't push.

On a machine whose macOS username isn't `jordanphillips`, change the single
`user = ` line in `flake.nix`.

> **Rebuilds remove undeclared Homebrew packages.**
> `homebrew.onActivation.cleanup = "zap"` is set, so anything you `brew install`
> ad-hoc gets uninstalled on the next rebuild. Add it to `configuration.nix`
> instead. This is deliberate — it keeps the machine reproducible.

## Manifest

Everything below is installed or configured by a rebuild. Most Nix versions are
what nixpkgs 26.05 currently pins and move when the channel is bumped; Homebrew
packages always track whatever Homebrew has today. Two packages come from outside
the channel, so a nixpkgs bump does not touch them: `claude-code` follows its own
flake input, and `ccstatusline` is pinned by hand in `ccstatusline.nix`.

### Languages and CLI tools — Nix

| Package | Version | Notes |
| --- | --- | --- |
| `python3` | 3.13.15 | Tracks the nixpkgs default, so other Python packages share one interpreter |
| `uv` | 0.11.21 | Venvs and package installs — `pip` can't write into the read-only Nix store |
| `nodejs` | 24.19.0 | The LTS line, again the nixpkgs default |
| `pnpm` | 11.25.0 | Installed directly rather than through corepack |
| `claude-code` | 2.1.284 | The CLI, from the [claude-code-nix](https://github.com/sadjow/claude-code-nix) flake — see below |
| `ccstatusline` | 2.2.30 | Claude Code status line. Not in nixpkgs — packaged from the npm tarball by `ccstatusline.nix` |
| `gh` | 2.100.0 | GitHub CLI, set up by `programs.gh` — see below |

`ripgrep`, `fd`, `fzf`, `jq` and `lazygit` are listed but commented out in
`home.nix` — uncomment to pick them up.

#### Why claude-code comes from a flake

Not from Homebrew, and not from nixpkgs, whose copy lags behind releases.
[claude-code-nix](https://github.com/sadjow/claude-code-nix) publishes releases
within the hour and ships a self-contained native binary.

The input deliberately does **not** follow this config's nixpkgs. Overriding it
would change the derivation hash, missing the project's binary cache, and upstream
only tests against its own pin. The cost is a second nixpkgs in `flake.lock`.

The package disables Claude Code's own auto-updater, so `claude` will not update
itself. Bump it deliberately:

```bash
./update.sh claude-code-nix && ./build.sh
```

Its optional Cachix cache is `claude-code.cachix.org`. Note that `nix.settings`
can't add it here, since `nix.enable = false` leaves the daemon to Determinate —
it would have to go in Determinate's own config. Skipping it just means Nix
downloads the release binary from Anthropic's CDN instead, at similar cost.

### CLI tools — Homebrew

| Package | What it is |
| --- | --- |
| `herdr` | Agent multiplexer that lives in your terminal |

### GUI apps — Homebrew casks

| Cask | What it is |
| --- | --- |
| `claude` | Claude desktop app (the CLI comes from Nix, above) |
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

### GitHub CLI — gh

`programs.gh` installs `gh` and manages `~/.config/gh/config.yml`: HTTPS as the
git protocol, and `zed --wait` as its editor. gh needs an editor that blocks until
you close the file; with plain `zed` it would read back an empty PR body. That file
is now a read-only link into the Nix store, so `gh config set` won't work — change
settings in `home.nix` instead.

It also makes git use gh's login for `github.com` and `gist.github.com` over HTTPS,
so `git push` needs no SSH key or separate token. That setting lives in
`~/.config/git/config`, which is why `programs.git` is enabled too — home-manager
only writes git's config when it is. Two things it deliberately does *not* do:
install a second git (`package = null`, so `/usr/bin/git` is still used), or touch
`~/.gitconfig`, where your name and email stay. Commit signing is explicitly off,
since home-manager would otherwise default it to GnuPG for this `stateVersion`.

**Logging in is a one-time manual step**, not part of the config, because the
token belongs in the macOS keychain rather than the world-readable Nix store. After
`./build.sh`, run this in your own terminal (it's interactive):

```bash
gh auth login --hostname github.com --git-protocol https --web
```

If it asks whether to authenticate Git with your GitHub credentials, answer no.
Nix has already set that up, and yes would only write a redundant copy into
`~/.gitconfig`. Check with `gh auth status`.

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
| `flake.nix` | Inputs (26.05 release line, plus `claude-code-nix` on its own), the `user` name, and the `mac` system output |
| `configuration.nix` | System-wide: macOS defaults, Homebrew packages, activation scripts |
| `home.nix` | Per-user: packages, fonts, environment, zsh, Zed, gh and git, Claude Code status line |
| `ccstatusline.nix` | Packages `ccstatusline` from npm; bump the version and hash here |
| `claude-statusline.py` | Merges the `statusLine` block into `~/.claude/settings.json` on activation |
| `build.sh` | Locks new inputs as you, then applies the config as root |
| `update.sh` | Updates inputs, fixes manifest versions, commits both |
| `flake.lock` | Exact input revisions — commit changes to this |

`nix.enable = false` because the Determinate installer already manages the Nix
daemon. Update pinned inputs with `./update.sh`.
