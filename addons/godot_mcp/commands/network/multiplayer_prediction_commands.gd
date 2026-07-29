@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Multiplayer prediction / lag compensation recipes - beyond lobby + interest.


func get_commands() -> Dictionary:
	return {
		"create_client_prediction_script": _client_prediction,
		"create_server_reconciliation_script": _server_recon,
		"create_lag_compensation_notes": _lag_notes,
		"create_network_interpolator_script": _interpolator,
		"create_input_buffer_script": _input_buffer,
		"setup_prediction_pipeline": _pipeline,
		"list_multiplayer_prediction_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_interest_manager_script", "setup_multiplayer_synchronizer", "create_enet_multiplayer_script",
		"create_network_clock_script", "pipeline_multiplayer_lobby",
	], {
		"flow": [
			"create_network_clock_script",
			"create_input_buffer_script + create_client_prediction_script",
			"create_server_reconciliation_script on authority",
			"create_network_interpolator_script for remote pawns",
		],
		"honesty": "Full rollback netcode is game-specific; these are production recipes, not a GGPO clone.",
	})


func _client_prediction(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/client_prediction.gd")
	var content := """extends Node
class_name ClientPrediction
## Client-side prediction shell for CharacterBody movement.

signal state_corrected(server_tick: int)

@export var body_path: NodePath
@export var max_pending: int = 64

var _pending: Array = []  # {tick, input, pos, vel}
var _tick: int = 0

func push_input(input: Dictionary, apply_fn: Callable) -> void:
	var body := get_node_or_null(body_path)
	if body == null:
		return
	_tick += 1
	apply_fn.call(body, input)
	_pending.append({
		\"tick\": _tick,
		\"input\": input.duplicate(true),
		\"pos\": body.global_position if body is Node3D else body.position,
		\"vel\": body.velocity if \"velocity\" in body else Vector3.ZERO,
	})
	while _pending.size() > max_pending:
		_pending.pop_front()

func reconcile(server_tick: int, server_pos: Vector3, server_vel: Vector3, apply_fn: Callable) -> void:
	var body := get_node_or_null(body_path)
	if body == null:
		return
	# Drop acked inputs
	while not _pending.is_empty() and int(_pending[0][\"tick\"]) <= server_tick:
		_pending.pop_front()
	if body is Node3D:
		body.global_position = server_pos
	if \"velocity\" in body:
		body.velocity = server_vel
	# Replay unacked
	for entry in _pending:
		apply_fn.call(body, entry[\"input\"])
	state_corrected.emit(server_tick)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "ClientPrediction"})


func _server_recon(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/server_reconciliation.gd")
	var content := """extends Node
class_name ServerReconciliation
## Server stores recent states for reconciliation responses.

@export var history_size: int = 120
var _history: Dictionary = {}  # peer_id -> Array[{tick, pos, vel}]

func record(peer_id: int, tick: int, pos: Vector3, vel: Vector3) -> void:
	if not _history.has(peer_id):
		_history[peer_id] = []
	var arr: Array = _history[peer_id]
	arr.append({\"tick\": tick, \"pos\": pos, \"vel\": vel})
	while arr.size() > history_size:
		arr.pop_front()
	_history[peer_id] = arr

func latest(peer_id: int) -> Dictionary:
	if not _history.has(peer_id):
		return {}
	var arr: Array = _history[peer_id]
	return arr.back() if arr.size() > 0 else {}

@rpc(\"any_peer\", \"unreliable\")
func receive_input(tick: int, input: Dictionary) -> void:
	# Game fills: apply input on authority pawn for sender, then record()
	pass
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "ServerReconciliation"})


func _interpolator(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/network_interpolator.gd")
	var content := """extends Node
class_name NetworkInterpolator
## Interpolate remote entity snapshots to hide jitter.

@export var target_path: NodePath
@export var delay_sec: float = 0.1

var _buffer: Array = []  # {t, pos, rot}

func push_snapshot(pos: Vector3, rot: Variant = null) -> void:
	_buffer.append({\"t\": Time.get_ticks_msec() / 1000.0, \"pos\": pos, \"rot\": rot})
	while _buffer.size() > 64:
		_buffer.pop_front()

func _process(_delta: float) -> void:
	var node := get_node_or_null(target_path) as Node3D
	if node == null or _buffer.size() < 2:
		return
	var render_t := Time.get_ticks_msec() / 1000.0 - delay_sec
	# Find surrounding snapshots
	var a: Dictionary = _buffer[0]
	var b: Dictionary = _buffer[0]
	for i in range(_buffer.size() - 1):
		if float(_buffer[i][\"t\"]) <= render_t and float(_buffer[i + 1][\"t\"]) >= render_t:
			a = _buffer[i]
			b = _buffer[i + 1]
			break
		a = _buffer[i]
		b = _buffer[i + 1]
	var span := maxf(0.0001, float(b[\"t\"]) - float(a[\"t\"]))
	var alpha := clampf((render_t - float(a[\"t\"])) / span, 0.0, 1.0)
	node.global_position = (a[\"pos\"] as Vector3).lerp(b[\"pos\"] as Vector3, alpha)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "NetworkInterpolator"})


func _input_buffer(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/network_input_buffer.gd")
	var content := """extends Node
class_name NetworkInputBuffer
## Ring buffer of inputs by tick for prediction/replay.

@export var capacity: int = 128
var _buf: Dictionary = {}  # tick -> input dict
var _min_tick: int = 0
var _max_tick: int = -1

func store(tick: int, input: Dictionary) -> void:
	_buf[tick] = input.duplicate(true)
	_max_tick = maxi(_max_tick, tick)
	if _min_tick == 0:
		_min_tick = tick
	while _buf.size() > capacity:
		_buf.erase(_min_tick)
		_min_tick += 1

func get_input(tick: int) -> Dictionary:
	return _buf.get(tick, {})

func has_tick(tick: int) -> bool:
	return _buf.has(tick)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "NetworkInputBuffer"})


func _lag_notes(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://docs/NETWORK_PREDICTION.md")
	var content := """# Network prediction notes (Godot MCP)

## Recommended stack
1. `create_network_clock_script` for RTT / server time estimate
2. `create_input_buffer_script` store client ticks
3. `create_client_prediction_script` apply local input immediately
4. Authority simulates and RPCs corrected state
5. `create_server_reconciliation_script` + client `reconcile()`
6. `create_network_interpolator_script` on remote pawns
7. `create_interest_manager_script` to limit sync set

## Not included (out of scope)
- Full deterministic lockstep / GGPO rollback
- Hosted relay / matchmaking
- Anti-cheat

## Bandwidth tips
- `set_synchronizer_replication_interval`
- Interest / visibility filters
- Unreliable RPCs for pose; reliable for inventory
"""
	var w := write_text_res(path, content, optional_bool(params, "overwrite", true))
	if w.has("error"):
		return w
	return success({"path": path})


func _pipeline(params: Dictionary) -> Dictionary:
	var steps: Array = []
	steps.append(_input_buffer({"path": optional_string(params, "input_buffer_path", "res://scripts/network_input_buffer.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_client_prediction({"path": optional_string(params, "prediction_path", "res://scripts/client_prediction.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_server_recon({"path": optional_string(params, "recon_path", "res://scripts/server_reconciliation.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_interpolator({"path": optional_string(params, "interp_path", "res://scripts/network_interpolator.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_lag_notes({"path": optional_string(params, "notes_path", "res://docs/NETWORK_PREDICTION.md"), "overwrite": true}))
	return success({"steps": steps, "pipeline": "prediction"})
