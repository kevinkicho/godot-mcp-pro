@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AudioStreamGenerator + procedural tone helpers (tutorials/audio depth).


func get_commands() -> Dictionary:
	return {
		"setup_audio_stream_generator": _setup_audio_stream_generator,
		"create_tone_generator_script": _create_tone_generator_script,
		"create_audio_bus_layout_preset": _create_audio_bus_layout_preset,
		"list_audio_generator_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_audio_player", "set_audio_player_stream", "add_audio_bus", "create_music_controller_script"],
	})


func _setup_audio_stream_generator(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var player := AudioStreamPlayer.new()
	player.name = optional_string(params, "name", "GeneratorPlayer")
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(params.get("mix_rate", 44100.0))
	if "buffer_length" in gen:
		gen.buffer_length = float(params.get("buffer_length", 0.1))
	player.stream = gen
	player.autoplay = optional_bool(params, "autoplay", false)
	add_child_with_undo(parent, player, root, "MCP: AudioStreamGenerator player")
	var script_path: String = optional_string(params, "script_path", "")
	if optional_bool(params, "attach_tone_script", true):
		if script_path.is_empty():
			script_path = "res://scripts/tone_generator_player.gd"
		if not FileAccess.file_exists(script_path):
			_write_tone_script(script_path)
		if FileAccess.file_exists(script_path):
			player.set_script(load(script_path))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(player)),
		"mix_rate": gen.mix_rate,
		"script_path": script_path,
		"hint": "Play scene; script fills playback buffer with sine if attached",
	})


func _write_tone_script(path: String) -> void:
	var content := """extends AudioStreamPlayer
## Fills AudioStreamGeneratorPlayback with a sine tone while playing.
@export var frequency_hz: float = 440.0
@export var amplitude: float = 0.2
var _phase: float = 0.0

func _process(_dt: float) -> void:
	if not playing:
		return
	var playback := get_stream_playback()
	if playback == null:
		return
	if playback is AudioStreamGeneratorPlayback:
		var p := playback as AudioStreamGeneratorPlayback
		var to_fill := p.get_frames_available()
		if to_fill <= 0:
			return
		var rate := 44100.0
		if stream is AudioStreamGenerator:
			rate = (stream as AudioStreamGenerator).mix_rate
		for i in to_fill:
			var s := sin(_phase * TAU) * amplitude
			p.push_frame(Vector2(s, s))
			_phase = fmod(_phase + frequency_hz / rate, 1.0)
"""
	write_script_file(path, content, false)


func _create_tone_generator_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/tone_generator_player.gd")
	_write_tone_script(path)
	return success({"path": path})


func _create_audio_bus_layout_preset(params: Dictionary) -> Dictionary:
	## Ensure Master + Music + SFX buses exist with basic routing.
	var layout_path: String = optional_string(params, "path", "res://default_bus_layout.tres")
	# Live buses
	var ensure := ["Music", "SFX", "UI", "Voice"]
	if params.has("buses") and params["buses"] is Array:
		ensure = []
		for b in params["buses"]:
			ensure.append(str(b))
	var created: Array = []
	for bname in ensure:
		var idx := AudioServer.get_bus_index(bname)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, "Master")
			created.append(bname)
	# Save layout resource if possible
	var saved := false
	if optional_bool(params, "save_layout", true):
		# AudioServer does not always expose easy save; write project setting path
		ProjectSettings.set_setting("audio/buses/default_bus_layout", layout_path)
		ProjectSettings.save()
		saved = true
	return success({
		"created_buses": created,
		"bus_count": AudioServer.bus_count,
		"layout_setting": layout_path if saved else "",
		"hint": "use add_audio_bus_effect / set_audio_bus for effects; save layout from editor Audio panel if needed",
	})
