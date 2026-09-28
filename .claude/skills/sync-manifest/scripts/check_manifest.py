#!/usr/bin/env python3
"""Report drift between the nix config and the manifest in README.md.

Read-only by design: this prints findings and changes nothing. Fixing the README
needs judgement about prose that a script would only flatten, so the script
handles the part that is mechanical (which names and versions disagree) and
leaves the writing to you.

Usage:
    python3 check_manifest.py [--repo DIR] [--versions]

--versions additionally resolves each Nix package's real version out of the
pinned nixpkgs and compares it to the version written in the README. It shells
out to `nix eval`, so it takes a few seconds; without it the script only
compares names, which is instant.

Exit status is 0 when the manifest agrees with the config and 1 when it drifts,
so this is usable from a hook or CI later if that's ever wanted.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

# Each Nix source maps to the README table that is supposed to mirror it.
# Headings are matched by substring so small edits to the wording don't break
# the check; if you retitle a section, update the fragment here too.
SECTIONS = [
    ("home.packages", "Languages and CLI tools"),
    ("brews", "CLI tools — Homebrew"),
    ("casks", "GUI apps — Homebrew casks"),
]

# Packages documented in prose rather than in a table row, so a missing table
# row for them is expected rather than drift.
PROSE_DOCUMENTED = re.compile(r"^nerd-fonts\b")


def read(path: Path) -> str:
    try:
        return path.read_text()
    except FileNotFoundError:
        sys.exit(f"error: {path} not found — is --repo pointing at the nix config?")


def nix_list_block(text: str, opener: re.Pattern) -> list[str]:
    """Return the raw lines inside the first `... = [ ... ];` block that matches."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if opener.search(line):
            body = []
            for rest in lines[i + 1:]:
                if rest.strip() in ("];", "]"):
                    return body
                body.append(rest)
            break
    return []


def parse_home_packages(text: str) -> tuple[list[str], list[str]]:
    """Return (active, commented-out) package attribute names from home.packages.

    Commented-out entries matter because the README documents them in a
    sentence of their own — uncommenting one should move it into the table.
    """
    body = nix_list_block(text, re.compile(r"home\.packages\s*=\s*with\s+pkgs;\s*\["))
    active, commented = [], []
    for line in body:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            # A commented package looks like `#ripgrep   # fast search`;
            # a prose comment like `# the font everything renders in` does not.
            candidate = stripped.lstrip("#").strip().split("#")[0].strip()
            if re.fullmatch(r"[A-Za-z0-9_.\-]+", candidate) and " " not in candidate:
                commented.append(candidate)
            continue
        name = stripped.split("#")[0].strip()
        if name:
            active.append(name)
    return active, commented


def parse_quoted_list(text: str, key: str) -> list[str]:
    body = nix_list_block(text, re.compile(rf"\b{key}\s*=\s*\["))
    names = []
    for line in body:
        if line.strip().startswith("#"):
            continue
        names.extend(re.findall(r'"([^"]+)"', line))
    return names


def readme_section(text: str, fragment: str) -> list[str] | None:
    """Return the lines of the section whose heading contains `fragment`."""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("#") and fragment in line:
            start = i + 1
            break
    if start is None:
        return None
    out = []
    for line in lines[start:]:
        if line.startswith("#"):
            break
        out.append(line)
    return out


def table_rows(lines: list[str]) -> list[tuple[str, str]]:
    """Return (first cell, second cell) for each data row of a markdown table."""
    rows = []
    for line in lines:
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not cells or set(cells[0]) <= set("- :"):
            continue  # separator row
        first = cells[0].strip("`").strip()
        if first.lower() in ("package", "cask", "variable", "file", "tool"):
            continue  # header row
        second = cells[1].strip("`").strip() if len(cells) > 1 else ""
        rows.append((first, second))
    return rows


def resolve_versions(repo: Path, names: list[str]) -> dict[str, str | None]:
    """Ask the pinned nixpkgs for each package's real version.

    Uses the flake's own nixpkgs input rather than whatever channel happens to
    be on the machine, because the README documents what a rebuild of *this*
    config installs. currentSystem keeps it working on Intel as well as ARM.
    """
    expr = """
    let
      flake = builtins.getFlake (toString %s);
      pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
      at = name: builtins.foldl' (acc: k: if acc == null then null else acc.${k} or null)
             pkgs (pkgs.lib.splitString "." name);
      version = name: let p = at name; in if p == null then null else (p.version or null);
    in builtins.toJSON (builtins.listToAttrs
         (map (n: { name = n; value = version n; }) %s))
    """ % (json.dumps(str(repo)),
           "[ " + " ".join(json.dumps(n) for n in names) + " ]")
    try:
        out = subprocess.run(
            ["nix", "eval", "--raw", "--impure", "--expr", expr],
            capture_output=True, text=True, timeout=300, cwd=repo,
        )
    except FileNotFoundError:
        print("  ! nix not on PATH; skipping version check\n", file=sys.stderr)
        return {}
    if out.returncode != 0:
        tail = out.stderr.strip().splitlines()[-3:]
        print("  ! could not evaluate versions:", " / ".join(tail), file=sys.stderr)
        return {}
    return json.loads(out.stdout)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".", help="path to the nix config repo")
    ap.add_argument("--versions", action="store_true",
                    help="also check versions against the pinned nixpkgs (slower)")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    home = read(repo / "home.nix")
    config = read(repo / "configuration.nix")
    readme = read(repo / "README.md")

    active, commented = parse_home_packages(home)
    in_nix = {
        "home.packages": [p for p in active if not PROSE_DOCUMENTED.match(p)],
        "brews": parse_quoted_list(config, "brews"),
        "casks": parse_quoted_list(config, "casks"),
    }

    problems = []

    for key, fragment in SECTIONS:
        lines = readme_section(readme, fragment)
        if lines is None:
            problems.append(f"README has no section matching {fragment!r} "
                            f"(expected it to mirror {key})")
            continue
        documented = {name for name, _ in table_rows(lines)}
        declared = set(in_nix[key])
        for name in sorted(declared - documented):
            problems.append(f"{name} — in {key} but missing from the "
                            f"'{fragment}' table")
        for name in sorted(documented - declared):
            problems.append(f"{name} — in the '{fragment}' table but not in "
                            f"{key}; remove the row or re-add the package")

    # Packages present but commented out live in a sentence, not a table.
    prose = next((l for l in readme.splitlines() if "commented out" in l), None)
    if commented and prose is None:
        problems.append("home.nix has commented-out packages "
                        f"({', '.join(commented)}) but README never mentions them")
    elif prose is not None:
        mentioned = set(re.findall(r"`([^`]+)`", prose)) - {"home.nix"}
        for name in sorted(set(commented) - mentioned):
            problems.append(f"{name} — commented out in home.nix but not named "
                            "in the README's commented-out sentence")
        for name in sorted(mentioned - set(commented)):
            problems.append(f"{name} — README calls it commented out, but it is "
                            "not a commented entry in home.packages")

    # Homebrew versions move on their own, so documenting them guarantees a lie.
    for key, fragment in (("brews", "CLI tools — Homebrew"),
                          ("casks", "GUI apps — Homebrew casks")):
        lines = readme_section(readme, fragment) or []
        for name, second in table_rows(lines):
            if re.fullmatch(r"v?\d+(\.\d+)+", second):
                problems.append(f"{name} — the '{fragment}' table lists version "
                                f"{second}; Homebrew packages are unpinned, so "
                                "describe them instead of versioning them")

    versions_checked = False
    if args.versions:
        nix_names = sorted(set(active))
        real = resolve_versions(repo, nix_names)
        if real:
            versions_checked = True
            lines = readme_section(readme, "Languages and CLI tools") or []
            for name, written in table_rows(lines):
                actual = real.get(name)
                if actual is None:
                    problems.append(f"{name} — documented but not a package in "
                                    "the pinned nixpkgs; check the attribute name")
                elif written and written != actual:
                    problems.append(f"{name} — README says {written}, pinned "
                                    f"nixpkgs has {actual}")
            for name in nix_names:
                if PROSE_DOCUMENTED.match(name) and real.get(name):
                    if real[name] not in readme:
                        problems.append(f"{name} — version {real[name]} does not "
                                        "appear in the README's font section")

    if args.versions and not versions_checked:
        print("  ! versions were NOT checked (see above)\n", file=sys.stderr)

    if problems:
        print(f"manifest drift ({len(problems)} issue"
              f"{'s' if len(problems) != 1 else ''}):\n")
        for p in problems:
            print(f"  - {p}")
        print("\nUpdate README.md so each section matches the config, then re-run.")
        return 1

    checked = sum(len(v) for v in in_nix.values())
    print(f"manifest is in sync ({checked} packages"
          f"{', versions checked' if args.versions else ''}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
