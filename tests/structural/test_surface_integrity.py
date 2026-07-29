#!/usr/bin/env python3
"""Structural integrity tests for the full plugin tool surface.

Does NOT require Godot. Validates that every registered command:
  - has a unique name across modules
  - has a matching handler function in its module
  - is discoverable from *_commands.gd
  - matches catalog counts
  - has a generated spec entry
"""
from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = Path(__file__).resolve().parents[1]
COMMANDS = ROOT / "addons" / "godot_mcp" / "commands"
CATALOG = TESTS / "catalog" / "tool_catalog.json"
SPECS = TESTS / "catalog" / "tool_specs.json"
SUMMARY = TESTS / "catalog" / "summary.json"
REGISTRY = ROOT / "SURFACE_REGISTRY.md"
PLUGIN = ROOT / "addons" / "godot_mcp" / "plugin.cfg"

CMD_KEY_RE = re.compile(r'^\s*"([a-z0-9_]+)":\s*(_[a-zA-Z0-9_]+)\s*,?\s*$', re.M)
FUNC_RE = re.compile(r"^func\s+(_[a-zA-Z0-9_]+)\s*\(", re.M)


def ensure_catalog() -> None:
    gen = TESTS / "generate_catalog.py"
    # Always regenerate for freshness
    import subprocess
    r = subprocess.run([sys.executable, str(gen)], cwd=str(ROOT), capture_output=True, text=True)
    if r.returncode not in (0, 1):
        raise RuntimeError(f"catalog generator failed:\n{r.stdout}\n{r.stderr}")


class SurfaceIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ensure_catalog()
        cls.catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        cls.specs = json.loads(SPECS.read_text(encoding="utf-8"))
        cls.summary = json.loads(SUMMARY.read_text(encoding="utf-8"))
        cls.tools = cls.catalog["tools"]
        cls.by_name = {}
        for t in cls.tools:
            cls.by_name.setdefault(t["name"], []).append(t)

    def test_catalog_nonempty(self) -> None:
        self.assertGreater(len(self.tools), 1000, "expected full production surface")

    def test_plugin_version_present(self) -> None:
        self.assertTrue(self.catalog.get("plugin_version"))
        cfg = PLUGIN.read_text(encoding="utf-8")
        self.assertIn(self.catalog["plugin_version"], cfg)

    def test_every_module_has_get_commands(self) -> None:
        missing = []
        for p in COMMANDS.rglob("*_commands.gd"):
            text = p.read_text(encoding="utf-8", errors="replace")
            if "func get_commands" not in text:
                missing.append(str(p))
        self.assertEqual(missing, [], f"modules missing get_commands: {missing}")

    def test_every_registration_has_handler(self) -> None:
        missing = [t for t in self.tools if not t["handler_exists"]]
        self.assertEqual(
            missing,
            [],
            "handlers missing for: " + ", ".join(t["name"] for t in missing[:50]),
        )

    def test_no_duplicate_command_names(self) -> None:
        dups = {k: v for k, v in self.by_name.items() if len(v) > 1}
        # Allow documenting duplicates but fail integrity
        if dups:
            detail = {k: [x["path"] for x in v] for k, v in list(dups.items())[:30]}
            self.fail(f"Duplicate command registrations ({len(dups)}): {json.dumps(detail, indent=2)}")

    def test_handler_functions_exist_on_disk(self) -> None:
        bad = []
        for t in self.tools:
            path = ROOT / t["path"]
            text = path.read_text(encoding="utf-8", errors="replace")
            funcs = set(FUNC_RE.findall(text))
            if t["handler"] not in funcs:
                bad.append(f"{t['name']} -> {t['handler']} in {t['path']}")
        self.assertEqual(bad, [], "missing funcs:\n" + "\n".join(bad[:40]))

    def test_every_tool_has_spec(self) -> None:
        spec_tools = self.specs.get("tools", {})
        missing = [t["name"] for t in self.tools if t["name"] not in spec_tools]
        self.assertEqual(missing, [], f"specs missing for {len(missing)} tools e.g. {missing[:20]}")

    def test_spec_has_assertions(self) -> None:
        for name, spec in self.specs["tools"].items():
            self.assertIn("assertions", spec, name)
            self.assertIn("returns_dict_envelope", spec["assertions"])
            self.assertIn("smoke_kind", spec)
            self.assertIn("risk", spec)

    def test_registry_md_mentions_tool_count(self) -> None:
        if not REGISTRY.exists():
            self.skipTest("SURFACE_REGISTRY.md missing")
        text = REGISTRY.read_text(encoding="utf-8")
        # Registry should mention plugin version and command count section
        self.assertIn("Registered plugin commands", text)
        self.assertIn(self.catalog["plugin_version"], text)

    def test_registry_lists_most_tools(self) -> None:
        """Registry should list the vast majority of tools (backtick-wrapped)."""
        if not REGISTRY.exists():
            self.skipTest("SURFACE_REGISTRY.md missing")
        text = REGISTRY.read_text(encoding="utf-8")
        listed = set(re.findall(r"`([a-z0-9_]+)`", text))
        names = {t["name"] for t in self.tools}
        missing = sorted(names - listed)
        # allow a few false positives from non-tool backticks but missing tools is a fail
        coverage = 1.0 - (len(missing) / max(len(names), 1))
        self.assertGreaterEqual(
            coverage,
            0.95,
            f"Registry missing {len(missing)} tools ({coverage:.1%} coverage). Sample: {missing[:25]}",
        )

    def test_list_tools_are_low_risk(self) -> None:
        bad = []
        for t in self.tools:
            if t["is_list_like"] and t["risk"] == "high":
                bad.append(t["name"])
        self.assertEqual(bad, [], f"list-like tools marked high risk: {bad}")

    def test_smoke_params_skip_destructive(self) -> None:
        for t in self.tools:
            if t["smoke_kind"] == "destructive_gated":
                self.assertTrue(t["smoke_params"].get("__skip__"), t["name"])

    def test_domains_nonempty(self) -> None:
        self.assertGreaterEqual(self.summary["domains"], 15)

    def test_summary_integrity_flag(self) -> None:
        # This is the gate for CI green
        dups = self.catalog["totals"]["duplicates"]
        missing = self.catalog["totals"]["missing_handlers"]
        self.assertEqual(missing, 0, f"missing handlers: {missing}")
        # Duplicates fail hard — they overwrite at runtime
        self.assertEqual(dups, 0, f"duplicate command names: {dups} -> {self.catalog.get('duplicates')}")

    def test_name_charset(self) -> None:
        bad = [t["name"] for t in self.tools if not re.fullmatch(r"[a-z][a-z0-9_]*", t["name"])]
        self.assertEqual(bad, [], f"invalid tool names: {bad[:20]}")

    def test_modules_extend_base_command(self) -> None:
        bad = []
        for p in COMMANDS.rglob("*_commands.gd"):
            text = p.read_text(encoding="utf-8", errors="replace")
            if "base_command.gd" not in text and "extends" in text:
                # still require extends something
                if "extends" not in text.splitlines()[1] if len(text.splitlines()) > 1 else True:
                    pass
            if "base_command.gd" not in text:
                bad.append(str(p.relative_to(ROOT)))
        # soft: report but most should extend base
        ratio = 1.0 - len(bad) / max(len(list(COMMANDS.rglob("*_commands.gd"))), 1)
        self.assertGreaterEqual(ratio, 0.95, f"modules not extending base_command ({len(bad)}): {bad[:15]}")


class CatalogFreshnessTests(unittest.TestCase):
    def test_regenerate_and_compare_counts(self) -> None:
        ensure_catalog()
        summary = json.loads(SUMMARY.read_text(encoding="utf-8"))
        # Live recount
        total = 0
        for p in COMMANDS.rglob("*_commands.gd"):
            text = p.read_text(encoding="utf-8", errors="replace")
            total += len(CMD_KEY_RE.findall(text))
        self.assertEqual(summary["tools"], total)


def main() -> int:
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(SurfaceIntegrityTests))
    suite.addTests(loader.loadTestsFromTestCase(CatalogFreshnessTests))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
