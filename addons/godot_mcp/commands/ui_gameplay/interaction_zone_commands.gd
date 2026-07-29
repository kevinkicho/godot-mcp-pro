@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Interaction zones - Area2D/3D use/talk/pickup structure (gameplay systems).


func get_commands() -> Dictionary:
	return {
		"setup_interaction_zone": _setup_interaction_zone,
		"setup_interaction_prompt_ui": _setup_interaction_prompt_ui,
		"create_interaction_controller_script": _create_interaction_controller_script,
		"bind_interaction_action": _bind_interaction_action,
		"list_interaction_zone_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"flow": [
			"setup_interaction_zone kind=use|talk|pickup",
			"create_interaction_controller_script on player",
			"setup_interaction_prompt_ui",
			"bind_interaction_action action=interact",
			"playtest_sequence with action interact",
		],
		"related": ["create_interactable_script", "bind_interaction", "setup_area", "dialogue_*"],
	})


func _setup_interaction_zone(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", _guess_3d(parent))
	var kind: String = optional_string(params, "kind", "use").to_lower()  # use|talk|pickup|trigger
	var zone_name: String = optional_string(params, "name", "InteractionZone")

	var area: Node
	var shape_node: Node
	if is_3d:
		var a3 := Area3D.new()
		a3.name = zone_name
		a3.monitoring = true
		a3.monitorable = true
		if params.has("collision_layer"):
			a3.collision_layer = int(params["collision_layer"])
		if params.has("collision_mask"):
			a3.collision_mask = int(params["collision_mask"])
		else:
			a3.collision_mask = 1
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sh := SphereShape3D.new()
		sh.radius = float(params.get("radius", 1.5))
		col.shape = sh
		area = a3
		shape_node = col
	else:
		var a2 := Area2D.new()
		a2.name = zone_name
		a2.monitoring = true
		a2.monitorable = true
		if params.has("collision_layer"):
			a2.collision_layer = int(params["collision_layer"])
		if params.has("collision_mask"):
			a2.collision_mask = int(params["collision_mask"])
		var col2 := CollisionShape2D.new()
		col2.name = "CollisionShape2D"
		var sh2 := CircleShape2D.new()
		sh2.radius = float(params.get("radius", 32.0))
		col2.shape = sh2
		area = a2
		shape_node = col2

	area.set_meta("interaction_kind", kind)
	area.set_meta("prompt", optional_string(params, "prompt", _default_prompt(kind)))
	area.set_meta("interaction_id", optional_string(params, "interaction_id", kind + "_" + zone_name))
	if params.has("dialogue_path"):
		area.set_meta("dialogue_path", str(params["dialogue_path"]))
	if params.has("item_id"):
		area.set_meta("item_id", str(params["item_id"]))

	add_child_with_undo(parent, area, root, "MCP: Interaction zone")
	add_child_with_undo(area, shape_node, root, "MCP: Interaction shape")

	# Optional attach interactable script
	var script_path: String = optional_string(params, "script_path", "res://scripts/interaction_zone.gd")
	if optional_bool(params, "create_script", true):
		_write_zone_script(script_path, is_3d, kind)
		if ResourceLoader.exists(script_path) or FileAccess.file_exists(script_path):
			var scr = load(script_path)
			if scr:
				area.set_script(scr)

	if params.has("position"):
		if area is Node3D:
			(area as Node3D).position = _v3(params["position"])
		elif area is Node2D:
			(area as Node2D).position = _v2(params["position"])

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(area)),
		"kind": kind,
		"is_3d": is_3d,
		"prompt": area.get_meta("prompt"),
		"script_path": script_path,
	})


func _default_prompt(kind: String) -> String:
	match kind:
		"talk": return "Talk [E]"
		"pickup": return "Pick up [E]"
		"trigger": return ""
		_: return "Use [E]"


func _write_zone_script(path: String, is_3d: bool, kind: String) -> void:
	if FileAccess.file_exists(path) and true:
		# Only write if missing unless we always overwrite when not exists
		pass
	if FileAccess.file_exists(path):
		return
	var body_type := "CharacterBody3D" if is_3d else "CharacterBody2D"
	var content := """extends Area%s
## MCP interaction zone - overlap + interact action.
signal interacted(who: Node)
signal player_entered(who: Node)
signal player_exited(who: Node)

@export var prompt: String = "Use [E]"
@export var interaction_kind: String = "%s"
@export var player_group: String = "player"
@export var interact_action: String = "interact"
@export var one_shot: bool = false

var _player_inside: Node = null
var _done: bool = false

func _ready() -> void:
	if has_meta("prompt"):
		prompt = str(get_meta("prompt"))
	if has_meta("interaction_kind"):
		interaction_kind = str(get_meta("interaction_kind"))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group) or body is %s:
		_player_inside = body
		player_entered.emit(body)

func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
		player_exited.emit(body)

func _unhandled_input(event: InputEvent) -> void:
	if _done or _player_inside == null:
		return
	if event.is_action_pressed(interact_action):
		interacted.emit(_player_inside)
		if one_shot:
			_done = true
		get_viewport().set_input_as_handled()

func can_interact() -> bool:
	return _player_inside != null and not _done
""" % ["3D" if is_3d else "2D", kind, body_type]
	write_script_file(path, content, false)


func _setup_interaction_prompt_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "InteractionPromptLayer")
	layer.layer = optional_int(params, "layer", 20)
	var label := Label.new()
	label.name = "PromptLabel"
	label.text = optional_string(params, "text", "")
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.85
	label.anchor_bottom = 0.85
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -20
	label.offset_bottom = 20
	add_child_with_undo(parent, layer, root, "MCP: Prompt layer")
	add_child_with_undo(layer, label, root, "MCP: Prompt label")
	var script_path: String = optional_string(params, "script_path", "res://scripts/interaction_prompt_ui.gd")
	if optional_bool(params, "create_script", true) and not FileAccess.file_exists(script_path):
		var scr := """extends CanvasLayer
## Shows prompt when InteractionZone signals player_entered.
@onready var label: Label = $PromptLabel

func show_prompt(text: String) -> void:
	if label:
		label.text = text
		label.visible = not text.is_empty()

func hide_prompt() -> void:
	if label:
		label.visible = false
"""
		write_script_file(script_path, scr, false)
	if FileAccess.file_exists(script_path):
		layer.set_script(load(script_path))
	mark_current_scene_unsaved()
	return success({
		"layer_path": str(root.get_path_to(layer)),
		"label_path": str(root.get_path_to(label)),
		"script_path": script_path,
	})


func _create_interaction_controller_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/interaction_controller.gd")
	var is_3d: bool = optional_bool(params, "is_3d", true)
	var content := """extends Node
## MCP interaction controller - finds nearest zone / listens to global interact.
## Attach to player or use as child of CharacterBody.

@export var interact_action: String = "interact"
@export var prompt_path: NodePath
@export var max_distance: float = 3.0

var _zones: Array = []
var _prompt: Node = null

func _ready() -> void:
	if not prompt_path.is_empty():
		_prompt = get_node_or_null(prompt_path)
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().current_scene if get_tree().current_scene else get_tree().root)

func _on_node_added(n: Node) -> void:
	if n.has_signal("player_entered") and n.has_method("can_interact"):
		_wire(n)

func _scan(n: Node) -> void:
	if n == null:
		return
	if n.has_signal("player_entered") and n.has_method("can_interact"):
		_wire(n)
	for c in n.get_children():
		_scan(c)

func _wire(zone: Node) -> void:
	if zone in _zones:
		return
	_zones.append(zone)
	if not zone.player_entered.is_connected(_on_enter):
		zone.player_entered.connect(_on_enter)
	if not zone.player_exited.is_connected(_on_exit):
		zone.player_exited.connect(_on_exit)

func _on_enter(who: Node) -> void:
	if who != get_parent() and who != self:
		return
	var z := _nearest_zone()
	if z and _prompt and _prompt.has_method("show_prompt"):
		_prompt.show_prompt(str(z.get("prompt") if "prompt" in z else z.get_meta("prompt", "Use [E]")))

func _on_exit(_who: Node) -> void:
	if _prompt and _prompt.has_method("hide_prompt"):
		_prompt.hide_prompt()

func _nearest_zone() -> Node:
	for z in _zones:
		if is_instance_valid(z) and z.has_method("can_interact") and z.can_interact():
			return z
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action):
		var z := _nearest_zone()
		if z and z.has_signal("interacted"):
			z.interacted.emit(get_parent())
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	# Optionally attach to node
	var attach: String = optional_string(params, "attach_to", "")
	if not attach.is_empty():
		var n := find_node_by_path(attach)
		if n:
			var child := Node.new()
			child.name = "InteractionController"
			child.set_script(load(path))
			var root := get_edited_root()
			add_child_with_undo(n, child, root, "MCP: Interaction controller")
			mark_current_scene_unsaved()
			return success({"path": path, "attached": str(root.get_path_to(child)), "is_3d": is_3d})
	return success({"path": path, "is_3d": is_3d})


func _bind_interaction_action(params: Dictionary) -> Dictionary:
	var action: String = optional_string(params, "action", "interact")
	var key: String = optional_string(params, "key", "E")
	# ProjectSettings input map
	var key_ev := InputEventKey.new()
	# Map letter to keycode
	var kc := OS.find_keycode_from_string(key)
	if kc == KEY_NONE:
		kc = KEY_E
	key_ev.physical_keycode = kc as Key
	if not ProjectSettings.has_setting("input/" + action):
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": 0.5,
			"events": [key_ev],
		})
	else:
		var cur = ProjectSettings.get_setting("input/" + action)
		# leave existing
		pass
	# Live InputMap
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Avoid duplicate events if possible
	InputMap.action_add_event(action, key_ev)
	ProjectSettings.save()
	return success({"action": action, "key": key, "keycode": kc})


func _guess_3d(n: Node) -> bool:
	if n is Node3D:
		return true
	if n is Node2D or n is Control:
		return false
	var p := n.get_parent()
	while p:
		if p is Node3D:
			return true
		if p is Node2D:
			return false
		p = p.get_parent()
	return true


func _v3(v: Variant) -> Vector3:
	if v is Dictionary:
		return Vector3(float(v.get("x", 0)), float(v.get("y", 0)), float(v.get("z", 0)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


func _v2(v: Variant) -> Vector2:
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO
