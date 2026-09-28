---
name: sync-manifest
description: Bring the human-readable manifest in README.md back in line with what the nix config actually installs. Use this skill whenever you add, remove, rename or comment out anything in home.nix's home.packages or configuration.nix's homebrew.brews / homebrew.casks, whenever you change system.defaults, shell aliases, session variables, fonts or Zed userSettings, and after any nix flake update or flake.lock bump since those move the version numbers the README states. Also use it when asked to "update the README", "sync the manifest", "document what this installs", or to check whether the README is still accurate — and reach for it proactively after editing the nix files rather than waiting to be asked, because the manifest is hand-written prose that drifts silently and nothing else catches it.
---

# Sync the README manifest

`README.md` in this repo carries a manifest of everything a rebuild installs and
configures. It is prose written for a human reading the repo cold, not generated
output, which is exactly why it goes stale without anyone noticing. Your job is
to make it true again while keeping it worth reading.

`AGENTS.md` asks for the manifest to be updated in the *same commit* as the
config change, so treat this as part of finishing that change rather than a
follow-up chore.

## Start by finding the drift

```bash
python3 .claude/skills/sync-manifest/scripts/check_manifest.py --repo . --versions
```

This compares package names in the nix files against the rows in each README
table, and with `--versions` also resolves each Nix package's real version out of
the pinned nixpkgs. It prints one line per problem and changes nothing. Drop
`--versions` if you only touched package lists and want an instant answer; it
shells out to `nix eval` and takes a few seconds.

Fix what it reports, then re-run until it says the manifest is in sync. Exit
status is 0 when clean and 1 when drifted.

The script is deliberately narrow: it checks names and versions, which are
mechanical. It cannot tell you that a description is misleading or that a new
macOS default went undocumented, so the sections below still need your eyes.

## What mirrors what

| README section | Source of truth |
| --- | --- |
| Languages and CLI tools — Nix | `home.packages` in `home.nix` |
| CLI tools — Homebrew | `homebrew.brews` in `configuration.nix` |
| GUI apps — Homebrew casks | `homebrew.casks` in `configuration.nix` |
| Fonts | the `nerd-fonts.*` entry in `home.packages` |
| Shell — zsh | `programs.zsh` (aliases, plugins, theme, `initContent` keybindings) |
| Global package prefixes | `home.sessionVariables` and `home.sessionPath` |
| Editor — Zed | `programs.zed-editor.userSettings` and `extensions` |
| macOS system settings | `system.defaults` and `system.activationScripts` |
| Where things are defined | the set of files in the repo root |

Sections beyond the first three have no table to diff, so when you change
`system.defaults`, an alias, a session variable or a Zed setting, go read the
matching section and edit the sentence yourself.

## Getting versions right

Never write a version from memory or from what a tool reports on this machine —
the manifest documents what a rebuild of *this* flake installs, which is whatever
`flake.lock` pins, not whatever happens to be on `PATH`. The script resolves
these for you, but if you need one directly:

```bash
nix eval --raw --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; in p.nodejs.version'
```

Homebrew packages are a different case: they are unpinned and track upstream, so
any version written next to a brew or cask is guaranteed to become a lie. Give
those a short description of what the thing *is* instead. The script flags a
version-looking string in a Homebrew row for this reason.

## Descriptions you don't already know

If a package's purpose isn't obvious, look it up rather than guessing — a
confidently wrong one-liner in a README is worse than none. For Homebrew:

```bash
curl -s https://formulae.brew.sh/api/formula/<name>.json | python3 -c 'import json,sys; print(json.load(sys.stdin)["desc"])'
# casks live at /api/cask/<name>.json and use "desc" too
```

For Nix packages, `pkgs.<name>.meta.description` through the same `nix eval`
shape above. If a lookup fails, say plainly in the row that you couldn't confirm
it rather than inventing something plausible.

## Keep the prose that earns its place

The manifest's value is the notes a bare list can't carry — that `pip` can't
write into the read-only Nix store, that `pnpm setup` would fight the
Nix-managed `.zshrc`, that the text-size setting needs Full Disk Access. When you
touch a table, preserve the surrounding explanation; when you add a package with
a non-obvious wrinkle, add that wrinkle.

Two things in the README are load-bearing and easy to delete by accident:

- The **`zap` warning** that rebuilds uninstall undeclared Homebrew packages.
  `AGENTS.md` records that README carries this warning, so removing it makes that
  note false.
- The **credit to Kun Chen's dotfiles** the config is inspired by.

Commented-out packages get a sentence rather than table rows, since they aren't
installed. When you uncomment one, move it into the table and out of that
sentence; the script checks both halves.

## Finishing

Report which sections you changed and why, in a sentence or two. If you found
drift the config change didn't cause — a version stale from an earlier flake
update, say — mention it separately so it isn't mistaken for part of the current
change. If something in the config has no natural home in the manifest, say so
rather than forcing a row; a missing section is easier to spot than a misleading
one.
