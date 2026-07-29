@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Character controllers & combat primitives for modern 2D/3D games.
## Human: assemble CharacterBody + collision + movement script + hitboxes.


func get_commands() -> Dictionary:
	return {
		"setup_character_2d": _setup_character_2d,
		"setup_character_3d": _setup_character_3d,
		"create_platformer_controller_script": _create_platformer_controller_script,
		"create_topdown_controller_script": _create_topdown_controller_script,
		"create_fps_controller_script": _create_fps_controller_script,
		"create_health_component_script": _create_health_component_script,
		"setup_hitbox": _setup_hitbox,
		"setup_hurtbox": _setup_hurtbox,
		"create_projectile_script": _create_projectile_script,
		"list_character_templates": _list_character_templates,
	}


func _list_character_templates(_params: Dictionary) -> Dictionary:
	return success({
		"templates": [
			{"id": "platformer_2d", "tools": ["setup_character_2d", "create_platformer_controller_script"]},
			{"id": "topdown_2d", "tools": ["setup_character_2d", "create_topdown_controller_script"]},
			{"id": "fps_3d", "tools": ["setup_character_3d", "create_fps_controller_script"]},
			{"id": "combat", "tools": ["create_health_component_script", "setup_hitbox", "setup_hurtbox", "create_projectile_script"]},
		],
		"hint": "Use create_input_map_preset first (platformer_2d / fps_basic).",
	})



func _setup_character_2d(params: Dictionary) -> Dictionary:
	## Full CharacterBody2D stack: body + collision + optional sprite + script.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var body := CharacterBody2D.new()
	body.name = optional_string(params, "name", "Player")
	body.collision_layer = optional_int(params, "collision_layer", 1)
	body.collision_mask = optional_int(params, "collision_mask", 1)
	var motion: String = optional_string(params, "motion_mode", "grounded")  # grounded|floating
	if motion == "floating":
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	else:
		body.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	add_child_with_undo(parent, body, root, "MCP: Setup CharacterBody2D")

	# Collision
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape_kind: String = optional_string(params, "shape", "capsule")
	var sx: float = float(params.get("shape_width", params.get("radius", 12.0)))
	var sy: float = float(params.get("shape_height", 28.0))
	match shape_kind:
		"circle":
			var c := CircleShape2D.new()
			c.radius = sx
			col.shape = c
		"rect", "rectangle":
			var r := RectangleShape2D.new()
			r.size = Vector2(sx * 2.0, sy)
			col.shape = r
		_:
			var cap := CapsuleShape2D.new()
			cap.radius = sx
			cap.height = sy
			col.shape = cap
	add_child_with_undo(body, col, root, "MCP: Character collision")

	var created: Array = [str(root.get_path_to(body)), str(root.get_path_to(col))]

	# Optional Sprite2D
	if optional_bool(params, "add_sprite", true):
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		var tex_path: String = optional_string(params, "texture_path", "")
		if not tex_path.is_empty():
			if not tex_path.begins_with("res://"):
				tex_path = "res://" + tex_path.trim_prefix("/")
			if ResourceLoader.exists(tex_path):
				spr.texture = load(tex_path)
		add_child_with_undo(body, spr, root, "MCP: Character sprite")
		created.append(str(root.get_path_to(spr)))

	# Controller script
	var style: String = optional_string(params, "controller", "platformer")  # platformer|topdown|none
	var script_path: String = optional_string(params, "script_path", "res://scripts/%s.gd" % body.name.to_snake_case())
	var script_result := {}
	if style != "none":
		if style == "topdown":
			script_result = _create_topdown_controller_script({
				"path": script_path,
				"overwrite": optional_bool(params, "overwrite", false),
				"speed": params.get("speed", 200.0),
			})
		else:
			script_result = _create_platformer_controller_script({
				"path": script_path,
				"overwrite": optional_bool(params, "overwrite", false),
				"speed": params.get("speed", 200.0),
				"jump_velocity": params.get("jump_velocity", -400.0),
			})
		if script_result.has("result"):
			var p: String = script_result["result"].get("path", script_path)
			var scr = load(p)
			if scr:
				body.set_script(scr)
		elif script_result.has("error") and not optional_bool(params, "overwrite", false):
			# Script may already exist — still try attach
			if FileAccess.file_exists(script_path):
				var scr2 = load(script_path)
				if scr2:
					body.set_script(scr2)

	# Optional Camera2D child
	if optional_bool(params, "add_camera", false):
		var cam := Camera2D.new()
		cam.name = "Camera2D"
		cam.enabled = true
		add_child_with_undo(body, cam, root, "MCP: Character camera")
		created.append(str(root.get_path_to(cam)))

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(body)),
		"type": "CharacterBody2D",
		"controller": style,
		"script_path": script_path,
		"created": created,
		"script": script_result.get("result", script_result),
	})


func _setup_character_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var body := CharacterBody3D.new()
	body.name = optional_string(params, "name", "Player")
	body.collision_layer = optional_int(params, "collision_layer", 1)
	body.collision_mask = optional_int(params, "collision_mask", 1)
	add_child_with_undo(parent, body, root, "MCP: Setup CharacterBody3D")

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var radius: float = float(params.get("radius", 0.4))
	var height: float = float(params.get("height", 1.8))
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	col.position = Vector3(0, height * 0.5, 0)
	add_child_with_undo(body, col, root, "MCP: Character3D collision")

	var mesh_path := ""
	if optional_bool(params, "add_mesh", true):
		var mi := MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		var cm := CapsuleMesh.new()
		cm.radius = radius
		cm.height = height
		mi.mesh = cm
		mi.position = Vector3(0, height * 0.5, 0)
		add_child_with_undo(body, mi, root, "MCP: Character3D mesh")
		mesh_path = str(root.get_path_to(mi))

	var script_path: String = optional_string(params, "script_path", "res://scripts/%s.gd" % body.name.to_snake_case())
	var style: String = optional_string(params, "controller", "fps")  # fps|none
	var script_result := {}
	if style == "fps":
		script_result = _create_fps_controller_script({
			"path": script_path,
			"overwrite": optional_bool(params, "overwrite", false),
			"speed": params.get("speed", 5.0),
			"jump_velocity": params.get("jump_velocity", 4.5),
		})
		if script_result.has("result"):
			var p: String = script_result["result"].get("path", script_path)
			var scr = load(p)
			if scr:
				body.set_script(scr)
		elif FileAccess.file_exists(script_path):
			var scr2 = load(script_path)
			if scr2:
				body.set_script(scr2)

	# Head + camera for FPS
	if optional_bool(params, "add_camera", true):
		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0, height * 0.85, 0)
		add_child_with_undo(body, head, root, "MCP: FPS head")
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.current = true
		add_child_with_undo(head, cam, root, "MCP: FPS camera")

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(body)),
		"type": "CharacterBody3D",
		"controller": style,
		"script_path": script_path,
		"mesh": mesh_path,
		"script": script_result.get("result", script_result),
	})


func _create_platformer_controller_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/player_platformer.gd")
	var speed: float = float(params.get("speed", 200.0))
	var jump_v: float = float(params.get("jump_velocity", -400.0))
	var content := """extends CharacterBody2D
## MCP platformer controller — InputMap: move_left/right, jump

@export var speed: float = %.1f
@export var jump_velocity: float = %.1f
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
""" % [speed, jump_v]
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "style": "platformer_2d", "actions": ["move_left", "move_right", "jump"]})


func _create_topdown_controller_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/player_topdown.gd")
	var speed: float = float(params.get("speed", 200.0))
	var content := """extends CharacterBody2D
## MCP top-down controller — InputMap: move_left/right/up/down

@export var speed: float = %.1f

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
""" % speed
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "style": "topdown_2d", "actions": ["move_left", "move_right", "move_up", "move_down"]})


func _create_fps_controller_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/player_fps.gd")
	var speed: float = float(params.get("speed", 5.0))
	var jump_v: float = float(params.get("jump_velocity", 4.5))
	var content := """extends CharacterBody3D
## MCP FPS controller — InputMap: move_*, jump. Mouse look on Head/Camera3D.

@export var speed: float = %.2f
@export var jump_velocity: float = %.2f
@export var mouse_sensitivity: float = 0.0025
@export var gravity_mult: float = 1.0

@onready var head: Node3D = $Head

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if head:
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_mult * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()
""" % [speed, jump_v]
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({
		"path": w.get("path", path),
		"style": "fps_3d",
		"actions": ["move_left", "move_right", "move_forward", "move_back", "jump"],
		"requires": "Child node Head with Camera3D (setup_character_3d adds this)",
	})


func _create_health_component_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/health_component.gd")
	var max_hp: float = float(params.get("max_health", 100.0))
	var content := """extends Node
## MCP HealthComponent — attach to any actor. Connect damaged/died for VFX/UI.

class_name HealthComponent
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health: float = %.1f
@export var invincible: bool = false

var current: float

func _ready() -> void:
	current = max_health
	health_changed.emit(current, max_health)

func take_damage(amount: float, source: Node = null) -> void:
	if invincible or current <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current <= 0.0:
		return
	current = minf(current + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current, max_health)

func is_alive() -> bool:
	return current > 0.0
""" % max_hp
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "class_name": "HealthComponent"})


func _setup_hitbox(params: Dictionary) -> Dictionary:
	## Damage-dealing Area (monitoring others).
	return _setup_combat_area(params, "Hitbox", true, false)


func _setup_hurtbox(params: Dictionary) -> Dictionary:
	## Damage-receiving Area (monitorable by hitboxes).
	return _setup_combat_area(params, "Hurtbox", false, true)


func _setup_combat_area(params: Dictionary, default_name: String, monitoring: bool, monitorable: bool) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var dim: String = optional_string(params, "dimension", "")
	if dim.is_empty():
		if parent is Node3D or parent is CharacterBody3D:
			dim = "3d"
		else:
			dim = "2d"
	var area: Node
	var col: Node
	if dim == "3d":
		area = Area3D.new()
		area.monitoring = optional_bool(params, "monitoring", monitoring)
		area.monitorable = optional_bool(params, "monitorable", monitorable)
		area.collision_layer = optional_int(params, "collision_layer", 4 if default_name == "Hitbox" else 2)
		area.collision_mask = optional_int(params, "collision_mask", 2 if default_name == "Hitbox" else 4)
		col = CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = float(params.get("radius", 0.5))
		col.shape = sh
	else:
		area = Area2D.new()
		area.monitoring = optional_bool(params, "monitoring", monitoring)
		area.monitorable = optional_bool(params, "monitorable", monitorable)
		area.collision_layer = optional_int(params, "collision_layer", 4 if default_name == "Hitbox" else 2)
		area.collision_mask = optional_int(params, "collision_mask", 2 if default_name == "Hitbox" else 4)
		col = CollisionShape2D.new()
		var sh2 := CircleShape2D.new()
		sh2.radius = float(params.get("radius", 16.0))
		col.shape = sh2
	area.name = optional_string(params, "name", default_name)
	col.name = "CollisionShape"
	add_child_with_undo(parent, area, root, "MCP: Add %s" % default_name)
	add_child_with_undo(area, col, root, "MCP: %s shape" % default_name)
	# Optional damage script on hitbox
	if default_name == "Hitbox" and optional_bool(params, "attach_damage_script", true):
		var dmg: float = float(params.get("damage", 10.0))
		var sp: String = optional_string(params, "script_path", "res://scripts/hitbox.gd")
		var scr_body := """extends Area2D
## MCP Hitbox — deals damage to bodies with take_damage or HealthComponent child.

@export var damage: float = %.1f
@export var one_shot: bool = false

func _ready() -> void:
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)

func _deal(target: Node) -> void:
	if target == null or target == get_parent():
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, get_parent())
	else:
		var hc := target.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(damage, get_parent())
	if one_shot:
		set_deferred("monitoring", false)

func _on_body(body: Node) -> void:
	_deal(body)

func _on_area(a: Node) -> void:
	_deal(a.get_parent() if a else null)
""" % dmg
		# Use Area3D script variant if 3d
		if dim == "3d":
			scr_body = scr_body.replace("extends Area2D", "extends Area3D")
		var wr := write_script_file(sp, scr_body, optional_bool(params, "overwrite", true))
		if wr.has("path"):
			var s = load(wr["path"])
			if s:
				area.set_script(s)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(area)),
		"type": area.get_class(),
		"role": default_name.to_lower(),
		"dimension": dim,
	})


func _create_projectile_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/projectile.gd")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var speed: float = float(params.get("speed", 400.0 if not is_3d else 20.0))
	var damage: float = float(params.get("damage", 10.0))
	var content: String
	if is_3d:
		content = """extends Area3D
## MCP projectile 3D

@export var speed: float = %.1f
@export var damage: float = %.1f
@export var lifetime: float = 3.0
var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	body_entered.connect(_hit)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

func _hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
	queue_free()
""" % [speed, damage]
	else:
		content = """extends Area2D
## MCP projectile 2D

@export var speed: float = %.1f
@export var damage: float = %.1f
@export var lifetime: float = 3.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_hit)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

func _hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, self)
	queue_free()
""" % [speed, damage]
	var w := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": w.get("path", path), "is_3d": is_3d})
