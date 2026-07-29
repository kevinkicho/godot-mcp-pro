@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Combat/UI feedback recipes - floating damage, hit flash, screen shake signal hooks.


func get_commands() -> Dictionary:
	return {
		"create_floating_text_script": _create_floating_text,
		"create_hit_flash_script": _create_hit_flash,
		"setup_floating_text_spawner": _setup_spawner,
		"list_gameplay_feedback_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_hitbox", "setup_hurtbox", "create_health_component_script", "add_camera_shake_to_camera2d"],
	})


func _create_floating_text(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/floating_text.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node2D
## Floating damage/heal text - spawn and forget.

@export var lifetime: float = 0.8
@export var rise_speed: float = 40.0
@export var text: String = "0"
@export var color: Color = Color(1, 0.9, 0.2, 1)

var _label: Label
var _t: float = 0.0

func _ready() -> void:
	_label = Label.new()
	_label.text = text
	_label.modulate = color
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	# Center pivot roughly
	await get_tree().process_frame
	if _label:
		_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y)

func setup(value: Variant, col: Color = Color(1, 0.9, 0.2)) -> void:
	text = str(value)
	color = col
	if _label:
		_label.text = text
		_label.modulate = color

func _process(delta: float) -> void:
	_t += delta
	position.y -= rise_speed * delta
	var a := 1.0 - clampf(_t / lifetime, 0.0, 1.0)
	modulate.a = a
	if _t >= lifetime:
		queue_free()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path})


func _create_hit_flash(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/hit_flash.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Flash CanvasItem modulate on hit - attach to sprite parent.

@export var target_path: NodePath
@export var flash_color: Color = Color(1, 1, 1, 1)
@export var flash_time: float = 0.08

var _target: CanvasItem
var _base: Color

func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as CanvasItem
	if _target == null and get_parent() is CanvasItem:
		_target = get_parent() as CanvasItem
	if _target:
		_base = _target.modulate

func flash() -> void:
	if _target == null:
		return
	_target.modulate = flash_color
	await get_tree().create_timer(flash_time).timeout
	if is_instance_valid(_target):
		_target.modulate = _base
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path})


func _setup_spawner(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/floating_text.gd")
	if not FileAccess.file_exists(script_path):
		var cr := _create_floating_text({"path": script_path, "overwrite": true})
		if cr.has("error"):
			return cr
	# Spawner helper script
	var spawner_path: String = optional_string(params, "spawner_script", "res://scripts/floating_text_spawner.gd")
	var sp_body := """extends Node2D
@export var floating_text_script: Script
@export var default_color: Color = Color(1, 0.85, 0.2)

func spawn(value: Variant, world_pos: Vector2, color: Color = Color(0,0,0,0)) -> void:
	if floating_text_script == null:
		return
	var n: Node2D = floating_text_script.new()
	if color.a > 0.0:
		n.set(\"color\", color)
	else:
		n.set(\"color\", default_color)
	n.set(\"text\", str(value))
	get_tree().current_scene.add_child(n)
	n.global_position = world_pos
	if n.has_method(\"setup\"):
		n.setup(value, n.get(\"color\"))
"""
	var wr := write_script_file(spawner_path, sp_body, true)
	if wr.has("error"):
		return wr
	var node := Node2D.new()
	node.name = optional_string(params, "name", "FloatingTextSpawner")
	var script_res = load(spawner_path)
	if script_res:
		node.set_script(script_res)
	add_child_with_undo(parent, node, root, "MCP: Floating text spawner")
	if "floating_text_script" in node:
		var fts = load(script_path)
		if fts:
			node.set("floating_text_script", fts)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"floating_text_script": script_path,
		"spawner_script": spawner_path,
	})
