@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## XR player rig depth — full VR avatar stack, movement, grab, teleport scaffolds.


func get_commands() -> Dictionary:
	return {
		"setup_xr_player_rig": _setup_player_rig,
		"create_xr_movement_script": _create_movement,
		"create_xr_grabber_script": _create_grabber,
		"create_xr_teleport_script": _create_teleport,
		"setup_xr_pickup_area": _setup_pickup,
		"list_xr_tools_catalog": _list_catalog,
		"list_xr_player_rig_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"setup_xr_origin", "set_xr_project_settings", "openxr_create_default_controller_bindings",
			"set_xr_passthrough_settings", "setup_xr_composition_layer_quad",
		],
		"workflow": [
			"set_xr_project_settings enabled=true",
			"setup_xr_player_rig",
			"create_xr_movement_script + attach",
			"openxr_create_default_controller_bindings",
		],
	})


func _list_catalog(_params: Dictionary) -> Dictionary:
	return success({
		"setup": ["setup_xr_origin", "setup_xr_player_rig", "add_xr_controller", "add_xr_hand_modifier"],
		"openxr": [
			"create_openxr_action_map", "openxr_add_action_set", "openxr_add_action",
			"openxr_bind_action", "openxr_create_default_controller_bindings",
		],
		"passthrough": ["set_xr_passthrough_settings", "setup_xr_composition_layer_quad"],
		"gameplay": [
			"create_xr_movement_script", "create_xr_grabber_script", "create_xr_teleport_script",
			"setup_xr_pickup_area",
		],
		"pipelines": ["pipeline_xr_setup"],
	})


func _setup_player_rig(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")

	var origin := XROrigin3D.new()
	origin.name = optional_string(params, "name", "XROrigin3D")
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		origin.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	add_child_with_undo(parent, origin, root, "MCP: XR player rig origin")

	var cam := XRCamera3D.new()
	cam.name = "XRCamera3D"
	cam.current = optional_bool(params, "make_current", true)
	add_child_with_undo(origin, cam, root, "MCP: XRCamera3D")

	var left := XRController3D.new()
	left.name = "LeftController"
	left.tracker = &"left_hand"
	add_child_with_undo(origin, left, root, "MCP: Left XR controller")

	var right := XRController3D.new()
	right.name = "RightController"
	right.tracker = &"right_hand"
	add_child_with_undo(origin, right, root, "MCP: Right XR controller")

	# Optional simple controller meshes for debugging
	if optional_bool(params, "debug_meshes", true):
		for ctrl in [left, right]:
			var mi := MeshInstance3D.new()
			mi.name = "DebugMesh"
			var box := BoxMesh.new()
			box.size = Vector3(0.05, 0.05, 0.12)
			mi.mesh = box
			add_child_with_undo(ctrl, mi, root, "MCP: XR debug mesh")

	var scripts_attached := {}
	if optional_bool(params, "add_movement", true):
		var mpath: String = optional_string(params, "movement_script", "res://scripts/xr_movement.gd")
		if not FileAccess.file_exists(mpath):
			_create_movement({"path": mpath, "overwrite": true})
		var mnode := Node.new()
		mnode.name = "XRMovement"
		var ms = load(mpath)
		if ms:
			mnode.set_script(ms)
		add_child_with_undo(origin, mnode, root, "MCP: XR movement")
		if "origin_path" in mnode:
			mnode.set("origin_path", NodePath(".."))
		if "camera_path" in mnode:
			mnode.set("camera_path", NodePath("../XRCamera3D"))
		scripts_attached["movement"] = str(root.get_path_to(mnode))

	if optional_bool(params, "add_grabbers", true):
		var gpath: String = optional_string(params, "grabber_script", "res://scripts/xr_grabber.gd")
		if not FileAccess.file_exists(gpath):
			_create_grabber({"path": gpath, "overwrite": true})
		for ctrl in [left, right]:
			var g := Node3D.new()
			g.name = "Grabber"
			var gs = load(gpath)
			if gs:
				g.set_script(gs)
			add_child_with_undo(ctrl, g, root, "MCP: XR grabber")

	if optional_bool(params, "enable_openxr_settings", true):
		ProjectSettings.set_setting("xr/openxr/enabled", true)
		ProjectSettings.set_setting("xr/shaders/enabled", true)
		ProjectSettings.save()

	mark_current_scene_unsaved()
	return success({
		"origin_path": str(root.get_path_to(origin)),
		"camera_path": str(root.get_path_to(cam)),
		"left_controller": str(root.get_path_to(left)),
		"right_controller": str(root.get_path_to(right)),
		"scripts": scripts_attached,
		"hint": "openxr_create_default_controller_bindings; export with XR-enabled templates",
	})


func _create_movement(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/xr_movement.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Continuous XR locomotion — thumbstick on right controller moves XROrigin.

@export var origin_path: NodePath
@export var camera_path: NodePath
@export var controller_path: NodePath = NodePath(\"../RightController\")
@export var move_speed: float = 2.0
@export var deadzone: float = 0.2
@export var input_action: StringName = &\"primary\"

var _origin: XROrigin3D
var _camera: XRCamera3D
var _controller: XRController3D

func _ready() -> void:
	_origin = get_node_or_null(origin_path) as XROrigin3D
	_camera = get_node_or_null(camera_path) as XRCamera3D
	_controller = get_node_or_null(controller_path) as XRController3D
	if _origin == null and get_parent() is XROrigin3D:
		_origin = get_parent() as XROrigin3D
	if _camera == null and _origin:
		_camera = _origin.get_node_or_null(\"XRCamera3D\") as XRCamera3D

func _physics_process(delta: float) -> void:
	if _origin == null or _controller == null:
		return
	var v: Vector2 = Vector2.ZERO
	if _controller.get_is_active():
		v = _controller.get_vector2(input_action)
	if v.length() < deadzone:
		return
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if _camera:
		var basis := _camera.global_transform.basis
		forward = -basis.z
		right = basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
	var motion := (right * v.x + forward * -v.y) * move_speed * delta
	_origin.global_position += motion
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path})


func _create_grabber(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/xr_grabber.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node3D
## XR grabber — pick up RigidBody3D in nearby Area3D on grip.

@export var grab_action: StringName = &\"grip\"
@export var grab_area_path: NodePath
@export var max_distance: float = 0.25

var _controller: XRController3D
var _area: Area3D
var _held: RigidBody3D
var _held_parent: Node
var _was_pressed: bool = false

func _ready() -> void:
	_controller = get_parent() as XRController3D
	if grab_area_path != NodePath():
		_area = get_node_or_null(grab_area_path) as Area3D
	if _area == null:
		_area = Area3D.new()
		_area.name = \"GrabArea\"
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = max_distance
		cs.shape = sphere
		_area.add_child(cs)
		add_child(_area)

func _physics_process(_delta: float) -> void:
	if _controller == null or not _controller.get_is_active():
		return
	var pressed := _controller.is_button_pressed(grab_action)
	if pressed and not _was_pressed:
		_try_grab()
	elif not pressed and _was_pressed:
		_release()
	_was_pressed = pressed
	if _held:
		_held.global_transform = global_transform

func _try_grab() -> void:
	if _held or _area == null:
		return
	for b in _area.get_overlapping_bodies():
		if b is RigidBody3D:
			_held = b
			_held_parent = _held.get_parent()
			_held.freeze = true
			_held.reparent(self)
			return

func _release() -> void:
	if _held == null:
		return
	_held.freeze = false
	if _held_parent:
		_held.reparent(_held_parent)
	_held = null
	_held_parent = null
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path})


func _create_teleport(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/xr_teleport.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Node
## Simple XR teleport — ray from controller, teleport origin on trigger release.

@export var origin_path: NodePath
@export var controller_path: NodePath
@export var teleport_action: StringName = &\"trigger_click\"
@export var max_distance: float = 10.0
@export var collision_mask: int = 1

var _origin: XROrigin3D
var _controller: XRController3D
var _aim_point: Vector3
var _has_aim: bool = false
var _was: bool = false

func _ready() -> void:
	_origin = get_node_or_null(origin_path) as XROrigin3D
	_controller = get_node_or_null(controller_path) as XRController3D

func _physics_process(_delta: float) -> void:
	if _origin == null or _controller == null or not _controller.get_is_active():
		return
	var space := _controller.get_world_3d().direct_space_state
	var from := _controller.global_position
	var to := from + (-_controller.global_transform.basis.z) * max_distance
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = collision_mask
	var hit := space.intersect_ray(q)
	_has_aim = not hit.is_empty()
	if _has_aim:
		_aim_point = hit.position
	var pressed := _controller.is_button_pressed(teleport_action)
	if _was and not pressed and _has_aim:
		# Keep camera offset roughly
		var cam := _origin.get_node_or_null(\"XRCamera3D\") as XRCamera3D
		var offset := Vector3.ZERO
		if cam:
			offset = _origin.global_position - Vector3(cam.global_position.x, _origin.global_position.y, cam.global_position.z)
		_origin.global_position = Vector3(_aim_point.x, _origin.global_position.y, _aim_point.z) + offset
	_was = pressed
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path})


func _setup_pickup(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var body := RigidBody3D.new()
	body.name = optional_string(params, "name", "Pickup")
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(
		float(params.get("size_x", 0.1)),
		float(params.get("size_y", 0.1)),
		float(params.get("size_z", 0.1))
	)
	mesh.mesh = box
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	col.shape = sh
	add_child_with_undo(parent, body, root, "MCP: XR pickup")
	add_child_with_undo(body, mesh, root, "MCP: pickup mesh")
	add_child_with_undo(body, col, root, "MCP: pickup col")
	if params.has("position") and params["position"] is Dictionary:
		var p: Dictionary = params["position"]
		body.position = Vector3(float(p.get("x", 0)), float(p.get("y", 1)), float(p.get("z", -1)))
	else:
		body.position = Vector3(0, 1, -1)
	body.add_to_group("xr_pickup", true)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(body)), "group": "xr_pickup"})
