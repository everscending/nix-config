# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.

## Keep the README manifest in sync

`README.md` carries a hand-written manifest of everything this config installs and
configures, so it drifts silently. Any change to `home.packages`, `homebrew.brews`,
`homebrew.casks`, `system.defaults`, shell aliases, session variables,
`home.activation` steps, or the Zed, gh or git settings must be reflected in the
matching README section in the same commit. Use `./update.sh` rather than a bare
`nix flake update`: it moves the manifest's version numbers along with the lock.

Use the `sync-manifest` skill for this — it maps each README section to its source
and bundles a drift checker:

```sh
python3 .agents/skills/sync-manifest/scripts/check_manifest.py --repo . --versions
```

## Repo skills

Skills for this repo live in `.agents/skills/`, which Codex and other agents read;
`.claude/skills/` holds a symlink to each one for Claude Code. Add a new skill the
same way, so every agent sees the same copy. `add-config` and `remove-config` are
the way to add or remove software here.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
