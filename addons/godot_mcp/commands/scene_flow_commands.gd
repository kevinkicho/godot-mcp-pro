@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene flow — transitions, loading screens, change_scene helpers (project-neutral).


func get_commands() -> Dictionary:
	return {
		"create_scene_transition_script": _create_scene_transition_script,
		"create_loading_screen_scene": _create_loading_screen_scene,
		"list_scene_flow_recipes": _list_scene_flow_recipes,
		"set_main_scene": _set_main_scene,
	}


func _list_scene_flow_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"recipes": [
			{"id": "fade_transition", "tool": "create_scene_transition_script", "desc": "Autoload fade + change_scene_to_file"},
			{"id": "loading_screen", "tool": "create_loading_screen_scene", "desc": "Threaded ResourceLoader progress UI"},
			{"id": "main_scene", "tool": "set_main_scene", "desc": "application/run/main_scene"},
		],
		"hint": "Add transition script as Autoload named SceneTransition for global use.",
	})


func _create_scene_transition_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/scene_transition.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	var fade_time: float = float(params.get("fade_time", 0.35))
	var content := """extends CanvasLayer
## MCP scene transition autoload — fade overlay then change scene.
## Project Settings > Autoload > SceneTransition = this script.

signal transition_started(path: String)
signal transition_finished(path: String)

@export var fade_time: float = %s
var _rect: ColorRect
var _busy: bool = false

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	transition_started.emit(path)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, fade_time)
	await tw.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition failed: %%s (%%s)" %% [path, error_string(err)])
	# New scene tree — this autoload persists; fade in
	await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(_rect, "color:a", 0.0, fade_time)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	transition_finished.emit(path)

func reload_current() -> void:
	var path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if not path.is_empty():
		change_scene(path)
""" % str(fade_time)
	# Fix double %% for GDScript - I used %% incorrectly. In the content string I want single % for GDScript format.
	# Actually the push_error line uses %% which becomes % after GDScript % formatting of fade_time only.
	# Wait - I only used %s once for fade_time. The %% becomes % in output. Good for push_error.
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	var autoload := false
	if optional_bool(params, "add_autoload", false):
		var aname: String = optional_string(params, "autoload_name", "SceneTransition")
		if not ProjectSettings.has_setting("autoload/" + aname):
			ProjectSettings.set_setting("autoload/" + aname, "*" + path)
			ProjectSettings.save()
			autoload = true
	return success({
		"path": path,
		"fade_time": fade_time,
		"autoload_added": autoload,
		"hint": "Call SceneTransition.change_scene(\"res://scenes/x.tscn\") from anywhere.",
	})


func _create_loading_screen_scene(params: Dictionary) -> Dictionary:
	## Creates a minimal .tscn + script that loads a target scene with progress bar.
	var scene_path: String = optional_string(params, "path", "res://scenes/loading_screen.tscn")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")
	var script_path: String = optional_string(params, "script_path", "res://scripts/loading_screen.gd")
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path.trim_prefix("/")
	var default_next: String = optional_string(params, "next_scene", "res://scenes/main.tscn")

	var script := """extends Control
## MCP loading screen — set next_scene then play this scene.
@export_file("*.tscn") var next_scene: String = "%s"
@onready var _bar: ProgressBar = $Center/VBox/ProgressBar
@onready var _label: Label = $Center/VBox/Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if next_scene.is_empty():
		_label.text = "No next_scene set"
		return
	ResourceLoader.load_threaded_request(next_scene)
	set_process(true)

func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(next_scene)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress: Array = []
			ResourceLoader.load_threaded_get_status(next_scene, progress)
			if progress.size() > 0:
				_bar.value = float(progress[0]) * 100.0
				_label.text = "Loading… %%d%%%%" %% int(_bar.value)
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_bar.value = 100
			var packed: PackedScene = ResourceLoader.load_threaded_get(next_scene)
			if packed:
				get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			_label.text = "Load failed"
""" % default_next

	var derr := ensure_parent_dir(script_path)
	if not derr.is_empty():
		return derr
	var sf := FileAccess.open(script_path, FileAccess.WRITE)
	sf.store_string(script)
	sf.close()

	# Build tscn text
	var tscn := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="%s" id="1"]

[node name="LoadingScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="ColorRect" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.08, 0.08, 0.1, 1)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="Center/VBox"]
layout_mode = 2
text = "Loading…"
horizontal_alignment = 1

[node name="ProgressBar" type="ProgressBar" parent="Center/VBox"]
custom_minimum_size = Vector2(320, 24)
layout_mode = 2
show_percentage = true
""" % script_path

	var derr2 := ensure_parent_dir(scene_path)
	if not derr2.is_empty():
		return derr2
	var tf := FileAccess.open(scene_path, FileAccess.WRITE)
	tf.store_string(tscn)
	tf.close()
	EditorInterface.get_resource_filesystem().update_file(script_path)
	EditorInterface.get_resource_filesystem().update_file(scene_path)
	return success({
		"scene_path": scene_path,
		"script_path": script_path,
		"next_scene": default_next,
		"hint": "Open loading scene, set next_scene export, or change_scene to loading screen with next_scene set.",
	})


func _set_main_scene(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		return error_invalid_params("main scene should be a .tscn/.scn")
	var old = ProjectSettings.get_setting("application/run/main_scene", "")
	ProjectSettings.set_setting("application/run/main_scene", path)
	ProjectSettings.save()
	return success({"main_scene": path, "old": old})
