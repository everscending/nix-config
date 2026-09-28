#!/usr/bin/env python3
"""Point Claude Code's statusLine at ccstatusline, without disturbing anything else.

Called from home-manager activation in home.nix. ~/.claude/settings.json is a
file Claude Code writes and the user edits by hand, so this merges a couple of
keys into it rather than owning the file:

  - `type` and `command` are set, because where the binary lives is exactly what
    Nix knows and the user should not have to restate.
  - every other key is left untouched, including cosmetic statusLine keys such as
    `padding` and `refreshInterval` that ccstatusline's own TUI manages, and
    unrelated top-level keys such as `hooks` and `theme`.

A malformed settings.json is left alone with a warning rather than replaced.
Losing someone's hooks to a rebuild would be a poor trade for a status line, and
the activation exits 0 either way so a broken file cannot abort the whole switch.

Usage: claude-statusline.py <settings.json path> <ccstatusline command>
"""

import json
import os
import sys
import tempfile


def warn(msg: str) -> None:
    print(f"warning: statusLine not configured: {msg}", file=sys.stderr)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        warn(f"expected 2 arguments, got {len(argv) - 1}")
        return 0
    path, command = argv[1], argv[2]

    settings: dict = {}
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                settings = json.load(f)
        except json.JSONDecodeError as e:
            warn(f"{path} is not valid JSON ({e}); leaving it untouched")
            return 0
        except OSError as e:
            warn(f"could not read {path} ({e})")
            return 0
        if not isinstance(settings, dict):
            warn(f"{path} holds {type(settings).__name__}, not an object; "
                 "leaving it untouched")
            return 0

    existing = settings.get("statusLine")
    status_line = dict(existing) if isinstance(existing, dict) else {}
    before = dict(status_line)

    status_line["type"] = "command"
    status_line["command"] = command

    if status_line == before and isinstance(existing, dict):
        return 0  # already correct; don't rewrite the file for nothing

    settings["statusLine"] = status_line

    # Write through a temp file in the same directory so an interrupted
    # activation cannot leave a truncated settings.json behind.
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".",
                                   prefix=".settings.json.")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(settings, f, indent=2)
                f.write("\n")
            os.replace(tmp, path)
        except BaseException:
            os.unlink(tmp)
            raise
    except OSError as e:
        warn(f"could not write {path} ({e})")
        return 0

    verb = "updated" if existing is not None else "added"
    print(f"{verb} statusLine in {path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
