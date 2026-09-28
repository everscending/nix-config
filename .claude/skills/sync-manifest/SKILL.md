---
name: sync-manifest
description: Update the manifest in README.md so it matches what the nix config actually installs, editing the README in place wherever the two disagree. Use this skill whenever you add, remove, rename or comment out anything in home.nix's home.packages or configuration.nix's homebrew.brews / homebrew.casks, whenever you change system.defaults, shell aliases, session variables, fonts or Zed userSettings, and after any nix flake update or flake.lock bump since those move the version numbers the README states. Also use it when asked to "update the README", "sync the manifest", "document what this installs", or to check whether the README is still accurate — and reach for it proactively after editing the nix files rather than waiting to be asked, because the manifest is hand-written prose that drifts silently and nothing else catches it.
---

# Sync the README manifest

`README.md` carries a manifest of everything a rebuild of this config installs
and configures. It is prose written for someone reading the repo cold, not
generated output, which is exactly why it goes stale without anyone noticing.

**Your job is to leave README.md matching the config.** Finding the drift is the
first step, not the deliverable — if the manifest is wrong when you finish, the
skill has not been used. `AGENTS.md` asks for the manifest to be updated in the
*same commit* as the config change, so treat this as part of finishing that
change.

The one case where you change nothing: the check below reports no drift. Then say
so and stop. Rewriting accurate prose just to look busy makes the diff harder to
review.

## 1. Find the drift

```bash
python3 .claude/skills/sync-manifest/scripts/check_manifest.py --repo . --versions --suggest
```

This compares package names in the nix files against the rows in each README
table, resolves each Nix package's real version out of the pinned nixpkgs
(`--versions`), and prints a paste-ready row for anything missing, with the
version and description looked up from the pinned nixpkgs or the Homebrew API
(`--suggest`). It prints findings and edits nothing.

Drop `--versions` if you only touched package lists and want an instant answer;
it shells out to `nix eval` and takes a few seconds.

The script is deliberately narrow: it checks names and versions, which are
mechanical. It cannot tell you that a description reads badly or that a new macOS
default went undocumented, so step 2 still needs your eyes.

## 2. Edit README.md

Work through what the script reported and fix each one:

- **Package in the config, no README row** — add a row to the matching table.
  Use the suggested row, but read the description before accepting it. Upstream
  one-liners are sometimes verbose or oddly worded (ripgrep's mentions The Silver
  Searcher, which means nothing to most readers); rewrite for someone skimming
  the repo. A row whose description still says `COULD NOT CONFIRM` is not
  finished — look it up or write plainly that it is unconfirmed.
- **A package this repo builds itself** — a `let` binding like
  `ccstatusline = pkgs.callPackage ./ccstatusline.nix { }` is not in nixpkgs, so
  its version is pinned by hand in that file and a channel bump won't move it.
  Say so in the row, and name the file that pins it, so the next person knows
  where to bump it.
- **README row for a package no longer declared** — delete the row. If a section
  ends up with no rows, delete the section and its heading too.
- **Version mismatch** — update the number only. Don't rewrite the surrounding
  note while you're there; the churn hides the real change.
- **Commented-out package drift** — packages commented out in `home.packages`
  belong in the README's "listed but commented out" sentence, not in a table,
  since they aren't installed. Uncommenting one means moving it from that
  sentence into the table, and commenting one out means the reverse.
- **Version on a Homebrew row** — replace it with a description. Those packages
  are unpinned and track upstream, so any number written down becomes a lie.

Then check the sections the script can't diff, if your change touched them:

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

Only the first three have tables to diff. The rest are sentences, so if you
changed `system.defaults`, an alias, a session variable or a Zed setting, go read
the matching section and edit the prose yourself.

### Keep the prose that earns its place

The manifest's value is the notes a bare list can't carry — that `pip` can't
write into the read-only Nix store, that `pnpm setup` would fight the
Nix-managed `.zshrc`, that the text-size setting needs Full Disk Access. Preserve
that explanation when you touch a table, and when you add a package with a
non-obvious wrinkle, add the wrinkle.

Two things are load-bearing and easy to delete by accident:

- The **`zap` warning** that rebuilds uninstall undeclared Homebrew packages.
  `AGENTS.md` records that README carries this warning, so removing it makes that
  note false.
- The **credit to Kun Chen's dotfiles** the config is inspired by.

### Getting versions right by hand

Never write a version from memory or from what a tool reports on this machine —
the manifest documents what a rebuild of *this* flake installs, which is whatever
`flake.lock` pins, not whatever happens to be on `PATH`. The script resolves
these for you, but if you need one directly:

```bash
nix eval --raw --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; in p.nodejs.version'
```

## 3. Re-run until clean

```bash
python3 .claude/skills/sync-manifest/scripts/check_manifest.py --repo . --versions
```

Keep going until it reports the manifest is in sync. It exits 0 when clean and 1
when drifted, so that line is also the signal that you're done.

## 4. Report

Say which sections you changed and why, in a sentence or two. If you found drift
the current change didn't cause — a version stale from an earlier flake update,
say — mention it separately so it isn't mistaken for part of this change. If
something in the config has no natural home in the manifest, say so rather than
forcing a row; a missing section is easier to spot than a misleading one.
