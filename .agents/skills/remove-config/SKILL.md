---
name: remove-config
description: Remove an app, CLI or agent skill from this nix-darwin config — every trace of it, what else depends on it, what the next build will delete, and the README manifest. Use when asked to remove, uninstall or drop software that the nix config sets up.
argument-hint: <app name>
---

# Remove an app from the nix config

The app is whatever the user named alongside this skill. In Claude Code it
arrives here: $ARGUMENTS

You are done when no trace of the app is left in the config, the build passes,
the README manifest is in sync, the change is committed, and the user knows what
the next `./build.sh` will delete and what cleanup it leaves to them. Applying the
config is the user's move.

How each channel is removed, and what removal leaves behind, is in the add-config
skill's reference: `.agents/skills/add-config/references/channels.md`.

## 1. Find every trace

Search the repo for the app under every name it goes by — app, binary, cask,
flake input, skill — not only the one the user typed:

```bash
grep -rniE '<name>|<binary>|<cask>' --exclude-dir=.git .
```

Assign each hit to its channel, or to the docs. Expect more than the package
line: comments, a flake input and its name in the outputs pattern, a `let`
binding, a local `.nix` file, an activation step, a shell alias, a README row or
section. Done when every hit is assigned.

## 2. Check dependents

Find what relies on the app before cutting it. Some packages are used by store
path elsewhere: `pkgs.nodejs` runs ccstatusline and the agent-skills installer;
Claude Code's settings carry the status line; `programs.git` exists for gh's
credential helper. If anything still needs the app, tell the user what would
break and wait for their decision. Done when each hit outside the app's own
definition is either part of the removal or confirmed independent.

## 3. Weigh what the next build deletes

For a cask or formula, read the `zap` stanza from
`https://formulae.brew.sh/api/{cask,formula}/<name>.json`; the config's `zap`
cleanup trashes every listed path. For an activation step or agent skill, list
what it left on the machine: removing it from the config undoes none of that.
If the deletions reach beyond the app itself (documents, or settings another
tool shares), lay them out and get the user's go-ahead before editing.

## 4. Remove

Follow the **Remove** part of each affected channel in `channels.md`. Delete
whole entries, including the comments that explained them. If a supporting
setting existed only for this app, remove it too.

## 5. Verify

1. `nix flake lock` if a flake input went, and confirm that no other pin moved.
2. Build: `nix build .#darwinConfigurations.mac.system --no-link --print-out-paths`.
3. Check the app is gone from the artifact that installed it: the generated
   Brewfile, the profile's package list, or the generated activate script.
4. Rerun the step 1 search. Done when it returns nothing but deliberate
   mentions, and you can say why each one stays.

## 6. Document

Run the `sync-manifest` skill: delete the app's rows, and its section if it was
the only thing in one. Done when
`.agents/skills/sync-manifest/scripts/check_manifest.py --repo . --versions` exits 0.

## 7. Commit and report

Make one commit with the config and README changes; leave pushing to the user.
Report what the next `./build.sh` will uninstall and delete, and give exact
commands for any cleanup the config cannot do — installed skills, merged settings
keys. Run those commands yourself only with the user's go-ahead: they act on the
real home folder.
