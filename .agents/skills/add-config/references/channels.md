# Channels

A **channel** is one way software reaches this machine through the config. Each
section says where the channel lives, points at a working example in this repo
(match its shape), and covers both adding and removing. Read only the section
for the channel you chose.

Lookups below use the flake's own pins, not whatever is on `PATH`:

```bash
# version of a nixpkgs attribute, from the pinned nixpkgs
nix eval --raw --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; in p.<attr>.version'
# source tree of an input (home-manager, nix-darwin), to read module code
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.<input>.outPath'
# the generated home-manager files and activate script
nix eval --raw .#darwinConfigurations.mac.config.home-manager.users.$(nix eval --raw .#darwinConfigurations.mac.config.system.primaryUser).home.activationPackage
```

## Homebrew cask

Desktop apps. Lives in `homebrew.casks` in `configuration.nix` (`codex-app`,
`tailscale-app`).

**Add:** append the cask name, with a short comment when the reason isn't obvious.
Read the cask from `https://formulae.brew.sh/api/cask/<name>.json` first:
`caveats` lists manual steps (extension approvals, licences), `artifacts` shows
whether its pkg also installs a CLI (`tailscale-app` puts `tailscale` in
`/usr/local/bin`), and `auto_updates` means the app updates itself. The cask name
often differs from the app name — try `<name>-app` too; `codex` is the CLI cask,
`codex-app` the desktop app. Verify by reading the generated Brewfile:
`grep '^cask' $(grep -o '/nix/store/[a-z0-9]*-Brewfile' <system>/activate | head -1)`.

**Remove:** delete the entry. `homebrew.onActivation.cleanup = "zap"` then
uninstalls it on the next build *and* runs the cask's `zap` stanza, which trashes
every path it lists. Read that list from the API and tell the user exactly what
goes. Data shared with another tool matters most (`codex-app`'s zap only
`rmdir`s `~/.codex`, so the Codex CLI's config survives).

## Homebrew formula

CLIs only Homebrew carries. Lives in `homebrew.brews` (`herdr`). Same shape and
same zap behaviour as casks; API at `.../api/formula/<name>.json`.

## nixpkgs package

CLIs and libraries in nixpkgs. Lives in `home.packages` in `home.nix` (`uv`,
`pnpm`). Use the default attribute (`python3`, `nodejs`) unless the user wants a
major pinned (`python314`).

**Remove:** delete the entry; the next build drops it from the profile. First
grep for `pkgs.<attr>` elsewhere — other parts of the config may use the package
by store path (`pkgs.nodejs` runs ccstatusline and the agent-skills installer).

## home-manager module

A CLI that home-manager can also configure. Lives as `programs.<name>` in
`home.nix` (`programs.gh`). Prefer it over a bare package when there is config
worth setting. Read the module source under the home-manager input's
`modules/programs/` before trusting it: options can quietly depend on another
module (gh's git credential helper is written only when `programs.git` is
enabled), and enabling one can switch on defaults keyed to `home.stateVersion`
(`programs.git` turned on GnuPG signing). Read every file it generates.

**Remove:** delete the block; home-manager removes the files it managed. If a
supporting module was enabled only for this one (`programs.git` for gh), remove
it too — after checking nothing else needs it.

## Dedicated flake

Fast-moving CLIs whose nixpkgs copy lags. Lives as a `flake.nix` input plus a
`let` binding in `home.nix` (`claude-code-nix`, `codex-cli-nix`).

**Add:**
1. Inspect it: `nix flake show github:<owner>/<repo>` for outputs, and its
   `flake.nix` for its own nixpkgs pin.
2. Add the input *without* `inputs.nixpkgs.follows`: overriding nixpkgs changes
   the derivation hash, so the project's binary cache misses, and upstream only
   tests its own pin.
3. Add the input's name to the `outputs = inputs@{ ... }` pattern. It has no
   `...`, so an unnamed input is an evaluation error.
4. Bind it in `home.nix`'s `let`:
   `inputs.<input>.packages.${pkgs.stdenv.hostPlatform.system}.default`, then list
   the binding in `home.packages`.
5. `nix flake lock`, then confirm no existing `rev` in `flake.lock` changed. A
   renamed node (`nixpkgs` → `nixpkgs_2`) with the same `rev` is fine.

These packages usually disable the tool's self-updater, so updates go through
`./update.sh <input>`; tell the user.

If `flake.lock` isn't writable (owned by root), stop and ask the user. Generating
a lock from scratch moves every pin.

**Remove:** the input, its name in the outputs pattern, the binding, the package
entry; then `nix flake lock` drops its nodes.

## Local derivation

Software in no other channel. A `<name>.nix` file called with
`pkgs.callPackage ./<name>.nix { }` in `home.nix`'s `let` (`ccstatusline.nix`).
For an npm package with no runtime `dependencies`: fetch the registry tarball,
use npm's `integrity` value directly as `hash` (it is already SRI), and wrap the
entry script with `makeWrapper` around `lib.getExe nodejs`. Note at the top of the
file how to bump it, since a channel update never will.

**Remove:** delete the file, the binding and the package entry.

## Agent skill

Skills for Claude Code and Codex. Lives in the `agentSkills` list in `home.nix`,
installed by `home.activation.agentSkills` into `~/.agents/skills` (Codex reads it
directly) with links in `~/.claude/skills`. Each entry is a `skills add` source;
narrow it with `args`, such as `[ "--skill" "<name>" ]`. Check what a source
contains first, in a scratch home: `npx -y skills@latest add <source> --list`.

**Remove:** delete the entry. That does **not** uninstall it: the files stay in
`~/.agents/skills`, and the source stays in `~/.agents/.skill-lock.json`. Uninstall
with `npx skills remove -g -y -s <skill>...`, which touches the real home folder,
so hand the command to the user or get their go-ahead first.

## Activation step

Setup no package can express: merging settings into a file the app also writes,
running an installer. Lives as `home.activation.<name>` in `home.nix`
(`claudeStatusLine`, `agentSkills`). A step must be:

- **ordered** — `lib.hm.dag.entryAfter` naming every step it relies on. All steps
  already run after the Homebrew bundle.
- **idempotent** — a rerun changes nothing; skip work already done.
- **unattended** — `-y`-style flags, stdin from `/dev/null`.
- **non-fatal** — warn and carry on; one failed step must not stop the switch.
- **self-contained** — tools by store path (`${pkgs.nodejs}/bin`), not `PATH`;
  side effects wrapped in `run` so dry runs skip them; `cd ~` before tools that
  look at the working directory.

**Merge, never replace,** any file the app or user also writes. Set only the keys
you own, leave malformed files alone with a warning, and write atomically
(`claude-statusline.py`).

**Test the generated snippet**, not your source. Take the lines between the step's
`_iNote "Activating %s"` marker and the next one in the generated `activate`
script, point `/Users/<user>` at a scratch home, and run it with `env -i`. Cover a
first run, a rerun, and a failure. A simple `run` stub is
`run() { "$@"; }; verboseEcho() { echo "$*"; }`.

**Remove:** delete the step. That does not undo what it already did; clean up its
leftovers separately (settings keys, installed files) or hand the user the
commands.
