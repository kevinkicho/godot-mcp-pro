@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Cinematic / FPS cameras - path track, look-at target, first-person rig.


func get_commands() -> Dictionary:
	return {
		"setup_first_person_camera": _setup_fps_cam,
		"setup_cinematic_path_camera": _setup_path_cam,
		"setup_camera_look_at_target": _look_at,
		"create_cinematic_camera_script": _cinematic_script,
		"setup_track_to_target_camera": _track_target,
		"list_cinematic_camera_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_camera_3d", "setup_third_person_camera_rig", "setup_path_3d", "setup_path_follow",
		"create_camera_attributes_practical", "set_camera_dof", "create_camera_shake_script",
	])


func _setup_fps_cam(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var pivot := Node3D.new()
	pivot.name = optional_string(params, "name", "Head")
	if parent is Node3D:
		pivot.position = Vector3(0, float(params.get("eye_height", 1.6)), 0)
	add_child_with_undo(parent, pivot, root, "MCP: FPS Head")
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = optional_bool(params, "current", true)
	cam.fov = float(params.get("fov", 75))
	if params.has("near"):
		cam.near = float(params["near"])
	if params.has("far"):
		cam.far = float(params["far"])
	add_child_with_undo(pivot, cam, root, "MCP: FPS Camera")
	mark_current_scene_unsaved()
	return success({
		"head_path": str(root.get_path_to(pivot)),
		"camera_path": str(root.get_path_to(cam)),
		"eye_height": float(params.get("eye_height", 1.6)),
		"fov": cam.fov,
		"hint": "create_fps_controller_script and attach; use create_camera_attributes_practical for DOF",
	})


func _setup_path_cam(params: Dictionary) -> Dictionary:
	## Path3D + PathFollow3D + Camera3D for cinematic rails.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var path_n: Path3D
	var existing_path: String = optional_string(params, "path_node", "")
	if not existing_path.is_empty():
		var en := find_node_by_path(existing_path)
		if en is Path3D:
			path_n = en as Path3D
	if path_n == null:
		path_n = Path3D.new()
		path_n.name = optional_string(params, "path_name", "CinematicPath")
		var curve := Curve3D.new()
		var pts: Array = params.get("points", [])
		if pts.is_empty():
			curve.add_point(Vector3(0, 2, 8))
			curve.add_point(Vector3(4, 3, 0))
			curve.add_point(Vector3(0, 2, -8))
		else:
			for p in pts:
				if p is Dictionary:
					curve.add_point(Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
		path_n.curve = curve
		add_child_with_undo(parent, path_n, root, "MCP: Cinematic Path")
	var follow := PathFollow3D.new()
	follow.name = optional_string(params, "follow_name", "PathFollow3D")
	follow.loop = optional_bool(params, "loop", true)
	follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED if optional_bool(params, "orient", true) else PathFollow3D.ROTATION_NONE
	follow.progress_ratio = float(params.get("progress_ratio", 0.0))
	add_child_with_undo(path_n, follow, root, "MCP: PathFollow")
	var cam := Camera3D.new()
	cam.name = "CinematicCamera"
	cam.current = optional_bool(params, "current", false)
	cam.fov = float(params.get("fov", 50))
	add_child_with_undo(follow, cam, root, "MCP: Cinematic Camera")
	mark_current_scene_unsaved()
	return success({
		"path_node": str(root.get_path_to(path_n)),
		"follow_path": str(root.get_path_to(follow)),
		"camera_path": str(root.get_path_to(cam)),
		"hint": "create_cinematic_camera_script to animate progress_ratio",
	})


func _look_at(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var target_r := require_string(params, "target_path")
	if target_r[1] != null:
		return target_r[1]
	var cam := find_node_by_path(r0[0])
	var target := find_node_by_path(target_r[0])
	if cam == null or not (cam is Node3D):
		return error_not_found("Camera/Node3D")
	if target == null or not (target is Node3D):
		return error_not_found("Target Node3D")
	(cam as Node3D).look_at((target as Node3D).global_position, Vector3.UP)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "target_path": target_r[0], "looked_at": true})


func _track_target(params: Dictionary) -> Dictionary:
	## Camera + script that continuously looks at a target (cinematic follow).
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var cam := Camera3D.new()
	cam.name = optional_string(params, "name", "TrackCamera")
	cam.current = optional_bool(params, "current", false)
	cam.fov = float(params.get("fov", 55))
	if parent is Node3D and params.has("position"):
		var p = params["position"]
		if p is Dictionary:
			cam.position = Vector3(float(p.get("x", 0)), float(p.get("y", 3)), float(p.get("z", 6)))
	add_child_with_undo(parent, cam, root, "MCP: Track Camera")
	var script_path: String = optional_string(params, "script_path", "res://scripts/track_camera.gd")
	var content := """extends Camera3D
@export var target_path: NodePath
@export var smooth: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 6)
@export var look_at_target: bool = true

func _process(delta: float) -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t == null:
		return
	var desired := t.global_position + offset
	global_position = global_position.lerp(desired, clampf(smooth * delta, 0.0, 1.0))
	if look_at_target:
		look_at(t.global_position + Vector3.UP * 1.2, Vector3.UP)
"""
	var wr := write_script_file(script_path, content, optional_bool(params, "overwrite", false))
	if not wr.has("error"):
		var scr: Script = load(script_path)
		if scr:
			cam.set_script(scr)
		if params.has("target_path") and "target_path" in cam:
			cam.set("target_path", NodePath(str(params["target_path"])))
	mark_current_scene_unsaved()
	return success({
		"camera_path": str(root.get_path_to(cam)),
		"script_path": script_path,
		"target_path": params.get("target_path", ""),
	})


func _cinematic_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/cinematic_camera.gd")
	var content := """extends Node
## Drive PathFollow3D progress for cinematic rails.

@export var follow_path: NodePath
@export var duration: float = 8.0
@export var autoplay: bool = false
@export var loop: bool = false

var _follow: PathFollow3D
var _t: float = 0.0
var _playing: bool = false

func _ready() -> void:
	_follow = get_node_or_null(follow_path) as PathFollow3D
	if autoplay:
		play()

func play() -> void:
	_t = 0.0
	_playing = true

func stop() -> void:
	_playing = false

func _process(delta: float) -> void:
	if not _playing or _follow == null or duration <= 0.0:
		return
	_t += delta
	var r := clampf(_t / duration, 0.0, 1.0)
	_follow.progress_ratio = r
	if r >= 1.0:
		if loop:
			_t = 0.0
		else:
			_playing = false
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path})
