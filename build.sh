#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# ln -sfn "$DIR" ~/.nix-config
sudo nix run nix-darwin -- switch --flake $DIR#mac
