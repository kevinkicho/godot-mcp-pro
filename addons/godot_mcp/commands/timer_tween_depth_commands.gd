@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Timer + SceneTreeTween structural helpers for agent timelines.


func get_commands() -> Dictionary:
	return {
		"setup_timer": _setup_timer,
		"setup_scene_tree_timer_script": _setup_scene_tree_timer_script,
		"create_tween_recipe_script": _create_tween_recipe_script,
		"list_timer_tween_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_tween", "tween_*", "utility_node_commands"],
	})


func _setup_timer(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var t := Timer.new()
	t.name = optional_string(params, "name", "Timer")
	t.wait_time = float(params.get("wait_time", 1.0))
	t.one_shot = optional_bool(params, "one_shot", false)
	t.autostart = optional_bool(params, "autostart", false)
	t.process_callback = Timer.TIMER_PROCESS_IDLE if optional_string(params, "process", "idle") == "idle" else Timer.TIMER_PROCESS_PHYSICS
	if params.has("paused"):
		t.paused = bool(params["paused"])
	add_child_with_undo(parent, t, root, "MCP: Timer")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(t)),
		"wait_time": t.wait_time,
		"one_shot": t.one_shot,
		"autostart": t.autostart,
	})


func _setup_scene_tree_timer_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/delay_helper.gd")
	var content := """extends Node
## Await-friendly delays without Timer nodes.
func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func wait_physics(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})


func _create_tween_recipe_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/tween_recipes.gd")
	var content := """extends Node
## Common Tween recipes for UI/game juice.

func fade_canvas_item(node: CanvasItem, to_alpha: float, duration: float = 0.3) -> Tween:
	var tw := create_tween()
	tw.tween_property(node, \"modulate:a\", to_alpha, duration)
	return tw

func move_to_3d(node: Node3D, target: Vector3, duration: float = 0.4) -> Tween:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, \"global_position\", target, duration)
	return tw

func punch_scale(node: Node, amount: float = 1.15, duration: float = 0.2) -> Tween:
	var base: Vector3 = node.scale if node is Node3D else Vector3(node.scale.x, node.scale.y, 1.0) if node is Node2D else Vector3.ONE
	var tw := create_tween()
	if node is Node3D:
		tw.tween_property(node, \"scale\", base * amount, duration * 0.5)
		tw.tween_property(node, \"scale\", base, duration * 0.5)
	elif node is Node2D:
		var b2: Vector2 = (node as Node2D).scale
		tw.tween_property(node, \"scale\", b2 * amount, duration * 0.5)
		tw.tween_property(node, \"scale\", b2, duration * 0.5)
	return tw

func flash_modulate(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.1) -> Tween:
	var original := node.modulate
	var tw := create_tween()
	tw.tween_property(node, \"modulate\", color, duration)
	tw.tween_property(node, \"modulate\", original, duration)
	return tw
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "recipes": ["fade_canvas_item", "move_to_3d", "punch_scale", "flash_modulate"]})
