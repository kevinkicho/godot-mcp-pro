@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Reverb / ambient zones - Area3D-driven bus send for spatial audio production.


func get_commands() -> Dictionary:
	return {
		"setup_reverb_zone_3d": _setup_zone,
		"create_reverb_zone_script": _create_script,
		"setup_audio_listener_3d": _setup_listener,
		"list_audio_reverb_zone_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"add_audio_bus_effect_typed", "setup_audio_stream_player_3d", "add_audio_bus",
		"create_audio_bus_layout_preset",
	])


func _create_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/reverb_zone.gd")
	var content := """extends Area3D
## When listener enters, enable a reverb bus send / wet amount.

@export var reverb_bus: StringName = &\"Reverb\"
@export var wet: float = 0.35
@export var target_player_group: StringName = &\"player\"

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	monitoring = true

func _on_enter(body: Node) -> void:
	if not body.is_in_group(target_player_group) and not body is CharacterBody3D:
		return
	_set_bus_send(true)

func _on_exit(body: Node) -> void:
	if not body.is_in_group(target_player_group) and not body is CharacterBody3D:
		return
	_set_bus_send(false)

func _set_bus_send(on: bool) -> void:
	var idx := AudioServer.get_bus_index(reverb_bus)
	if idx < 0:
		return
	# Enable bus; effects assumed preconfigured via add_audio_bus_effect_typed
	AudioServer.set_bus_mute(idx, not on)
	if on:
		for i in AudioServer.get_bus_effect_count(idx):
			var fx := AudioServer.get_bus_effect(idx, i)
			if fx and \"wet\" in fx:
				fx.set(\"wet\", wet)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})


func _setup_zone(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	# Ensure reverb bus exists
	var bus_name: String = optional_string(params, "bus", "Reverb")
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, bus_name)
		var rev := AudioEffectReverb.new()
		rev.room_size = float(params.get("room_size", 0.8))
		rev.damping = float(params.get("damping", 0.5))
		rev.wet = float(params.get("wet", 0.35))
		rev.dry = float(params.get("dry", 0.7))
		AudioServer.add_bus_effect(bi, rev)
	var area := Area3D.new()
	area.name = optional_string(params, "name", "ReverbZone")
	area.monitoring = true
	area.monitorable = false
	add_child_with_undo(parent, area, root, "MCP: ReverbZone")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	var size := Vector3(
		float(params.get("width", 10)),
		float(params.get("height", 4)),
		float(params.get("depth", 10))
	)
	shape.size = size
	col.shape = shape
	add_child_with_undo(area, col, root, "MCP: reverb shape")
	var script_path: String = optional_string(params, "script_path", "res://scripts/reverb_zone.gd")
	if not FileAccess.file_exists(script_path):
		_create_script({"path": script_path, "overwrite": false})
	var scr: Script = load(script_path)
	if scr:
		area.set_script(scr)
		if "reverb_bus" in area:
			area.set("reverb_bus", StringName(bus_name))
		if "wet" in area:
			area.set("wet", float(params.get("wet", 0.35)))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(area)),
		"bus": bus_name,
		"size": {"x": size.x, "y": size.y, "z": size.z},
	})


func _setup_listener(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var listener := AudioListener3D.new()
	listener.name = optional_string(params, "name", "AudioListener3D")
	listener.current = optional_bool(params, "current", true)
	add_child_with_undo(parent, listener, root, "MCP: AudioListener3D")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(listener)), "current": listener.current})
