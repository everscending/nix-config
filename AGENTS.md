# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.

## Keep the README manifest in sync

`README.md` carries a human-readable manifest of everything this config installs and
configures. It is hand-written prose, not generated, so it drifts silently.

Any change to `home.packages`, `homebrew.brews`, `homebrew.casks`, `system.defaults`,
shell aliases, session variables or the Zed settings MUST be reflected in the matching
README section in the same commit. Removing a package means removing its row.

Versions in the manifest are the resolved ones, not the Nix attribute names. Read them
out of the pinned nixpkgs rather than guessing:

```sh
nix eval --raw --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.aarch64-darwin; in p.nodejs.version'
```

So after a `nix flake update`, re-check the versions in the manifest. Do not list
versions for Homebrew packages; those are unpinned and track upstream.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
