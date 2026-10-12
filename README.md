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
packages always track whatever Homebrew has today. Three packages come from outside
the channel, so a nixpkgs bump does not touch them: `claude-code` and `codex` follow
their own flake inputs, and `ccstatusline` is pinned by hand in `ccstatusline.nix`.

### Languages and CLI tools — Nix

| Package | Version | Notes |
| --- | --- | --- |
| `python3` | 3.13.15 | Tracks the nixpkgs default, so other Python packages share one interpreter |
| `uv` | 0.11.21 | Venvs and package installs — `pip` can't write into the read-only Nix store |
| `nodejs` | 24.21.0 | The LTS line, again the nixpkgs default |
| `pnpm` | 11.27.0 | Installed directly rather than through corepack |
| `claude-code` | 2.1.292 | The CLI, from the [claude-code-nix](https://github.com/sadjow/claude-code-nix) flake — see below |
| `codex` | 0.160.1 | The Codex CLI, from the [codex-cli-nix](https://github.com/sadjow/codex-cli-nix) flake — see below |
| `ccstatusline` | 2.2.30 | Claude Code status line. Not in nixpkgs — packaged from the npm tarball by `ccstatusline.nix` |
| `gh` | 2.102.0 | GitHub CLI, set up by `programs.gh` — see below |

`ripgrep`, `fd`, `fzf`, `jq` and `lazygit` are listed but commented out in
`home.nix` — uncomment to pick them up.

#### Why claude-code and codex come from flakes

Not from Homebrew, and not from nixpkgs, whose copies lag behind releases.
[claude-code-nix](https://github.com/sadjow/claude-code-nix) and
[codex-cli-nix](https://github.com/sadjow/codex-cli-nix), from the same maintainer,
publish new releases quickly and ship self-contained native binaries. Each desktop
app still comes from Homebrew; only the CLIs come from these flakes.

Neither input follows this config's nixpkgs, deliberately. Overriding it would
change the derivation hash, missing each project's binary cache, and upstream only
tests against its own pin. The cost is extra nixpkgs copies in `flake.lock`.

Both packages disable the tool's own auto-updater, so `claude` and `codex` will not
update themselves. Bump them deliberately — together, or name just one:

```bash
./update.sh claude-code-nix codex-cli-nix && ./build.sh
```

claude-code-nix's optional Cachix cache is `claude-code.cachix.org`. Note that `nix.settings`
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
| `codex-app` | Codex desktop app (the CLI comes from Nix, above) |
| `ghostty` | Terminal emulator |
| `karabiner-elements` | Keyboard remapper |
| `slack` | Chat |
| `tailscale-app` | Tailscale VPN; also installs the `tailscale` CLI to `/usr/local/bin` |
| `zed` | Code editor |

Tailscale needs a one-time setup after the first `./build.sh`: open the app, approve
its network extension when macOS asks (System Settings → Privacy & Security, or
General → Login Items & Extensions), and log in. It updates itself after that. It's
the app rather than nix-darwin's `services.tailscale`, which runs an older,
headless daemon — don't enable both, as they would fight over the network setup.

### Claude Code status line

A rebuild points Claude Code at `ccstatusline` by merging a `statusLine` block
into `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "/nix/store/…/bin/ccstatusline" }
```

This runs during home-manager activation, which the generated activate script
sequences after the Homebrew bundle and after packages are linked — so Claude
Code is already installed by the time the status line is wired up.

That settings file is shared with Claude Code and edited by hand, so
`claude-statusline.py` merges rather than writes. It sets only `type` and
`command` — where the binary lives, which is the part Nix knows — and leaves
everything else untouched, including unrelated keys like `hooks` and `theme` and
the cosmetic `statusLine` keys (`padding`, `refreshInterval`) that ccstatusline's
own TUI manages. A malformed `settings.json` is left alone with a warning rather
than replaced, and a failure there won't abort the rest of the rebuild.

Run `ccstatusline` to open its configuration TUI. Its own settings live in
`~/.config/ccstatusline/settings.json`, which this config does not manage.

### Agent skills

Two sets of skills are installed for **both Claude Code and Codex**, using the
cross-agent installer (`npx skills@latest add <source> -g`):

| Source | What it adds |
| --- | --- |
| [mattpocock/skills](https://github.com/mattpocock/skills) | 38 engineering skills such as `tdd`, `diagnosing-bugs` and `grill-me` |
| [kunchenguid/lavish-axi](https://github.com/kunchenguid/lavish-axi) | `lavish` — Lavish Editor: the agent writes plans, diagrams and reports as HTML you can annotate in the browser and send feedback on |

One copy of each skill lands in `~/.agents/skills`, which Codex reads directly;
Claude Code gets a link per skill in `~/.claude/skills`. Both agents are named
explicitly (`-a claude-code codex`) instead of left to the installer's
auto-detection, which only counts an agent as present once its `~/.claude` or
`~/.codex` folder exists — on a fresh machine, not until you first run it. The list
lives in `agentSkills` in `home.nix`; add a source there to install it everywhere.

This runs at the end of home-manager activation, after Node, Claude Code and Codex
are installed. Lavish needs nothing else: its skill has the agent run
`npx -y lavish-axi` when it's needed. Its optional session hook (`lavish-axi setup
hooks`) is not set up here.

Each source installs **once**. Running the installer again overwrites the skill
files, and they're meant to be edited, so later rebuilds see each source in
`~/.agents/.skill-lock.json` and leave it alone. That check is per source, so adding
one later installs just that one. Update deliberately:

```bash
npx skills update -g
```

Because it needs the network, a failed install prints a warning and the rest of
the rebuild carries on; the next `./build.sh` tries again. To link the skills into
another agent later, run `npx skills add <source> -g -a <agent>` once by hand; like
any re-run of `add`, that refreshes the skill files.

Then run `/setup-matt-pocock-skills` in each repo you use Matt's skills in. It asks
which issue tracker and labels you use. Lavish is invoked as `/lavish` in Claude
Code, or picked up on its own when a visual answer fits.

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

`~/.zshrc` is generated by Nix and read-only, so edits go in one of two places.
Changes you want on every machine belong in `home.nix` — PATH entries in
`home.sessionPath` (see below), aliases in `shellAliases`. Anything machine-local or
experimental goes in **`~/.zshrc.local`**: the generated `.zshrc` sources it last, if
it exists, so it can add PATH entries, set variables or override aliases without a
rebuild. Nix never creates or touches it. For example:

```bash
export PATH="$HOME/my-tools/bin:$PATH"
```

Changes take effect in new shells. It only applies to interactive shells — your
terminal — not to scripts run with `zsh script.sh` or programs launched from the
Dock.

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
| `flake.nix` | Inputs (26.05 release line, plus `claude-code-nix` and `codex-cli-nix` on their own), the `user` name, and the `mac` system output |
| `configuration.nix` | System-wide: macOS defaults, Homebrew packages, activation scripts |
| `home.nix` | Per-user: packages, fonts, environment, zsh, Zed, gh and git, Claude Code status line, agent skills |
| `ccstatusline.nix` | Packages `ccstatusline` from npm; bump the version and hash here |
| `claude-statusline.py` | Merges the `statusLine` block into `~/.claude/settings.json` on activation |
| `build.sh` | Locks new inputs as you, then applies the config as root |
| `update.sh` | Updates inputs, fixes manifest versions, commits both |
| `flake.lock` | Exact input revisions — commit changes to this |

`nix.enable = false` because the Determinate installer already manages the Nix
daemon. Update pinned inputs with `./update.sh`.
