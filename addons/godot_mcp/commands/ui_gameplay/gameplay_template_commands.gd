@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Gameplay templates - save system, signal bus, object pool, camera shake (project-neutral).


func get_commands() -> Dictionary:
	return {
		"create_save_manager_script": _create_save_manager_script,
		"create_signal_bus_script": _create_signal_bus_script,
		"create_object_pool_script": _create_object_pool_script,
		"create_camera_shake_script": _create_camera_shake_script,
		"list_gameplay_templates": _list_gameplay_templates,
	}


func _list_gameplay_templates(_params: Dictionary) -> Dictionary:
	return success({
		"templates": [
			{"id": "save_manager", "tool": "create_save_manager_script", "desc": "JSON save/load under user://saves"},
			{"id": "signal_bus", "tool": "create_signal_bus_script", "desc": "Global EventBus autoload"},
			{"id": "object_pool", "tool": "create_object_pool_script", "desc": "Acquire/release Node pool"},
			{"id": "camera_shake", "tool": "create_camera_shake_script", "desc": "Trauma-based Camera2D/3D shake"},
		],
	})



func _maybe_autoload(params: Dictionary, path: String, default_name: String) -> bool:
	return maybe_add_autoload(params, path, default_name)


func _create_save_manager_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/save_manager.gd")
	var content := """extends Node
## MCP SaveManager - JSON slots under user://saves/
signal save_completed(slot: String)
signal load_completed(slot: String, data: Dictionary)

const SAVE_DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")

func save_game(data: Dictionary, slot: String = "slot0") -> Error:
	var path := _slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_CREATE
	var payload := {"version": 1, "timestamp": Time.get_unix_time_from_system(), "data": data}
	f.store_string(JSON.stringify(payload, "\\t"))
	f.close()
	save_completed.emit(slot)
	return OK

func load_game(slot: String = "slot0") -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed.get("data", {})
	load_completed.emit(slot, data)
	return data

func has_save(slot: String = "slot0") -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func delete_save(slot: String = "slot0") -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func list_slots() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if n.ends_with(".json"):
			out.append(n.get_basename())
		n = dir.get_next()
	dir.list_dir_end()
	return out
"""
	var err := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if err.has("error"):
		return err
	var al := _maybe_autoload(params, path if path.begins_with("res://") else "res://" + path, "SaveManager")
	return success({"path": path if path.begins_with("res://") else "res://" + path.trim_prefix("/"), "autoload_added": al})


func _create_signal_bus_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/event_bus.gd")
	# Custom signals from params
	var extra: Array = params.get("signals", [])
	var sig_lines := ""
	if extra is Array:
		for s in extra:
			var sn := str(s).validate_filename().replace("-", "_")
			if sn.is_empty():
				continue
			sig_lines += "signal %s\n" % sn
	if sig_lines.is_empty():
		sig_lines = """signal game_started
signal game_paused(paused: bool)
signal player_died
signal score_changed(score: int)
signal dialogue_requested(id: String)
"""
	var content := """extends Node
## MCP EventBus autoload - decouple systems without hard node paths.
%s
# Generic bag for one-off events
signal event(name: String, payload: Variant)

func emit_named(name: String, payload: Variant = null) -> void:
	event.emit(name, payload)
""" % sig_lines
	var wpath := path if path.begins_with("res://") else "res://" + path.trim_prefix("/")
	var err := write_script_file(wpath, content, optional_bool(params, "overwrite", false))
	if err.has("error"):
		return err
	var al := _maybe_autoload(params, wpath, "EventBus")
	return success({"path": wpath, "autoload_added": al, "signals": sig_lines.split("\n")})


func _create_object_pool_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/object_pool.gd")
	var wpath := path if path.begins_with("res://") else "res://" + path.trim_prefix("/")
	var content := """extends Node
## MCP ObjectPool - acquire/release for bullets, VFX, etc.
## Usage: pool.setup(preload("res://bullet.tscn"), 32); var b = pool.acquire()

var _scene: PackedScene
var _available: Array[Node] = []
var _parent: Node

func setup(scene: PackedScene, initial: int = 16, parent: Node = null) -> void:
	_scene = scene
	_parent = parent if parent else self
	for i in initial:
		_available.append(_make())

func _make() -> Node:
	var n: Node = _scene.instantiate()
	if n.has_method("set_process"):
		n.set_process(false)
	if n.has_method("set_physics_process"):
		n.set_physics_process(false)
	if "visible" in n:
		n.visible = false
	_parent.add_child(n)
	return n

func acquire() -> Node:
	var n: Node
	if _available.is_empty():
		n = _make()
	else:
		n = _available.pop_back()
	if "visible" in n:
		n.visible = true
	if n.has_method("set_process"):
		n.set_process(true)
	if n.has_method("set_physics_process"):
		n.set_physics_process(true)
	if n.has_method("on_pool_acquire"):
		n.on_pool_acquire()
	return n

func release(n: Node) -> void:
	if n == null:
		return
	if n.has_method("on_pool_release"):
		n.on_pool_release()
	if n.has_method("set_process"):
		n.set_process(false)
	if n.has_method("set_physics_process"):
		n.set_physics_process(false)
	if "visible" in n:
		n.visible = false
	_available.append(n)

func available_count() -> int:
	return _available.size()
"""
	var err := write_script_file(wpath, content, optional_bool(params, "overwrite", false))
	if err.has("error"):
		return err
	return success({"path": wpath, "created": true})


func _create_camera_shake_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/camera_shake.gd")
	var wpath := path if path.begins_with("res://") else "res://" + path.trim_prefix("/")
	var content := """extends Node
## MCP camera shake - attach as child of Camera2D or Camera3D (or set camera_path).
## Trauma model: add_trauma(0.2..1.0); decays each frame.

@export var camera_path: NodePath
@export var max_offset: float = 12.0
@export var max_roll: float = 0.08
@export var trauma_power: float = 2.0
@export var decay: float = 1.2

var _trauma: float = 0.0
var _noise: FastNoiseLite
var _cam: Node
var _base_pos: Vector3
var _base_pos2: Vector2
var _t: float = 0.0

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.5
	if camera_path != NodePath():
		_cam = get_node_or_null(camera_path)
	else:
		_cam = get_parent()
	if _cam is Camera2D:
		_base_pos2 = (_cam as Camera2D).offset
	elif _cam is Camera3D:
		_base_pos = (_cam as Camera3D).position

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if _cam == null or _trauma <= 0.0:
		return
	_t += delta
	_trauma = maxf(_trauma - decay * delta, 0.0)
	var shake := pow(_trauma, trauma_power)
	var nx := _noise.get_noise_2d(_t * 100.0, 0.0)
	var ny := _noise.get_noise_2d(0.0, _t * 100.0)
	var nr := _noise.get_noise_2d(_t * 80.0, _t * 80.0)
	if _cam is Camera2D:
		var c := _cam as Camera2D
		c.offset = _base_pos2 + Vector2(nx, ny) * max_offset * shake
		c.rotation = nr * max_roll * shake
	elif _cam is Camera3D:
		var c3 := _cam as Camera3D
		c3.h_offset = nx * max_offset * 0.05 * shake
		c3.v_offset = ny * max_offset * 0.05 * shake
"""
	var err := write_script_file(wpath, content, optional_bool(params, "overwrite", false))
	if err.has("error"):
		return err
	return success({
		"path": wpath,
		"hint": "Add as child of Camera2D/3D; call add_trauma(0.4) on hit.",
	})
