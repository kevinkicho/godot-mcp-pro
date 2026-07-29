#!/usr/bin/env python3
"""Fix UTF-8 mojibake (chars mis-decoded as CP1252) in command modules."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "addons" / "godot_mcp" / "commands"

# Proper Unicode -> ASCII-safe replacements for comments/strings
UNICODE_TO_ASCII = {
    "\u2014": "-",  # em dash
    "\u2013": "-",  # en dash
    "\u2026": "...",  # ellipsis
    "\u201c": '"',
    "\u201d": '"',
    "\u2018": "'",
    "\u2019": "'",
    "\u2194": "<->",  # left-right arrow
    "\u2192": "->",
    "\u2190": "<-",
    "\u00a0": " ",
    "\u00b7": "*",
    "\u2713": "OK",
    "\u2717": "X",
}


def mojibake_cp1252(ch: str) -> str | None:
    try:
        return ch.encode("utf-8").decode("cp1252")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None


def build_replacements() -> list[tuple[str, str]]:
    repls: list[tuple[str, str]] = []
    for ch, ascii_r in UNICODE_TO_ASCII.items():
        repls.append((ch, ascii_r))
        m = mojibake_cp1252(ch)
        if m and m != ch:
            repls.append((m, ascii_r))
    # Sort longest first so multi-byte mojibake wins
    repls.sort(key=lambda x: len(x[0]), reverse=True)
    return repls


def main() -> None:
    repls = build_replacements()
    fixed = 0
    for path in sorted(ROOT.rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        orig = text
        for old, new in repls:
            if old in text:
                text = text.replace(old, new)
        if text != orig:
            path.write_text(text, encoding="utf-8", newline="\n")
            print(f"fixed: {path.relative_to(ROOT)}")
            fixed += 1
    print(f"total fixed: {fixed}")

    still = []
    for path in ROOT.rglob("*.gd"):
        t = path.read_text(encoding="utf-8")
        for i, line in enumerate(t.splitlines(), 1):
            if any(ord(c) > 127 for c in line):
                codes = " ".join(f"U+{ord(c):04X}" for c in line if ord(c) > 127)
                still.append(f"{path.relative_to(ROOT)}:{i}: {codes}")
    if still:
        print("remaining non-ASCII lines:")
        for s in still[:40]:
            print(" ", s)
        print(f"  ... total {len(still)}")
    else:
        print("all command modules are ASCII-clean")


if __name__ == "__main__":
    main()
