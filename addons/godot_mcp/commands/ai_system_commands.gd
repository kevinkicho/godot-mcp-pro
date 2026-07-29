@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## AI / NPC systems for modern games: nav chase, patrol, detection, FSM.


func get_commands() -> Dictionary:
	return {
		"setup_ai_agent_2d": _setup_ai_agent_2d,
		"setup_ai_agent_3d": _setup_ai_agent_3d,
		"create_chase_ai_script": _create_chase_ai_script,
		"create_patrol_ai_script": _create_patrol_ai_script,
		"setup_detection_area": _setup_detection_area,
		"create_gameplay_state_machine_script": _create_gameplay_state_machine_script,
		"create_interactable_script": _create_interactable_script,
		"list_ai_templates": _list_ai_templates,
	}


func _list_ai_templates(_params: Dictionary) -> Dictionary:
	return success({
		"templates": [
			{"id": "chase", "tool": "create_chase_ai_script", "needs": "NavigationAgent + target"},
			{"id": "patrol", "tool": "create_patrol_ai_script", "needs": "Marker2D/3D waypoints"},
			{"id": "detect", "tool": "setup_detection_area"},
			{"id": "fsm", "tool": "create_gameplay_state_machine_script"},
			{"id": "interact", "tool": "create_interactable_script"},
		],
	})


func _write_script(path: String, content: String, overwrite: bool) -> Dictionary:
	return write_script_file(path, content, overwrite)


func _setup_ai_agent_2d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var body: CharacterBody2D
	var created_body := false
	if parent is CharacterBody2D:
		body = parent as CharacterBody2D
	else:
		body = CharacterBody2D.new()
		body.name = optional_string(params, "name", "Enemy")
		body.collision_layer = optional_int(params, "collision_layer", 2)
		body.collision_mask = optional_int(params, "collision_mask", 1)
		add_child_with_undo(parent, body, root, "MCP: AI CharacterBody2D")
		created_body = true
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var sh := CircleShape2D.new()
		sh.radius = float(params.get("radius", 12.0))
		col.shape = sh
		add_child_with_undo(body, col, root, "MCP: AI collision")

	var agent := NavigationAgent2D.new()
	agent.name = optional_string(params, "agent_name", "NavigationAgent2D")
	agent.path_desired_distance = float(params.get("path_desired_distance", 4.0))
	agent.target_desired_distance = float(params.get("target_desired_distance", 8.0))
	add_child_with_undo(body, agent, root, "MCP: NavigationAgent2D")

	var behavior: String = optional_string(params, "behavior", "chase")  # chase|patrol|none
	var script_path: String = optional_string(params, "script_path", "res://scripts/%s_ai.gd" % body.name.to_snake_case())
	var script_info := {}
	if behavior == "chase":
		script_info = _create_chase_ai_script({
			"path": script_path,
			"is_3d": false,
			"speed": params.get("speed", 120.0),
			"overwrite": optional_bool(params, "overwrite", false),
			"target_group": optional_string(params, "target_group", "player"),
		})
	elif behavior == "patrol":
		script_info = _create_patrol_ai_script({
			"path": script_path,
			"is_3d": false,
			"speed": params.get("speed", 80.0),
			"overwrite": optional_bool(params, "overwrite", false),
		})
	if script_info.has("result"):
		var p: String = script_info["result"].get("path", script_path)
		var scr = load(p)
		if scr:
			body.set_script(scr)

	if optional_bool(params, "add_detection", true):
		_setup_detection_area({
			"parent_path": str(root.get_path_to(body)),
			"dimension": "2d",
			"radius": params.get("detect_radius", 160.0),
		})

	mark_current_scene_unsaved()
	return success({
		"body_path": str(root.get_path_to(body)),
		"agent_path": str(root.get_path_to(agent)),
		"created_body": created_body,
		"behavior": behavior,
		"script": script_info.get("result", script_info),
	})


func _setup_ai_agent_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var body: CharacterBody3D
	var created_body := false
	if parent is CharacterBody3D:
		body = parent as CharacterBody3D
	else:
		body = CharacterBody3D.new()
		body.name = optional_string(params, "name", "Enemy")
		add_child_with_undo(parent, body, root, "MCP: AI CharacterBody3D")
		created_body = true
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = float(params.get("radius", 0.4))
		cap.height = float(params.get("height", 1.6))
		col.shape = cap
		col.position = Vector3(0, cap.height * 0.5, 0)
		add_child_with_undo(body, col, root, "MCP: AI3D collision")

	var agent := NavigationAgent3D.new()
	agent.name = optional_string(params, "agent_name", "NavigationAgent3D")
	add_child_with_undo(body, agent, root, "MCP: NavigationAgent3D")

	var behavior: String = optional_string(params, "behavior", "chase")
	var script_path: String = optional_string(params, "script_path", "res://scripts/%s_ai.gd" % body.name.to_snake_case())
	var script_info := {}
	if behavior == "chase":
		script_info = _create_chase_ai_script({
			"path": script_path,
			"is_3d": true,
			"speed": params.get("speed", 3.5),
			"overwrite": optional_bool(params, "overwrite", false),
			"target_group": optional_string(params, "target_group", "player"),
		})
	elif behavior == "patrol":
		script_info = _create_patrol_ai_script({
			"path": script_path,
			"is_3d": true,
			"speed": params.get("speed", 2.5),
			"overwrite": optional_bool(params, "overwrite", false),
		})
	if script_info.has("result"):
		var p: String = script_info["result"].get("path", script_path)
		var scr = load(p)
		if scr:
			body.set_script(scr)

	mark_current_scene_unsaved()
	return success({
		"body_path": str(root.get_path_to(body)),
		"agent_path": str(root.get_path_to(agent)),
		"created_body": created_body,
		"behavior": behavior,
		"script": script_info.get("result", script_info),
	})


func _create_chase_ai_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/chase_ai.gd")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var speed: float = float(params.get("speed", 120.0 if not is_3d else 3.5))
	var group: String = optional_string(params, "target_group", "player")
	var content: String
	if is_3d:
		content = """extends CharacterBody3D
## MCP chase AI 3D — put player in group '%s'. Needs NavigationRegion3D baked + NavigationAgent3D child.

@export var speed: float = %.2f
@export var target_group: String = "%s"
@export var retarget_interval: float = 0.25

@onready var agent: NavigationAgent3D = $NavigationAgent3D
var _target: Node3D
var _t: float = 0.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= retarget_interval or _target == null or not is_instance_valid(_target):
		_t = 0.0
		_retarget()
	if _target == null or agent == null:
		return
	if agent.is_navigation_finished():
		return
	var next := agent.get_next_path_position()
	var dir := global_position.direction_to(next)
	velocity = dir * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if dir.length_squared() > 0.001:
		look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)

func _retarget() -> void:
	var nodes := get_tree().get_nodes_in_group(target_group)
	_target = nodes[0] as Node3D if nodes.size() > 0 else null
	if _target and agent:
		agent.target_position = _target.global_position
""" % [group, speed, group]
	else:
		content = """extends CharacterBody2D
## MCP chase AI 2D — put player in group '%s'. Needs NavigationRegion2D + NavigationAgent2D.

@export var speed: float = %.1f
@export var target_group: String = "%s"
@export var retarget_interval: float = 0.25

@onready var agent: NavigationAgent2D = $NavigationAgent2D
var _target: Node2D
var _t: float = 0.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= retarget_interval or _target == null or not is_instance_valid(_target):
		_t = 0.0
		_retarget()
	if _target == null or agent == null:
		return
	if agent.is_navigation_finished():
		return
	var next := agent.get_next_path_position()
	var dir := global_position.direction_to(next)
	velocity = dir * speed
	move_and_slide()

func _retarget() -> void:
	var nodes := get_tree().get_nodes_in_group(target_group)
	_target = nodes[0] as Node2D if nodes.size() > 0 else null
	if _target and agent:
		agent.target_position = _target.global_position
""" % [group, speed, group]
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "is_3d": is_3d, "target_group": group})


func _create_patrol_ai_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/patrol_ai.gd")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var speed: float = float(params.get("speed", 80.0 if not is_3d else 2.5))
	var content: String
	if is_3d:
		content = """extends CharacterBody3D
## MCP patrol AI 3D — assign waypoint_paths (NodePaths to Marker3D) or children named Waypoint*

@export var speed: float = %.2f
@export var waypoint_paths: Array[NodePath] = []
@export var wait_sec: float = 0.5

var _points: Array[Vector3] = []
var _i: int = 0
var _wait: float = 0.0

func _ready() -> void:
	for p in waypoint_paths:
		var n := get_node_or_null(p)
		if n is Node3D:
			_points.append((n as Node3D).global_position)
	if _points.is_empty():
		for c in get_children():
			if c is Marker3D or (c is Node3D and str(c.name).begins_with("Waypoint")):
				_points.append((c as Node3D).global_position)

func _physics_process(delta: float) -> void:
	if _points.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var target := _points[_i]
	var dir := global_position.direction_to(target)
	if global_position.distance_to(target) < 0.4:
		_i = (_i + 1) % _points.size()
		_wait = wait_sec
		velocity = Vector3.ZERO
	else:
		velocity = dir * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
""" % speed
	else:
		content = """extends CharacterBody2D
## MCP patrol AI 2D — assign waypoint_paths or Marker2D children named Waypoint*

@export var speed: float = %.1f
@export var waypoint_paths: Array[NodePath] = []
@export var wait_sec: float = 0.5

var _points: Array[Vector2] = []
var _i: int = 0
var _wait: float = 0.0

func _ready() -> void:
	for p in waypoint_paths:
		var n := get_node_or_null(p)
		if n is Node2D:
			_points.append((n as Node2D).global_position)
	if _points.is_empty():
		for c in get_children():
			if c is Marker2D or (c is Node2D and str(c.name).begins_with("Waypoint")):
				_points.append((c as Node2D).global_position)

func _physics_process(delta: float) -> void:
	if _points.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var target := _points[_i]
	var dir := global_position.direction_to(target)
	if global_position.distance_to(target) < 8.0:
		_i = (_i + 1) % _points.size()
		_wait = wait_sec
		velocity = Vector2.ZERO
	else:
		velocity = dir * speed
	move_and_slide()
""" % speed
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "is_3d": is_3d})


func _setup_detection_area(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var dim: String = optional_string(params, "dimension", "2d")
	var area: Node
	var col: Node
	if dim == "3d":
		area = Area3D.new()
		col = CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = float(params.get("radius", 8.0))
		col.shape = sh
	else:
		area = Area2D.new()
		col = CollisionShape2D.new()
		var sh2 := CircleShape2D.new()
		sh2.radius = float(params.get("radius", 160.0))
		col.shape = sh2
	area.name = optional_string(params, "name", "DetectionArea")
	area.set("monitoring", true)
	area.set("monitorable", false)
	area.set("collision_mask", optional_int(params, "collision_mask", 1))
	col.name = "CollisionShape"
	add_child_with_undo(parent, area, root, "MCP: Detection area")
	add_child_with_undo(area, col, root, "MCP: Detection shape")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(area)), "type": area.get_class()})


func _create_gameplay_state_machine_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/state_machine.gd")
	var content := """extends Node
## MCP gameplay FSM — attach states as child nodes with enter/exit/update methods.
## Or use string states via change_state("idle").

signal state_changed(from_state: String, to_state: String)

@export var initial_state: String = "idle"
var current: String = ""
var _states: Dictionary = {}  # name -> Node (optional)

func _ready() -> void:
	for c in get_children():
		_states[str(c.name).to_lower()] = c
	change_state(initial_state)

func change_state(next: String) -> void:
	next = next.to_lower()
	if next == current:
		return
	var prev := current
	if _states.has(current) and _states[current].has_method("exit"):
		_states[current].exit()
	current = next
	if _states.has(current) and _states[current].has_method("enter"):
		_states[current].enter()
	state_changed.emit(prev, current)

func _physics_process(delta: float) -> void:
	if _states.has(current) and _states[current].has_method("update"):
		_states[current].update(delta)

func is_state(name: String) -> bool:
	return current == name.to_lower()
"""
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path)})


func _create_interactable_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/interactable.gd")
	var content := """extends Area2D
## MCP interactable — player presses 'interact' while overlapping.

signal interacted(by: Node)

@export var prompt: String = "Press E"
@export var one_shot: bool = false
var _bodies: Array[Node] = []

func _ready() -> void:
	body_entered.connect(func(b): _bodies.append(b))
	body_exited.connect(func(b): _bodies.erase(b))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _bodies.is_empty():
		interacted.emit(_bodies[0])
		if one_shot:
			monitoring = false
"""
	if optional_bool(params, "is_3d", false):
		content = content.replace("extends Area2D", "extends Area3D")
	var w := _write_script(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "action": "interact"})
