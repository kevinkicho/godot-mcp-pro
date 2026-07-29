@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Export CI templates - GitHub Actions, export preset packs, headless export scripts.


func get_commands() -> Dictionary:
	return {
		"list_export_ci_templates": _list_templates,
		"create_github_actions_godot_export": _create_gha,
		"create_export_presets_pack": _create_presets_pack,
		"create_headless_export_script": _create_headless,
		"write_export_ci_readme": _write_readme,
		"list_export_ci_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"create_export_preset", "run_export", "verify_export_ready",
			"get_export_signing_checklist", "pipeline_pre_ship_check",
		],
	})


func _list_templates(_params: Dictionary) -> Dictionary:
	return success({
		"templates": {
			"github_actions_export": "create_github_actions_godot_export - Windows/Linux/Web matrix",
			"export_presets_pack": "create_export_presets_pack - desktop+web presets in export_presets.cfg",
			"headless_export_script": "create_headless_export_script - local .ps1/.sh export helpers",
			"ci_readme": "write_export_ci_readme - agent checklist",
		},
		"note": "CI cannot install proprietary console SDKs; Android signing needs secrets",
	})


func _create_gha(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://../.github/workflows/godot-export.yml")
	# Prefer writing next to project: user often wants .github at project root
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var out_path: String = optional_string(params, "output_path", "")
	if out_path.is_empty():
		out_path = project_root.path_join(".github/workflows/godot-export.yml")
	elif out_path.begins_with("res://"):
		out_path = ProjectSettings.globalize_path(out_path)

	var godot_version: String = optional_string(params, "godot_version", "4.3-stable")
	var platforms: Array = params.get("platforms", ["windows", "linux", "web"])
	if not platforms is Array:
		platforms = ["windows", "linux", "web"]

	var matrix_os := []
	var include_blocks := []
	for p in platforms:
		match str(p).to_lower():
			"windows", "win":
				matrix_os.append("windows-latest")
				include_blocks.append("          - platform: windows\n            os: windows-latest\n            preset: \"Windows Desktop\"\n            path: build/windows/game.exe")
			"linux":
				matrix_os.append("ubuntu-latest")
				include_blocks.append("          - platform: linux\n            os: ubuntu-latest\n            preset: \"Linux/X11\"\n            path: build/linux/game.x86_64")
			"web", "html5":
				matrix_os.append("ubuntu-latest")
				include_blocks.append("          - platform: web\n            os: ubuntu-latest\n            preset: \"Web\"\n            path: build/web/index.html")
			"android":
				matrix_os.append("ubuntu-latest")
				include_blocks.append("          - platform: android\n            os: ubuntu-latest\n            preset: \"Android\"\n            path: build/android/game.apk")

	var yml := """name: Godot Export

on:
  push:
    branches: [ main, master ]
  pull_request:
  workflow_dispatch:

env:
  GODOT_VERSION: %s

jobs:
  export:
    name: Export ${{ matrix.platform }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
%s

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v2
        with:
          version: ${{ env.GODOT_VERSION }}
          use-dotnet: false

      - name: Import project
        run: godot --headless --path . --import || true

      - name: Export
        run: |
          mkdir -p "$(dirname "${{ matrix.path }}")"
          godot --headless --path . --export-release "${{ matrix.preset }}" "${{ matrix.path }}"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: game-${{ matrix.platform }}
          path: build/**
          if-no-files-found: warn
""" % [godot_version, "\n".join(PackedStringArray(include_blocks))]

	# Ensure directory
	var parent_dir := out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		# Fallback to res://ci/
		var fallback := "res://ci/godot-export.yml"
		var vr := validate_res_path(fallback)
		if vr[1] != null:
			return error_internal("Cannot write workflow to %s" % out_path)
		var derr := ensure_parent_dir(vr[0])
		if not derr.is_empty():
			return derr
		f = FileAccess.open(ProjectSettings.globalize_path(vr[0]), FileAccess.WRITE)
		if f == null:
			return error_internal("Cannot write workflow")
		out_path = ProjectSettings.globalize_path(vr[0])
	f.store_string(yml)
	f.close()
	return success({
		"path": out_path,
		"godot_version": godot_version,
		"platforms": platforms,
		"hint": "Ensure export_presets.cfg presets match matrix preset names; add export templates on runner",
	})


func _create_presets_pack(params: Dictionary) -> Dictionary:
	## Create/merge common export presets via existing create_export_preset router calls.
	var platforms: Array = params.get("platforms", ["Windows Desktop", "Linux/X11", "Web"])
	if not platforms is Array:
		platforms = ["Windows Desktop", "Linux/X11", "Web"]
	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No router")
	var results: Array = []
	var base_out: String = optional_string(params, "output_dir", "res://build")
	for p in platforms:
		var pname := str(p)
		var platform_key := pname
		var export_path := base_out
		match pname.to_lower():
			"windows desktop", "windows", "win":
				platform_key = "Windows Desktop"
				export_path = base_out.path_join("windows/game.exe")
			"linux/x11", "linux":
				platform_key = "Linux/X11"
				export_path = base_out.path_join("linux/game.x86_64")
			"web", "html5":
				platform_key = "Web"
				export_path = base_out.path_join("web/index.html")
			"android":
				platform_key = "Android"
				export_path = base_out.path_join("android/game.apk")
			"macos", "mac osx", "mac":
				platform_key = "macOS"
				export_path = base_out.path_join("macos/game.zip")
		var r = await router.execute("create_export_preset", {
			"name": platform_key,
			"platform": platform_key,
			"export_path": export_path,
			"runnable": optional_bool(params, "runnable", true),
		})
		results.append({"platform": platform_key, "export_path": export_path, "result": r})
	return success({
		"presets": results,
		"count": results.size(),
		"hint": "Open Project > Export to attach export templates; then run_export",
	})


func _create_headless(params: Dictionary) -> Dictionary:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var ps1_path := project_root.path_join("scripts/export-release.ps1")
	var sh_path := project_root.path_join("scripts/export-release.sh")
	if optional_bool(params, "use_res_path", false):
		ps1_path = ProjectSettings.globalize_path("res://scripts/export-release.ps1")
		sh_path = ProjectSettings.globalize_path("res://scripts/export-release.sh")

	var godot_bin: String = optional_string(params, "godot_bin", "godot")
	var preset: String = optional_string(params, "preset", "Windows Desktop")
	var out: String = optional_string(params, "export_path", "build/game.exe")

	var ps1 := """# Headless Godot export (Windows PowerShell)
param(
  [string]$Godot = "%s",
  [string]$Preset = "%s",
  [string]$Output = "%s",
  [string]$Project = "."
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path (Split-Path $Output) | Out-Null
& $Godot --headless --path $Project --import
if ($LASTEXITCODE -ne 0) { Write-Warning "import exit $LASTEXITCODE" }
& $Godot --headless --path $Project --export-release $Preset $Output
if ($LASTEXITCODE -ne 0) { throw "export failed: $LASTEXITCODE" }
Write-Host "Exported $Output"
""" % [godot_bin, preset, out]

	var sh := """#!/usr/bin/env bash
# Headless Godot export (Linux/macOS)
set -euo pipefail
GODOT="${GODOT:-%s}"
PRESET="${PRESET:-%s}"
OUTPUT="${OUTPUT:-%s}"
PROJECT="${PROJECT:-.}"
mkdir -p "$(dirname "$OUTPUT")"
"$GODOT" --headless --path "$PROJECT" --import || true
"$GODOT" --headless --path "$PROJECT" --export-release "$PRESET" "$OUTPUT"
echo "Exported $OUTPUT"
""" % [godot_bin, preset, out]

	DirAccess.make_dir_recursive_absolute(ps1_path.get_base_dir())
	var f1 := FileAccess.open(ps1_path, FileAccess.WRITE)
	if f1:
		f1.store_string(ps1)
		f1.close()
	var f2 := FileAccess.open(sh_path, FileAccess.WRITE)
	if f2:
		f2.store_string(sh)
		f2.close()
	return success({
		"powershell": ps1_path,
		"bash": sh_path,
		"preset": preset,
		"export_path": out,
		"usage_ps1": ".\\scripts\\export-release.ps1 -Godot path\\to\\godot.exe",
		"usage_sh": "GODOT=/path/to/godot ./scripts/export-release.sh",
	})


func _write_readme(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://ci/EXPORT_CI.md")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """# Export & CI checklist (Godot MCP)

## Local

1. `verify_export_ready` / `pipeline_pre_ship_check`
2. `create_export_presets_pack` or Project > Export
3. Install export templates matching editor version
4. `run_export` preset=... **or** `scripts/export-release.ps1`

## GitHub Actions

1. `create_github_actions_godot_export`
2. Align **preset names** in `export_presets.cfg` with workflow matrix
3. Commit `export_presets.cfg` (no secrets)
4. Android: store keystore in GitHub Secrets - see `get_export_signing_checklist`

## MCP tools

- `list_export_presets` / `create_export_preset` / `set_export_preset_option`
- `run_export` / `export_and_verify`
- `get_export_signing_checklist` / `configure_android_keystore`
- `list_export_ci_templates`

## Out of scope

- Console vendor SDKs (Switch/PS/Xbox)
- iOS notarization on non-macOS hosts
"""
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", true):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write")
	f.store_string(content)
	f.close()
	return success({"path": path})
