@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## iOS / platform export helpers - checklists & scaffolds (full Xcode still needs macOS).


func get_commands() -> Dictionary:
	return {
		"get_ios_export_checklist": _ios_checklist,
		"get_platform_export_matrix": _platform_matrix,
		"create_ios_export_notes": _ios_notes,
		"ensure_ios_export_preset": _ensure_ios_preset,
		"list_ios_platform_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_export_preset", "get_export_signing_checklist", "pipeline_export_ci", "run_export"],
		"honesty": "iOS code signing and App Store upload require macOS + Xcode; MCP provides checklist + preset scaffolding only",
	})


func _ios_checklist(_params: Dictionary) -> Dictionary:
	return success({
		"host_required": "macOS with Xcode",
		"steps": [
			{"id": 1, "action": "Install iOS export templates matching Godot version", "mcp": "list_export_templates / get_export_templates_path"},
			{"id": 2, "action": "Create iOS export preset", "mcp": "ensure_ios_export_preset or create_export_preset platform=iOS"},
			{"id": 3, "action": "Set bundle id, app name, icons, landscape/portrait", "mcp": "set_export_preset_option"},
			{"id": 4, "action": "Configure signing team / provisioning in Xcode after export", "mcp": "get_export_signing_checklist platform=ios"},
			{"id": 5, "action": "Export from macOS Godot or xcodebuild", "mcp": "run_export (macOS host)"},
			{"id": 6, "action": "Archive & upload via Xcode Organizer / Transporter", "mcp": null},
		],
		"project_settings_to_review": [
			"application/config/name",
			"application/config/version",
			"display/window/handheld/orientation",
			"rendering/renderer/rendering_method",
		],
		"privacy": [
			"NSCameraUsageDescription if using camera",
			"NSMicrophoneUsageDescription if using mic",
			"NSMotionUsageDescription if using IMU",
			"Tracking / ATT if advertising",
		],
		"windows_linux_note": "Cannot complete iOS signing on this host - use ensure_ios_export_preset + checklist only",
	})


func _platform_matrix(_params: Dictionary) -> Dictionary:
	return success({
		"platforms": {
			"windows": {"mcp_support": "strong", "ci": true, "signing": "optional codesign"},
			"linux": {"mcp_support": "strong", "ci": true, "signing": "optional"},
			"macos": {"mcp_support": "strong", "ci": true, "signing": "notarization needs Apple ID"},
			"web": {"mcp_support": "strong", "ci": true, "signing": "n/a"},
			"android": {"mcp_support": "strong", "ci": "partial (keystore secrets)", "signing": "get_export_signing_checklist"},
			"ios": {"mcp_support": "checklist + preset", "ci": "macOS runners only", "signing": "Xcode required"},
			"consoles": {"mcp_support": "out_of_scope", "ci": false, "signing": "vendor SDKs"},
		},
		"tools": {
			"desktop_web": ["create_export_presets_pack", "pipeline_export_ci", "run_export"],
			"android": ["deploy_to_android", "configure_android_keystore", "get_export_signing_checklist"],
			"ios": ["get_ios_export_checklist", "ensure_ios_export_preset", "create_ios_export_notes"],
		},
	})


func _ios_notes(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://docs/IOS_EXPORT.md")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """# iOS export notes (Godot MCP)

## Reality check

Full iOS App Store shipping **requires macOS + Xcode**. On Windows/Linux, use this checklist to prepare the project, then finish on a Mac.

## Prepare anywhere (Windows/Linux/macOS)

1. Set app name / version in Project Settings
2. `ensure_ios_export_preset` or create Export preset \"iOS\"
3. Icons, splash, orientation, bundle identifier
4. Review privacy usage strings for plugins

## Finish on macOS

1. Install matching iOS export templates
2. Export project from Godot -> `.xcodeproj` / `.ipa` flow
3. Open in Xcode -> Signing & Capabilities
4. Archive -> Distribute App

## MCP

- `get_ios_export_checklist`
- `get_platform_export_matrix`
- `get_export_signing_checklist platform=ios`
"""
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", true):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("write failed")
	f.store_string(content)
	f.close()
	return success({"path": path})


func _ensure_ios_preset(params: Dictionary) -> Dictionary:
	var router = get_parent()
	if router == null or not router.has_method("execute"):
		return error_internal("No router")
	var name: String = optional_string(params, "name", "iOS")
	var export_path: String = optional_string(params, "export_path", "res://build/ios/game.ipa")
	var r = await router.execute("create_export_preset", {
		"name": name,
		"platform": "iOS",
		"export_path": export_path,
		"runnable": optional_bool(params, "runnable", true),
	})
	return success({
		"preset": name,
		"export_path": export_path,
		"result": r,
		"next": ["get_ios_export_checklist", "set_export_preset_option for bundle id"],
	})
