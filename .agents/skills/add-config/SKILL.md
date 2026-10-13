---
name: add-config
description: Add an app, CLI or agent skill to this nix-darwin config — choose how it's installed, wire it in, verify the build, update the README manifest. Use when asked to add, install or set up software on this Mac through the nix config.
argument-hint: <app name, URL or description>
---

# Add an app to the nix config

The app is whatever the user named alongside this skill. In Claude Code it
arrives here: $ARGUMENTS

You are done when the config builds with the app in it, you have seen the
generated artifact that installs it, the README manifest is in sync, the change
is committed, and the user knows every manual step left. Applying the config is
the user's move: they run `./build.sh`, which uses sudo and switches the live
machine.

## 1. Identify

Find the app's homepage and read how it recommends installing itself. Name its
kind: desktop app, CLI, background service, agent skill — or several (Codex is
both a desktop app and a CLI). Done when you can state the kind and the
recommended install in a sentence. When the request could mean things that give
the user something materially different (a desktop app versus a headless
daemon), take the conventional choice for a Mac used day to day and say so; ask
only if that choice is genuinely unclear.

## 2. Survey

Look up every channel with a real lookup — never from memory. The commands are in
[references/channels.md](references/channels.md).

| Channel | Look up |
| --- | --- |
| nixpkgs | the attribute's version in the pinned nixpkgs |
| home-manager module | `modules/programs/<name>*` in the home-manager input |
| nix-darwin service | `modules/services/<name>*` in the nix-darwin input |
| Homebrew cask, formula | `https://formulae.brew.sh/api/{cask,formula}/<name>.json` |
| dedicated flake | `nix flake show github:<owner>/<repo>` |
| npm | `https://registry.npmjs.org/<name>` — `dependencies` and `bin` |
| agent skill | `npx -y skills@latest add <source> --list` in a scratch home |

Then check the machine for an install that would collide:
`/Applications/<App>.app` (an App Store copy contains `Contents/_MASReceipt`),
`command -v <binary>`, and `launchctl list | grep -i <name>`.

Done when every channel has an answer — available or not, and at what version —
and you know what is already installed.

## 3. Choose

If the user named a method, use it, and confirm it can run unattended. Otherwise
take the first match:

1. Agent skill → `agentSkills`.
2. Desktop app → Homebrew cask. If the cask's pkg also ships the CLI, that covers
   the CLI.
3. A CLI whose nixpkgs copy lags, with a dedicated flake → flake input.
4. A CLI in nixpkgs → `home.packages`, or `programs.<name>` when home-manager has
   a module and there is config worth setting.
5. A CLI only on npm, with no runtime dependencies → local derivation.
6. Anything else → Homebrew formula.

Keep one copy of each command: when two channels both provide the same binary (a
cask and a flake both shipping `codex`), choose one. Done when you can name the
channel and the reason in one sentence.

## 4. Implement

Follow your channel's section in [references/channels.md](references/channels.md).
Each section points at a working example in this repo; match its shape. Put new
entries beside related ones, in the order the user asked for.

Two rules hold for every channel:

- Logins, tokens and macOS approvals stay manual steps for the user. Anything in
  the Nix store is readable by every user on the machine.
- A file the app also writes, such as `~/.claude/settings.json`, gets the keys you
  own merged into it. The file itself stays the app's.

## 5. Verify

1. `git add` new files — a flake only sees tracked files.
2. Build: `nix build .#darwinConfigurations.mac.system --no-link --print-out-paths`.
3. Open the artifact that installs or configures the app: the generated
   Brewfile, the generated home files, the built binary (`<store path>/bin/<binary>
   --version`), or the generated activation snippet run in a scratch home.
   Read generated config files whole; modules write more than you asked for.

Done when the build passes and you have looked at that artifact yourself.

## 6. Document

Run the `sync-manifest` skill. Done when
`.agents/skills/sync-manifest/scripts/check_manifest.py --repo . --versions` exits
0 and the README describes every manual step.

## 7. Commit and report

Make one commit with the config, the README and any new files; AGENTS.md wants
the manifest to change in the same commit as the config. Leave pushing to the
user. Then report: what was added, the channel and why, what you verified, and
the manual steps in order — `./build.sh` first, then any login or approval.
