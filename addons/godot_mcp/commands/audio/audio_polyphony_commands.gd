@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Polyphonic SFX — max_polyphony, AudioStreamPolyphonic recipes for overlapping sounds.


func get_commands() -> Dictionary:
	return {
		"setup_polyphonic_player": _setup_polyphonic_player,
		"set_audio_player_polyphony": _set_polyphony,
		"create_sfx_pool_script": _create_sfx_pool,
		"list_audio_polyphony_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_audio_stream_player_2d", "create_audio_manager_script", "add_audio_bus"],
	})


func _setup_polyphonic_player(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var dim: String = optional_string(params, "dimension", "2d").to_lower()
	var player: Node
	if dim in ["3d", "3"]:
		player = AudioStreamPlayer3D.new()
	elif dim in ["ui", "bus", "plain", "mix"]:
		player = AudioStreamPlayer.new()
	else:
		player = AudioStreamPlayer2D.new()
	player.name = optional_string(params, "name", "SFXPlayer")
	var max_poly: int = optional_int(params, "max_polyphony", 8)
	if "max_polyphony" in player:
		player.set("max_polyphony", max_poly)
	var stream_path: String = optional_string(params, "stream_path", "")
	if not stream_path.is_empty() and ResourceLoader.exists(stream_path):
		var st = load(stream_path)
		if st is AudioStream:
			player.set("stream", st)
	if params.has("volume_db"):
		player.set("volume_db", float(params["volume_db"]))
	if params.has("bus"):
		player.set("bus", str(params["bus"]))
	if params.has("position") and player is Node2D and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		(player as Node2D).position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	add_child_with_undo(parent, player, root, "MCP: Polyphonic audio player")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(player)),
		"class": player.get_class(),
		"max_polyphony": max_poly,
		"hint": "Godot 4 max_polyphony allows overlapping plays of the same player",
	})


func _set_polyphony(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	if not ("max_polyphony" in node):
		return error_invalid_params("Node has no max_polyphony (need AudioStreamPlayer*)")
	var max_poly: int = optional_int(params, "max_polyphony", 4)
	node.set("max_polyphony", max_poly)
	if params.has("volume_db"):
		node.set("volume_db", float(params["volume_db"]))
	if params.has("bus"):
		node.set("bus", str(params["bus"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "max_polyphony": max_poly})


func _create_sfx_pool(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/sfx_pool.gd")
	var res := validate_res_path(path)
	if res[1] != null:
		return res[1]
	path = res[0]
	var content := """extends Node
## Simple SFX pool — play overlapping one-shots without cutting prior sounds.

@export var player_path: NodePath
@export var default_bus: StringName = &"SFX"

var _player: Node

func _ready() -> void:
	if player_path != NodePath():
		_player = get_node_or_null(player_path)
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "PoolPlayer"
		if "max_polyphony" in _player:
			_player.max_polyphony = 16
		_player.bus = String(default_bus)
		add_child(_player)

func play_stream(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _player == null:
		return
	_player.stream = stream
	if "volume_db" in _player:
		_player.volume_db = volume_db
	if "pitch_scale" in _player:
		_player.pitch_scale = pitch_scale
	_player.play()

func play_path(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		push_warning("SFX missing: %s" % path)
		return
	var st = load(path)
	if st is AudioStream:
		play_stream(st, volume_db, pitch_scale)
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var added_al := maybe_add_autoload(params, path, "SFXPool")
	return success({
		"path": path,
		"autoload_added": added_al,
		"hint": "setup_polyphonic_player then set player_path; call play_path(res://…)",
	})
