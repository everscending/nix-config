#!/usr/bin/env bash
# Update flake inputs, carry the new version numbers into the README manifest, and
# commit both. With no arguments every input is updated; name inputs to update
# only those:
#
#   ./update.sh                    # everything
#   ./update.sh claude-code-nix    # just Claude Code
#
# This only changes the lock - run ./build.sh afterwards to apply it.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR"

CHECK=.agents/skills/sync-manifest/scripts/check_manifest.py

# The commit should contain exactly what the update changed, so refuse to run over
# hand edits to the two files it commits.
if ! git diff --quiet HEAD -- flake.lock README.md; then
  echo "flake.lock or README.md has uncommitted changes; commit or stash them first." >&2
  exit 1
fi

update_log="$(nix flake update "$@" 2>&1)"
printf '%s\n' "$update_log" >&2

if git diff --quiet HEAD -- flake.lock; then
  echo "Already up to date; nothing to commit."
  exit 0
fi

# AGENTS.md wants the manifest updated in the same commit as the lock. Version
# numbers are the only thing an update can move, and the checker rewrites those.
if ! fix_log="$(python3 "$CHECK" --repo . --fix-versions)"; then
  printf '%s\n' "$fix_log" >&2
  echo >&2
  echo "The manifest still drifts after fixing versions, so nothing was committed." >&2
  echo "flake.lock is updated; fix README.md (see the sync-manifest skill) and commit," >&2
  echo "or discard the update with: git checkout -- flake.lock README.md" >&2
  exit 1
fi
printf '%s\n' "$fix_log"

updated="$(printf '%s\n' "$update_log" | sed -n "s/^• Updated input '\([^']*\)'.*/\1/p" | paste -sd, - | sed 's/,/, /g')"
versions="$(printf '%s\n' "$fix_log" | sed -n 's/^fixed: /- /p')"

msg="Update flake inputs: ${updated:-lock refreshed}"
if [ -n "$versions" ]; then
  msg="$msg

Manifest versions:
$versions"
fi

# Pathspec commit: only these two files, whatever else happens to be staged.
git commit -q -m "$msg" -- flake.lock README.md
git log -1 --stat --format='%h %s' | cat
echo
echo "Committed. Run ./build.sh to apply."
