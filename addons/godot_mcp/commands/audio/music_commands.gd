@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Interactive music - playlist / state crossfade scaffolds (docs tutorials/audio).


func get_commands() -> Dictionary:
	return {
		"create_music_controller_script": _create_music_controller,
		"setup_music_player": _setup_music_player,
		"music_set_playlist": _music_set_playlist,
		"list_music_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"flow": [
			"create_music_controller_script add_autoload=true",
			"setup_music_player with layers or dual players for crossfade",
			"music_set_playlist states={explore,combat,...}",
			"Call MusicController.transition_to(\"combat\") from game code",
		],
		"tools": get_commands().keys(),
	})


func _create_music_controller(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/music_controller.gd")
	var content := """extends Node
## MCP MusicController - stateful BGM with crossfade between two players.
signal state_changed(state: String)

@export var fade_time: float = 1.0
var _players: Array = []  # AudioStreamPlayer
var _active: int = 0
var _playlist: Dictionary = {}  # state -> stream path or AudioStream
var _state: String = ""

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Layer%d" % i
		p.bus = "Music"
		add_child(p)
		_players.append(p)

func set_playlist(map: Dictionary) -> void:
	_playlist = map.duplicate()

func transition_to(state: String) -> void:
	if state == _state:
		return
	if not _playlist.has(state):
		push_warning("Unknown music state: " + state)
		return
	var next := 1 - _active
	var stream = _playlist[state]
	if stream is String and ResourceLoader.exists(stream):
		stream = load(stream)
	if stream is AudioStream:
		_players[next].stream = stream
	_players[next].volume_db = -40.0
	_players[next].play()
	var tw := create_tween()
	tw.tween_property(_players[next], "volume_db", 0.0, fade_time)
	tw.parallel().tween_property(_players[_active], "volume_db", -40.0, fade_time)
	tw.tween_callback(func():
		_players[_active].stop()
		_active = next
	)
	_state = state
	state_changed.emit(state)

func play_state(state: String) -> void:
	transition_to(state)

func stop_all() -> void:
	for p in _players:
		p.stop()
	_state = ""
"""
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	# Ensure Music bus
	var has_music := false
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == "Music":
			has_music = true
			break
	if not has_music:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	var al := false
	if optional_bool(params, "add_autoload", true):
		al = ensure_autoload(optional_string(params, "autoload_name", "MusicController"), w.get("path", path), true)
	return success({"path": w.get("path", path), "autoload_added": al, "music_bus": true})


func _setup_music_player(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var node := Node.new()
	node.name = optional_string(params, "name", "MusicController")
	add_child_with_undo(parent, node, root, "MCP: MusicController")
	var script_path: String = optional_string(params, "script_path", "res://scripts/music_controller.gd")
	if not FileAccess.file_exists(script_path):
		var c := _create_music_controller({"path": script_path, "overwrite": true, "add_autoload": false})
		if c.has("error"):
			return c
	var scr = load(script_path)
	if scr is Script:
		node.set_script(scr)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "script": script_path})


func _music_set_playlist(params: Dictionary) -> Dictionary:
	## Write a playlist resource JSON + optional call into scene autoload script defaults.
	var path: String = optional_string(params, "path", "res://audio/music_playlist.json")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var states: Dictionary = params.get("states", params.get("playlist", {}))
	if states.is_empty():
		return error_invalid_params("states/playlist Dictionary required: {explore: res://..., combat: res://...}")
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write playlist")
	f.store_string(JSON.stringify(states, "\t"))
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"states": states.keys(),
		"hint": "MusicController.set_playlist(load or parse JSON); transition_to(state)",
	})
