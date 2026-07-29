@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Steering / flocking recipes - critical AI movement map beyond navmesh agents.


func get_commands() -> Dictionary:
	return {
		"create_steering_behaviors_script": _create_steering,
		"create_flock_controller_script": _create_flock,
		"setup_steering_agent_node": _setup_agent,
		"list_steering_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_navigation_agent", "setup_ai_agent_3d", "setup_ai_agent_2d",
		"create_astar_grid_2d_script", "navigation_query_path",
	], {
		"flow": [
			"create_steering_behaviors_script",
			"setup_steering_agent_node on CharacterBody",
			"optional create_flock_controller_script for groups",
		],
	})


func _create_steering(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/steering_behaviors.gd")
	var content := """extends RefCounted
class_name SteeringBehaviors
## Classic steering forces (2D/3D vector).

static func seek(pos: Vector3, vel: Vector3, target: Vector3, max_speed: float) -> Vector3:
	var desired := (target - pos)
	if desired.length() < 0.001:
		return Vector3.ZERO
	desired = desired.normalized() * max_speed
	return desired - vel

static func flee(pos: Vector3, vel: Vector3, threat: Vector3, max_speed: float) -> Vector3:
	return seek(pos, vel, pos + (pos - threat), max_speed)

static func arrive(pos: Vector3, vel: Vector3, target: Vector3, max_speed: float, slowing: float = 4.0) -> Vector3:
	var to := target - pos
	var dist := to.length()
	if dist < 0.05:
		return -vel
	var speed := max_speed if dist > slowing else max_speed * (dist / slowing)
	var desired := to.normalized() * speed
	return desired - vel

static func pursue(pos: Vector3, vel: Vector3, target_pos: Vector3, target_vel: Vector3, max_speed: float) -> Vector3:
	var to := target_pos - pos
	var dist := to.length()
	var speed := maxf(vel.length(), 0.1)
	var prediction := dist / speed
	return seek(pos, vel, target_pos + target_vel * prediction, max_speed)

static func separate(pos: Vector3, neighbors: Array, desired_sep: float, max_speed: float) -> Vector3:
	var steer := Vector3.ZERO
	var count := 0
	for n in neighbors:
		var np: Vector3 = n
		var d := pos.distance_to(np)
		if d > 0.001 and d < desired_sep:
			steer += (pos - np).normalized() / d
			count += 1
	if count > 0:
		steer /= float(count)
		if steer.length() > 0.001:
			steer = steer.normalized() * max_speed
	return steer

static func align(vel: Vector3, neighbor_vels: Array, max_speed: float) -> Vector3:
	if neighbor_vels.is_empty():
		return Vector3.ZERO
	var avg := Vector3.ZERO
	for v in neighbor_vels:
		avg += v
	avg /= float(neighbor_vels.size())
	if avg.length() < 0.001:
		return Vector3.ZERO
	return avg.normalized() * max_speed - vel

static func cohesion(pos: Vector3, vel: Vector3, neighbor_pos: Array, max_speed: float) -> Vector3:
	if neighbor_pos.is_empty():
		return Vector3.ZERO
	var center := Vector3.ZERO
	for p in neighbor_pos:
		center += p
	center /= float(neighbor_pos.size())
	return seek(pos, vel, center, max_speed)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "SteeringBehaviors"})


func _create_flock(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/flock_controller.gd")
	var content := """extends Node3D
class_name FlockController
## Simple boid flock: children with velocity property or CharacterBody3D.

@export var max_speed: float = 6.0
@export var neighbor_radius: float = 5.0
@export var separation_weight: float = 1.4
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var target_path: NodePath
@export var seek_weight: float = 0.6

func _physics_process(delta: float) -> void:
	var agents: Array = []
	for c in get_children():
		if c is CharacterBody3D or c is Node3D:
			agents.append(c)
	var target := get_node_or_null(target_path) as Node3D
	for a in agents:
		var pos: Vector3 = a.global_position
		var vel: Vector3 = a.velocity if a is CharacterBody3D else Vector3.ZERO
		var npos: Array = []
		var nvel: Array = []
		for b in agents:
			if b == a:
				continue
			if pos.distance_to(b.global_position) <= neighbor_radius:
				npos.append(b.global_position)
				if b is CharacterBody3D:
					nvel.append(b.velocity)
		var force := Vector3.ZERO
		if ResourceLoader.exists(\"res://scripts/steering_behaviors.gd\"):
			var SB = load(\"res://scripts/steering_behaviors.gd\")
			force += SB.separate(pos, npos, neighbor_radius * 0.5, max_speed) * separation_weight
			force += SB.align(vel, nvel, max_speed) * alignment_weight
			force += SB.cohesion(pos, vel, npos, max_speed) * cohesion_weight
			if target:
				force += SB.seek(pos, vel, target.global_position, max_speed) * seek_weight
		if a is CharacterBody3D:
			a.velocity = (vel + force * delta).limit_length(max_speed)
			a.move_and_slide()
		elif a is Node3D:
			a.global_position += force.limit_length(max_speed) * delta
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "FlockController"})


func _setup_agent(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var script_path: String = optional_string(params, "script_path", "res://scripts/steering_agent.gd")
	var content := """extends CharacterBody3D
## Steering seek/arrive toward a target.

@export var target_path: NodePath
@export var max_speed: float = 5.0
@export var arrive: bool = true
@export var slowing_radius: float = 3.0

func _physics_process(delta: float) -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t == null:
		return
	var force := Vector3.ZERO
	if ResourceLoader.exists(\"res://scripts/steering_behaviors.gd\"):
		var SB = load(\"res://scripts/steering_behaviors.gd\")
		if arrive:
			force = SB.arrive(global_position, velocity, t.global_position, max_speed, slowing_radius)
		else:
			force = SB.seek(global_position, velocity, t.global_position, max_speed)
	velocity = (velocity + force).limit_length(max_speed)
	move_and_slide()
"""
	if not FileAccess.file_exists(script_path):
		var wr := write_script_file(script_path, content, optional_bool(params, "overwrite", false))
		if wr.has("error") and int(wr["error"].get("code", 0)) != -32000:
			return wr
	_create_steering({"path": "res://scripts/steering_behaviors.gd", "overwrite": false})
	var body := CharacterBody3D.new()
	body.name = optional_string(params, "name", "SteeringAgent")
	var scr: Script = load(script_path)
	if scr:
		body.set_script(scr)
	if params.has("target_path") and "target_path" in body:
		body.set("target_path", NodePath(str(params["target_path"])))
	add_child_with_undo(parent, body, root, "MCP: SteeringAgent")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child_with_undo(body, col, root, "MCP: col")
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(body)),
		"script_path": script_path,
	})
