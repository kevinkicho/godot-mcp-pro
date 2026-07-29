@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## OpenXR passthrough + composition layer scaffolds (XR docs gap).


func get_commands() -> Dictionary:
	return {
		"set_xr_passthrough_settings": _set_xr_passthrough_settings,
		"setup_xr_composition_layer_quad": _setup_xr_composition_layer_quad,
		"get_xr_passthrough_info": _get_xr_passthrough_info,
		"create_xr_passthrough_controller_script": _create_xr_passthrough_controller_script,
		"list_xr_passthrough_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_xr_origin", "set_xr_project_settings", "openxr_*"],
		"note": "Passthrough APIs vary by headset/vendor; these expose project settings + scene scaffolds",
	})


func _set_xr_passthrough_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	# Godot 4 OpenXR / environment blend mode style settings (names vary by version)
	var candidates := {
		"enabled": [
			"xr/openxr/environment_blend_mode",
			"xr/openxr/foveation_level",
		],
		"submit_depth": ["xr/openxr/submit_depth_buffer"],
		"startup": ["xr/openxr/enabled", "xr/shaders/enabled"],
	}
	if params.has("openxr_enabled"):
		ProjectSettings.set_setting("xr/openxr/enabled", bool(params["openxr_enabled"]))
		applied["xr/openxr/enabled"] = bool(params["openxr_enabled"])
	if params.has("shaders_enabled"):
		ProjectSettings.set_setting("xr/shaders/enabled", bool(params["shaders_enabled"]))
		applied["xr/shaders/enabled"] = bool(params["shaders_enabled"])
	# Environment blend: 0 opaque, 1 additive, 2 alpha (passthrough-ish on supported devices)
	if params.has("environment_blend_mode"):
		var mode = params["environment_blend_mode"]
		if mode is String:
			match str(mode).to_lower():
				"opaque":
					mode = 0
				"additive":
					mode = 1
				"alpha", "passthrough":
					mode = 2
		ProjectSettings.set_setting("xr/openxr/environment_blend_mode", int(mode))
		applied["xr/openxr/environment_blend_mode"] = int(mode)
	if params.has("submit_depth_buffer"):
		ProjectSettings.set_setting("xr/openxr/submit_depth_buffer", bool(params["submit_depth_buffer"]))
		applied["xr/openxr/submit_depth_buffer"] = bool(params["submit_depth_buffer"])
	if params.has("foveation_level"):
		ProjectSettings.set_setting("xr/openxr/foveation_level", int(params["foveation_level"]))
		applied["xr/openxr/foveation_level"] = int(params["foveation_level"])
	# Reference space
	if params.has("reference_space"):
		ProjectSettings.set_setting("xr/openxr/reference_space", int(params["reference_space"]) if not (params["reference_space"] is String) else params["reference_space"])
		applied["xr/openxr/reference_space"] = ProjectSettings.get_setting("xr/openxr/reference_space")
	if applied.is_empty():
		return error_invalid_params("Provide openxr_enabled, environment_blend_mode=alpha|passthrough, etc.")
	ProjectSettings.save()
	return success({
		"applied": applied,
		"hint": "Device must support blend modes; use create_xr_passthrough_controller_script for runtime toggle",
	})


func _get_xr_passthrough_info(_params: Dictionary) -> Dictionary:
	var keys := [
		"xr/openxr/enabled",
		"xr/shaders/enabled",
		"xr/openxr/environment_blend_mode",
		"xr/openxr/submit_depth_buffer",
		"xr/openxr/foveation_level",
		"xr/openxr/reference_space",
		"xr/openxr/default_action_map",
	]
	var settings := {}
	for k in keys:
		if ProjectSettings.has_setting(k):
			settings[k] = ProjectSettings.get_setting(k)
	var interfaces: Array = []
	if XRServer:
		for iface_name in ["OpenXR", "OpenXRInterface"]:
			pass
		# List registered interfaces
		var count := XRServer.get_interface_count() if XRServer.has_method("get_interface_count") else 0
		for i in range(count):
			var iface = XRServer.get_interface(i)
			if iface:
				interfaces.append({
					"name": iface.get_name() if iface.has_method("get_name") else str(iface),
					"is_initialized": iface.is_initialized() if iface.has_method("is_initialized") else null,
				})
	return success({
		"settings": settings,
		"interfaces": interfaces,
		"blend_mode_legend": {"0": "opaque", "1": "additive", "2": "alpha/passthrough"},
	})


func _setup_xr_composition_layer_quad(params: Dictionary) -> Dictionary:
	## Best-effort OpenXR composition layer quad (class may be OpenXRCompositionLayerQuad).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var class_names := [
		"OpenXRCompositionLayerQuad",
		"XRCompositionLayerQuad",
	]
	var node: Node = null
	var used := ""
	for cn in class_names:
		if ClassDB.class_exists(cn):
			node = ClassDB.instantiate(cn)
			used = cn
			break
	if node == null:
		# Fallback: MeshInstance quad as placeholder for UI-in-world
		var mi := MeshInstance3D.new()
		mi.name = optional_string(params, "name", "CompositionLayerQuadPlaceholder")
		var q := QuadMesh.new()
		q.size = Vector2(float(params.get("width", 1.0)), float(params.get("height", 1.0)))
		mi.mesh = q
		add_child_with_undo(parent, mi, root, "MCP: XR quad placeholder")
		mark_current_scene_unsaved()
		return success({
			"node_path": str(root.get_path_to(mi)),
			"class": "MeshInstance3D+QuadMesh",
			"placeholder": true,
			"hint": "OpenXRCompositionLayerQuad not in this build - placeholder mesh for layout",
		})
	node.name = optional_string(params, "name", "OpenXRCompositionLayerQuad")
	if params.has("layer") and "layer" in node:
		node.set("layer", int(params["layer"]))
	if params.has("alpha_blend") and "alpha_blend" in node:
		node.set("alpha_blend", bool(params["alpha_blend"]))
	if params.has("sort_order") and "sort_order" in node:
		node.set("sort_order", int(params["sort_order"]))
	add_child_with_undo(parent, node, root, "MCP: XR composition layer")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "class": used, "placeholder": false})


func _create_xr_passthrough_controller_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/xr_passthrough_controller.gd")
	var content := """extends Node
## Runtime OpenXR environment blend / passthrough helper (device-dependent).
signal blend_mode_changed(mode: int)

@export var start_with_passthrough: bool = false

func _ready() -> void:
	if start_with_passthrough:
		set_passthrough(true)

func _openxr_interface() -> XRInterface:
	var iface := XRServer.find_interface(\"OpenXR\")
	if iface == null:
		iface = XRServer.find_interface(\"OpenXRInterface\")
	return iface

func set_passthrough(enabled: bool) -> bool:
	var iface := _openxr_interface()
	if iface == null:
		push_warning(\"OpenXR interface not found\")
		return false
	# Prefer environment blend modes when available
	if iface.has_method(\"set_environment_blend_mode\"):
		# 0 opaque, 2 alpha blend (passthrough on many HMDs)
		var mode := 2 if enabled else 0
		iface.call(\"set_environment_blend_mode\", mode)
		blend_mode_changed.emit(mode)
		return true
	if \"environment_blend_mode\" in iface:
		iface.set(\"environment_blend_mode\", 2 if enabled else 0)
		blend_mode_changed.emit(int(iface.get(\"environment_blend_mode\")))
		return true
	push_warning(\"Passthrough blend mode API not available on this interface\")
	return false

func toggle_passthrough() -> void:
	set_passthrough(true)  # caller can track state
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	var added := maybe_add_autoload(params, path, "XRPassthrough")
	return success({"path": path, "autoload_added": added})
