#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# ln -sfn "$DIR" ~/.nix-config

# Resolve any new flake inputs as the invoking user first. The sudo below runs nix
# as root, so without this a new input gets its lock entry written by root - and
# then updating flake.lock next time needs sudo too.
nix flake lock "$DIR"

sudo nix run nix-darwin -- switch --flake "$DIR#mac"
