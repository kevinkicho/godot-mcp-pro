#!/usr/bin/env python3
"""Run all offline tool-surface validation (no Godot required)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

TESTS = Path(__file__).resolve().parent
ROOT = TESTS.parent


def run(label: str, args: list[str]) -> int:
    print("\n" + "=" * 60)
    print(label)
    print("=" * 60)
    r = subprocess.run(args, cwd=str(ROOT))
    return r.returncode


def main() -> int:
    py = sys.executable
    codes = []
    codes.append(run("1/3 Generate catalog + specs", [py, str(TESTS / "generate_catalog.py")]))
    codes.append(run("2/3 Structural integrity", [py, str(TESTS / "structural" / "test_surface_integrity.py")]))
    codes.append(run("3/3 Static smoke contracts", [py, str(TESTS / "smoke" / "run_static_smoke.py")]))
    failed = [c for c in codes if c != 0]
    print("\n" + "=" * 60)
    if failed:
        print(f"FAILED ({len(failed)} step(s))")
        return 1
    print("ALL STATIC TOOL SURFACE TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
