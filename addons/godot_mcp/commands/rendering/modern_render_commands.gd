@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Modern rendering presets & camera systems for polished 2D/3D games.


func get_commands() -> Dictionary:
	return {
		"apply_environment_preset": _apply_environment_preset,
		"setup_camera_follow_2d": _setup_camera_follow_2d,
		"setup_third_person_camera": _setup_third_person_camera,
		"setup_orbit_camera_3d": _setup_orbit_camera_3d,
		"create_minimap_viewport": _create_minimap_viewport,
		"list_render_presets": _list_render_presets,
	}


func _list_render_presets(_params: Dictionary) -> Dictionary:
	return success({
		"environment_presets": [
			"cinematic", "outdoor_day", "outdoor_night", "indoor", "stylized", "horror", "clean",
		],
		"camera": ["setup_camera_follow_2d", "setup_third_person_camera", "setup_orbit_camera_3d"],
		"ui": ["create_minimap_viewport"],
	})


func _apply_environment_preset(params: Dictionary) -> Dictionary:
	## One-shot modern look: WorldEnvironment + tuned postFX.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var preset: String = optional_string(params, "preset", "cinematic")

	var world_env: WorldEnvironment = null
	for c in parent.get_children():
		if c is WorldEnvironment:
			world_env = c as WorldEnvironment
			break
	var created := false
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = optional_string(params, "name", "WorldEnvironment")
		add_child_with_undo(parent, world_env, root, "MCP: WorldEnvironment preset")
		created = true

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	match preset:
		"outdoor_day":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.45, 0.65, 0.95)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.7, 0.75, 0.85)
			env.ambient_light_energy = 0.35
			env.tonemap_exposure = 1.0
			env.glow_enabled = true
			env.glow_intensity = 0.4
			env.ssao_enabled = true
			env.ssao_intensity = 1.5
			env.sdfgi_enabled = optional_bool(params, "sdfgi", true)
			env.fog_enabled = true
			env.fog_light_color = Color(0.7, 0.8, 0.95)
			env.fog_density = 0.0015
		"outdoor_night":
			env.background_color = Color(0.02, 0.03, 0.08)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.15, 0.18, 0.35)
			env.ambient_light_energy = 0.15
			env.tonemap_exposure = 1.1
			env.glow_enabled = true
			env.glow_intensity = 0.9
			env.glow_bloom = 0.15
			env.ssao_enabled = true
			env.fog_enabled = true
			env.fog_density = 0.004
			env.fog_light_color = Color(0.1, 0.12, 0.25)
		"indoor":
			env.background_color = Color(0.12, 0.12, 0.14)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.5, 0.48, 0.45)
			env.ambient_light_energy = 0.25
			env.ssao_enabled = true
			env.ssao_intensity = 2.5
			env.ssr_enabled = true
			env.glow_enabled = true
			env.glow_intensity = 0.5
			env.sdfgi_enabled = optional_bool(params, "sdfgi", false)
		"stylized":
			env.background_color = Color(0.55, 0.72, 0.95)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(1, 0.95, 0.9)
			env.ambient_light_energy = 0.55
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.glow_enabled = true
			env.glow_intensity = 0.6
			env.glow_bloom = 0.05
			env.ssao_enabled = false
		"horror":
			env.background_color = Color(0.01, 0.01, 0.02)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.08, 0.05, 0.1)
			env.ambient_light_energy = 0.08
			env.tonemap_exposure = 0.85
			env.glow_enabled = true
			env.glow_intensity = 1.2
			env.fog_enabled = true
			env.fog_density = 0.02
			env.fog_light_color = Color(0.05, 0.02, 0.08)
			env.ssao_enabled = true
			env.ssao_intensity = 3.0
		"clean":
			env.background_color = Color(0.2, 0.2, 0.22)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.8, 0.8, 0.8)
			env.ambient_light_energy = 0.4
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.glow_enabled = false
			env.ssao_enabled = false
		_:  # cinematic default
			env.background_color = Color(0.08, 0.09, 0.12)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.4, 0.42, 0.5)
			env.ambient_light_energy = 0.2
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 0.95
			env.glow_enabled = true
			env.glow_intensity = 0.7
			env.glow_bloom = 0.08
			env.ssao_enabled = true
			env.ssao_intensity = 2.0
			env.ssr_enabled = true
			env.sdfgi_enabled = optional_bool(params, "sdfgi", true)
			env.fog_enabled = true
			env.fog_density = 0.002
			env.fog_light_color = Color(0.3, 0.35, 0.45)

	if params.has("background_color"):
		var bc = params["background_color"]
		if bc is String:
			env.background_color = Color.html(str(bc)) if str(bc).begins_with("#") else env.background_color

	world_env.environment = env
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(world_env)),
		"preset": preset,
		"created": created,
		"features": {
			"glow": env.glow_enabled,
			"ssao": env.ssao_enabled,
			"ssr": env.ssr_enabled,
			"sdfgi": env.sdfgi_enabled,
			"fog": env.fog_enabled,
		},
	})


func _setup_camera_follow_2d(params: Dictionary) -> Dictionary:
	## Camera2D that follows a target via RemoteTransform2D or script.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var cam := Camera2D.new()
	cam.name = optional_string(params, "name", "FollowCamera2D")
	cam.enabled = true
	cam.position_smoothing_enabled = optional_bool(params, "smoothing", true)
	cam.position_smoothing_speed = float(params.get("smoothing_speed", 8.0))
	if params.has("zoom"):
		var z = params["zoom"]
		if z is float or z is int:
			cam.zoom = Vector2(float(z), float(z))
		elif z is Array and z.size() >= 2:
			cam.zoom = Vector2(float(z[0]), float(z[1]))
	if params.has("limit_left"):
		cam.limit_left = int(params["limit_left"])
	if params.has("limit_top"):
		cam.limit_top = int(params["limit_top"])
	if params.has("limit_right"):
		cam.limit_right = int(params["limit_right"])
	if params.has("limit_bottom"):
		cam.limit_bottom = int(params["limit_bottom"])
	add_child_with_undo(parent, cam, root, "MCP: Follow Camera2D")

	var target_path: String = optional_string(params, "target_path", "")
	var mode: String = optional_string(params, "mode", "script")  # script|child
	if mode == "child" and not target_path.is_empty():
		# Reparent approach: put camera under target
		var target := find_node_by_path(target_path)
		if target:
			# Already added under parent; user can reparent manually - use RemoteTransform instead
			pass

	if not target_path.is_empty() and mode != "child":
		var sp: String = optional_string(params, "script_path", "res://scripts/camera_follow_2d.gd")
		var scr := """extends Camera2D
## MCP follow camera 2D

@export var target_path: NodePath
@export var offset: Vector2 = Vector2.ZERO
@export var look_ahead: float = 0.0

var _target: Node2D

func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	enabled = true

func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	var la := Vector2.ZERO
	if look_ahead != 0.0 and "velocity" in _target:
		la = _target.velocity.normalized() * look_ahead
	global_position = _target.global_position + offset + la
"""
		var wpath := sp
		if not FileAccess.file_exists(sp) or optional_bool(params, "overwrite", true):
			var derr := ensure_parent_dir(sp)
			if derr.is_empty():
				var f := FileAccess.open(sp, FileAccess.WRITE)
				if f:
					f.store_string(scr)
					f.close()
					EditorInterface.get_resource_filesystem().update_file(sp)
		var s = load(sp)
		if s:
			cam.set_script(s)
			cam.set("target_path", NodePath(target_path) if not target_path.begins_with("/") else NodePath(target_path))
			# Prefer relative path from camera to target
			var target_node := find_node_by_path(target_path)
			if target_node:
				cam.set("target_path", cam.get_path_to(target_node))

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(cam)),
		"target_path": target_path,
		"mode": mode,
	})


func _setup_third_person_camera(params: Dictionary) -> Dictionary:
	## SpringArm3D + Camera3D under a pivot (attach under player or as sibling).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var pivot := Node3D.new()
	pivot.name = optional_string(params, "name", "CameraPivot")
	if params.has("position"):
		var p = params["position"]
		if p is Array and p.size() >= 3:
			pivot.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	else:
		pivot.position = Vector3(0, float(params.get("height", 1.6)), 0)
	add_child_with_undo(parent, pivot, root, "MCP: Camera pivot")

	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = float(params.get("arm_length", 4.0))
	arm.collision_mask = optional_int(params, "collision_mask", 1)
	arm.margin = float(params.get("margin", 0.2))
	# Rotate arm to look from behind
	arm.rotation_degrees = Vector3(float(params.get("pitch_deg", -15.0)), 0, 0)
	add_child_with_undo(pivot, arm, root, "MCP: SpringArm3D")

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = optional_bool(params, "current", true)
	cam.fov = float(params.get("fov", 70.0))
	add_child_with_undo(arm, cam, root, "MCP: Third person camera")

	if optional_bool(params, "attach_look_script", true):
		var sp: String = optional_string(params, "script_path", "res://scripts/third_person_camera.gd")
		var scr := """extends Node3D
## MCP third-person camera pivot - mouse look. Attach to CameraPivot (parent of SpringArm3D).

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 45.0

@onready var arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if arm:
			arm.rotate_x(-event.relative.y * mouse_sensitivity)
			arm.rotation.x = clampf(arm.rotation.x, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
"""
		var derr := ensure_parent_dir(sp)
		if derr.is_empty():
			var f := FileAccess.open(sp, FileAccess.WRITE)
			if f:
				f.store_string(scr)
				f.close()
				EditorInterface.get_resource_filesystem().update_file(sp)
		var s = load(sp)
		if s:
			pivot.set_script(s)

	mark_current_scene_unsaved()
	return success({
		"pivot_path": str(root.get_path_to(pivot)),
		"arm_path": str(root.get_path_to(arm)),
		"camera_path": str(root.get_path_to(cam)),
	})


func _setup_orbit_camera_3d(params: Dictionary) -> Dictionary:
	## Free orbit camera for editors / showcases / strategy games.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var pivot := Node3D.new()
	pivot.name = optional_string(params, "name", "OrbitCamera")
	add_child_with_undo(parent, pivot, root, "MCP: Orbit pivot")
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, float(params.get("height", 8.0)), float(params.get("distance", 12.0)))
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	cam.current = optional_bool(params, "current", true)
	add_child_with_undo(pivot, cam, root, "MCP: Orbit camera")
	var sp: String = optional_string(params, "script_path", "res://scripts/orbit_camera.gd")
	var scr := """extends Node3D
## MCP orbit camera - LMB drag rotate, wheel zoom.

@export var rotate_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 1.0
@export var min_distance: float = 2.0
@export var max_distance: float = 40.0

@onready var cam: Camera3D = $Camera3D
var _dragging := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and cam:
			var d := cam.position.length()
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				d = maxf(min_distance, d - zoom_sensitivity)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				d = minf(max_distance, d + zoom_sensitivity)
			cam.position = cam.position.normalized() * d
	if event is InputEventMouseMotion and _dragging:
		rotate_y(-event.relative.x * rotate_sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotate_sensitivity)
"""
	var derr := ensure_parent_dir(sp)
	if derr.is_empty():
		var f := FileAccess.open(sp, FileAccess.WRITE)
		if f:
			f.store_string(scr)
			f.close()
			EditorInterface.get_resource_filesystem().update_file(sp)
	var s = load(sp)
	if s:
		pivot.set_script(s)
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(pivot)), "camera_path": str(root.get_path_to(cam))})


func _create_minimap_viewport(params: Dictionary) -> Dictionary:
	## SubViewport minimap camera looking at the world from above.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)

	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "Minimap")
	layer.layer = optional_int(params, "layer", 15)
	add_child_with_undo(parent, layer, root, "MCP: Minimap layer")

	var container := SubViewportContainer.new()
	container.name = "SubViewportContainer"
	container.stretch = true
	container.custom_minimum_size = Vector2(
		float(params.get("width", 180)),
		float(params.get("height", 180))
	)
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.offset_left = -float(params.get("width", 180)) - 16
	container.offset_top = 16
	container.offset_right = -16
	container.offset_bottom = float(params.get("height", 180)) + 16
	add_child_with_undo(layer, container, root, "MCP: Minimap container")

	var sv := SubViewport.new()
	sv.name = "SubViewport"
	sv.size = Vector2i(int(params.get("width", 180)), int(params.get("height", 180)))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# world_2d/world_3d: set at runtime to share the game world (editor scene root
	# is not the play viewport). Agent can update_property after play, or use a script.
	add_child_with_undo(container, sv, root, "MCP: Minimap viewport")

	var is_3d: bool = optional_bool(params, "is_3d", false)
	if is_3d:
		var cam3 := Camera3D.new()
		cam3.name = "MinimapCamera"
		cam3.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam3.size = float(params.get("ortho_size", 40.0))
		cam3.position = Vector3(0, float(params.get("height", 50.0)), 0)
		cam3.rotation_degrees = Vector3(-90, 0, 0)
		cam3.current = true
		add_child_with_undo(sv, cam3, root, "MCP: Minimap cam3d")
	else:
		var cam2 := Camera2D.new()
		cam2.name = "MinimapCamera"
		cam2.enabled = true
		cam2.zoom = Vector2(
			float(params.get("zoom", 0.15)),
			float(params.get("zoom", 0.15))
		)
		add_child_with_undo(sv, cam2, root, "MCP: Minimap cam2d")

	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(layer)),
		"viewport_path": str(root.get_path_to(sv)),
		"is_3d": is_3d,
		"hint": "For 3D, set SubViewport.world_3d to the main viewport world or instance a remote camera target follow script.",
	})
