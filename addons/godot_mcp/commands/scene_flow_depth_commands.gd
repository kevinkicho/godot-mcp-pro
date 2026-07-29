@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scene flow depth — pause tree, change scene recipes, quit, reload, main menu shell.


func get_commands() -> Dictionary:
	return {
		"set_scene_tree_paused_state": _set_paused,
		"create_game_flow_controller_script": _create_flow_controller,
		"setup_main_menu_scene": _setup_main_menu,
		"create_pause_menu_controller_script": _create_pause_controller,
		"list_scene_flow_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"create_scene_transition_script", "create_loading_screen_scene", "set_main_scene",
			"setup_pause_menu", "play_main_scene",
		],
		"workflow": [
			"setup_main_menu_scene path=res://scenes/main_menu.tscn",
			"create_game_flow_controller_script add_autoload=true",
			"create_scene_transition_script add_autoload=true",
			"set_main_scene path=res://scenes/main_menu.tscn",
		],
	})


func _set_paused(params: Dictionary) -> Dictionary:
	## Editor-side note: pausing affects editor tree if not careful — set on intention.
	var paused: bool = optional_bool(params, "paused", true)
	# Prefer documenting runtime; still set if get_tree available
	var tree := get_tree()
	if tree:
		tree.paused = paused
	return success({
		"paused": paused,
		"hint": "For game pause use process_mode on pause menu + get_tree().paused at runtime via GameFlow script",
	})


func _create_flow_controller(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/game_flow.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var main_menu: String = optional_string(params, "main_menu_scene", "res://scenes/main_menu.tscn")
	var game_scene: String = optional_string(params, "game_scene", "res://scenes/main.tscn")
	var content := """extends Node
## Global game flow: menu ↔ game, pause, quit, reload.

signal scene_change_requested(path: String)
signal paused_changed(is_paused: bool)

@export_file(\"*.tscn\") var main_menu_scene: String = \"%s\"
@export_file(\"*.tscn\") var game_scene: String = \"%s\"
@export var pause_action: StringName = &\"ui_cancel\"

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pause_action) and get_tree().current_scene:
		# Only toggle pause when not on main menu
		if str(get_tree().current_scene.scene_file_path) != main_menu_scene:
			toggle_pause()

func go_main_menu() -> void:
	set_paused(false)
	change_scene(main_menu_scene)

func start_game() -> void:
	set_paused(false)
	change_scene(game_scene)

func reload_current() -> void:
	var sc := get_tree().current_scene
	if sc and not sc.scene_file_path.is_empty():
		change_scene(sc.scene_file_path)

func change_scene(path: String) -> void:
	scene_change_requested.emit(path)
	# Prefer SceneTransition autoload if present
	if Engine.has_singleton(\"SceneTransition\") == false:
		var st := get_node_or_null(\"/root/SceneTransition\")
		if st and st.has_method(\"change_scene\"):
			st.change_scene(path)
			return
	get_tree().change_scene_to_file(path)

func set_paused(p: bool) -> void:
	is_paused = p
	get_tree().paused = p
	paused_changed.emit(p)

func toggle_pause() -> void:
	set_paused(not is_paused)

func quit_game() -> void:
	get_tree().quit()
""" % [main_menu, game_scene]
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	var al := maybe_add_autoload(params, path, "GameFlow")
	return success({
		"path": path,
		"autoload_added": al,
		"main_menu_scene": main_menu,
		"game_scene": game_scene,
		"api": ["go_main_menu", "start_game", "reload_current", "toggle_pause", "quit_game"],
	})


func _setup_main_menu(params: Dictionary) -> Dictionary:
	## Create a simple main menu scene with Start / Quit wired to GameFlow if present.
	var path: String = optional_string(params, "path", "res://scenes/main_menu.tscn")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})

	# Ensure controller script for menu
	var script_path: String = optional_string(params, "script_path", "res://scripts/main_menu.gd")
	var game_scene: String = optional_string(params, "game_scene", "res://scenes/main.tscn")
	var script_body := """extends Control
@export_file(\"*.tscn\") var game_scene: String = \"%s\"

func _on_start_pressed() -> void:
	var gf := get_node_or_null(\"/root/GameFlow\")
	if gf and gf.has_method(\"start_game\"):
		gf.start_game()
	else:
		get_tree().change_scene_to_file(game_scene)

func _on_quit_pressed() -> void:
	var gf := get_node_or_null(\"/root/GameFlow\")
	if gf and gf.has_method(\"quit_game\"):
		gf.quit_game()
	else:
		get_tree().quit()
""" % game_scene
	var sw := write_script_file(script_path, script_body, true)
	if sw.has("error"):
		return sw

	# Build scene in memory if no scene open, or create offline tscn
	var title: String = optional_string(params, "title", "Game Title")
	var body := """[gd_scene load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]

[node name=\"MainMenu\" type=\"Control\"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource(\"1\")
game_scene = \"%s\"

[node name=\"Center\" type=\"CenterContainer\" parent=\".\"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name=\"VBox\" type=\"VBoxContainer\" parent=\"Center\"]
layout_mode = 2
theme_override_constants/separation = 12

[node name=\"Title\" type=\"Label\" parent=\"Center/VBox\"]
layout_mode = 2
text = \"%s\"
horizontal_alignment = 1

[node name=\"StartButton\" type=\"Button\" parent=\"Center/VBox\"]
layout_mode = 2
text = \"Start\"

[node name=\"QuitButton\" type=\"Button\" parent=\"Center/VBox\"]
layout_mode = 2
text = \"Quit\"

[connection signal=\"pressed\" from=\"Center/VBox/StartButton\" to=\".\" method=\"_on_start_pressed\"]
[connection signal=\"pressed\" from=\"Center/VBox/QuitButton\" to=\".\" method=\"_on_quit_pressed\"]
""" % [script_path, game_scene, title]
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write scene")
	f.store_string(body)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	if optional_bool(params, "set_as_main", true):
		ProjectSettings.set_setting("application/run/main_scene", path)
		ProjectSettings.save()
	if optional_bool(params, "open", false):
		EditorInterface.open_scene_from_path(path)
	return success({
		"path": path,
		"script_path": script_path,
		"game_scene": game_scene,
		"set_as_main": optional_bool(params, "set_as_main", true),
	})


func _create_pause_controller(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/pause_menu_controller.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends CanvasLayer
## Pause menu controller — PROCESS_MODE_ALWAYS so it works while tree paused.

signal resume_pressed
signal quit_to_menu_pressed

@export var panel_path: NodePath
@export var resume_button_path: NodePath
@export var quit_button_path: NodePath

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var resume := get_node_or_null(resume_button_path)
	if resume and resume.has_signal(\"pressed\"):
		resume.pressed.connect(_on_resume)
	var quit_b := get_node_or_null(quit_button_path)
	if quit_b and quit_b.has_signal(\"pressed\"):
		quit_b.pressed.connect(_on_quit_menu)

func show_pause() -> void:
	visible = true
	get_tree().paused = true

func hide_pause() -> void:
	visible = false
	get_tree().paused = false

func _on_resume() -> void:
	hide_pause()
	resume_pressed.emit()

func _on_quit_menu() -> void:
	hide_pause()
	quit_to_menu_pressed.emit()
	var gf := get_node_or_null(\"/root/GameFlow\")
	if gf and gf.has_method(\"go_main_menu\"):
		gf.go_main_menu()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "hint": "Attach to CanvasLayer pause UI; wire resume/quit button paths"})
