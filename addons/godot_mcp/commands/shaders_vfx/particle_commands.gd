@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_particles": _create_particles,
		"set_particle_material": _set_particle_material,
		"set_particle_color_gradient": _set_particle_color_gradient,
		"apply_particle_preset": _apply_particle_preset,
		"get_particle_info": _get_particle_info,
		"set_particle_emitting": _set_particle_emitting,
		"set_particle_amount": _set_particle_amount,
		"set_particle_trail": _set_particle_trail,
		"set_particle_subemitter": _set_particle_subemitter,
		"set_particle_collision": _set_particle_collision,
		"add_gpu_particles_collision": _add_gpu_particles_collision,
	}


func _get_particles_node(node_path: String) -> GPUParticles2D:
	# Returns any GPUParticles2D or GPUParticles3D (both share similar API)
	var node := find_node_by_path(node_path)
	if node is GPUParticles2D:
		return node as GPUParticles2D
	return null


func _get_particles_node_any(node_path: String) -> Node:
	var node := find_node_by_path(node_path)
	if node is GPUParticles2D or node is GPUParticles3D:
		return node
	return null


func _parse_color(color_str: String) -> Color:
	# Support hex "#RRGGBB", "#RRGGBBAA", or named colors
	if color_str.begins_with("#"):
		return Color.html(color_str)
	# Try named color
	match color_str.to_lower():
		"red": return Color.RED
		"green": return Color.GREEN
		"blue": return Color.BLUE
		"white": return Color.WHITE
		"black": return Color.BLACK
		"yellow": return Color.YELLOW
		"orange": return Color(1.0, 0.5, 0.0)
		"gray", "grey": return Color.GRAY
		"cyan": return Color.CYAN
		"magenta": return Color.MAGENTA
		"transparent": return Color(0, 0, 0, 0)
	# Try Expression parser for Color(r,g,b,a)
	var expr := Expression.new()
	if expr.parse(color_str) == OK:
		var parsed = expr.execute()
		if parsed is Color:
			return parsed
	return Color.WHITE


func _create_particles(params: Dictionary) -> Dictionary:
	var result := require_string(params, "parent_path")
	if result[1] != null:
		return result[1]
	var parent_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Node at '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "Particles")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var amount: int = optional_int(params, "amount", 16)
	var lifetime: float = float(params.get("lifetime", 1.0))
	var one_shot: bool = optional_bool(params, "one_shot", false)
	var explosiveness: float = float(params.get("explosiveness", 0.0))
	var randomness: float = float(params.get("randomness", 0.0))
	var emitting: bool = optional_bool(params, "emitting", true)

	var particles_node: Node
	if is_3d:
		var p := GPUParticles3D.new()
		p.name = node_name
		p.amount = amount
		p.lifetime = lifetime
		p.one_shot = one_shot
		p.explosiveness = explosiveness
		p.randomness = randomness
		p.emitting = emitting
		var mat := ParticleProcessMaterial.new()
		p.process_material = mat
		particles_node = p
	else:
		var p := GPUParticles2D.new()
		p.name = node_name
		p.amount = amount
		p.lifetime = lifetime
		p.one_shot = one_shot
		p.explosiveness = explosiveness
		p.randomness = randomness
		p.emitting = emitting
		var mat := ParticleProcessMaterial.new()
		p.process_material = mat
		particles_node = p

	add_child_with_undo(parent, particles_node, root, "MCP: Create particles")

	return success({
		"name": particles_node.name,
		"parent": parent_path,
		"is_3d": is_3d,
		"amount": amount,
		"lifetime": lifetime,
		"one_shot": one_shot,
		"created": true,
	})


func _set_particle_material(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := _get_particles_node_any(node_path)
	if node == null:
		return error_not_found("GPUParticles2D/3D at '%s'" % node_path)

	var old_mat: ParticleProcessMaterial = node.get("process_material")
	var mat: ParticleProcessMaterial
	if old_mat != null:
		mat = old_mat.duplicate(true) as ParticleProcessMaterial
	else:
		mat = ParticleProcessMaterial.new()

	var changes: Array = []

	# Direction
	if params.has("direction"):
		var dir = params["direction"]
		if dir is Dictionary:
			mat.direction = Vector3(float(dir.get("x", 0)), float(dir.get("y", 0)), float(dir.get("z", 0)))
			changes.append("direction")
		elif dir is String:
			var expr := Expression.new()
			if expr.parse(dir) == OK:
				var parsed = expr.execute()
				if parsed is Vector3:
					mat.direction = parsed
					changes.append("direction")

	# Spread
	if params.has("spread"):
		mat.spread = float(params["spread"])
		changes.append("spread")

	# Initial velocity
	if params.has("initial_velocity_min"):
		mat.initial_velocity_min = float(params["initial_velocity_min"])
		changes.append("initial_velocity_min")
	if params.has("initial_velocity_max"):
		mat.initial_velocity_max = float(params["initial_velocity_max"])
		changes.append("initial_velocity_max")

	# Gravity
	if params.has("gravity"):
		var grav = params["gravity"]
		if grav is Dictionary:
			mat.gravity = Vector3(float(grav.get("x", 0)), float(grav.get("y", 0)), float(grav.get("z", 0)))
			changes.append("gravity")
		elif grav is String:
			var expr := Expression.new()
			if expr.parse(grav) == OK:
				var parsed = expr.execute()
				if parsed is Vector3:
					mat.gravity = parsed
					changes.append("gravity")

	# Scale
	if params.has("scale_min"):
		mat.scale_min = float(params["scale_min"])
		changes.append("scale_min")
	if params.has("scale_max"):
		mat.scale_max = float(params["scale_max"])
		changes.append("scale_max")

	# Color
	if params.has("color"):
		mat.color = _parse_color(str(params["color"]))
		changes.append("color")

	# Emission shape
	if params.has("emission_shape"):
		var shape_str: String = str(params["emission_shape"]).to_lower()
		match shape_str:
			"point":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			"sphere":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
				if params.has("emission_sphere_radius"):
					mat.emission_sphere_radius = float(params["emission_sphere_radius"])
					changes.append("emission_sphere_radius")
			"sphere_surface":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
				if params.has("emission_sphere_radius"):
					mat.emission_sphere_radius = float(params["emission_sphere_radius"])
					changes.append("emission_sphere_radius")
			"box":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				if params.has("emission_box_extents"):
					var ext = params["emission_box_extents"]
					if ext is Dictionary:
						mat.emission_box_extents = Vector3(float(ext.get("x", 1)), float(ext.get("y", 1)), float(ext.get("z", 1)))
						changes.append("emission_box_extents")
			"ring":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
				if params.has("emission_ring_radius"):
					mat.emission_ring_radius = float(params["emission_ring_radius"])
					changes.append("emission_ring_radius")
				if params.has("emission_ring_inner_radius"):
					mat.emission_ring_inner_radius = float(params["emission_ring_inner_radius"])
					changes.append("emission_ring_inner_radius")
				if params.has("emission_ring_height"):
					mat.emission_ring_height = float(params["emission_ring_height"])
					changes.append("emission_ring_height")
		changes.append("emission_shape")

	# Angular velocity
	if params.has("angular_velocity_min"):
		mat.angular_velocity_min = float(params["angular_velocity_min"])
		changes.append("angular_velocity_min")
	if params.has("angular_velocity_max"):
		mat.angular_velocity_max = float(params["angular_velocity_max"])
		changes.append("angular_velocity_max")

	# Orbit velocity
	if params.has("orbit_velocity_min"):
		mat.orbit_velocity_min = float(params["orbit_velocity_min"])
		changes.append("orbit_velocity_min")
	if params.has("orbit_velocity_max"):
		mat.orbit_velocity_max = float(params["orbit_velocity_max"])
		changes.append("orbit_velocity_max")

	# Damping
	if params.has("damping_min"):
		mat.damping_min = float(params["damping_min"])
		changes.append("damping_min")
	if params.has("damping_max"):
		mat.damping_max = float(params["damping_max"])
		changes.append("damping_max")

	# Attractor interaction
	if params.has("attractor_interaction_enabled"):
		mat.attractor_interaction_enabled = bool(params["attractor_interaction_enabled"])
		changes.append("attractor_interaction_enabled")

	if not changes.is_empty():
		set_property_with_undo(node, "process_material", mat, "MCP: Set particle material")
	return success({"node_path": node_path, "changes": changes})


func _set_particle_color_gradient(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := _get_particles_node_any(node_path)
	if node == null:
		return error_not_found("GPUParticles2D/3D at '%s'" % node_path)

	var old_mat: ParticleProcessMaterial = node.get("process_material")
	var mat: ParticleProcessMaterial
	if old_mat != null:
		mat = old_mat.duplicate(true) as ParticleProcessMaterial
	else:
		mat = ParticleProcessMaterial.new()

	if not params.has("stops") or not params["stops"] is Array:
		return error_invalid_params("Missing required parameter: stops (array of {offset, color})")

	var stops: Array = params["stops"]
	if stops.is_empty():
		return error_invalid_params("stops array must not be empty")

	# Gradient.remove_point refuses to drop below 2 points, so a fresh Gradient
	# cannot be cleared point by point - assign offsets/colors wholesale instead.
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		if stop is Dictionary:
			offsets.append(float(stop.get("offset", 0.0)))
			colors.append(_parse_color(str(stop.get("color", "#ffffff"))))
	if offsets.is_empty():
		return error_invalid_params("stops array must contain {offset, color} dictionaries")

	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors

	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex
	set_property_with_undo(node, "process_material", mat, "MCP: Set particle color gradient")

	return success({"node_path": node_path, "stops_count": gradient.get_point_count()})


func _apply_particle_preset(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "preset")
	if result2[1] != null:
		return result2[1]
	var preset: String = result2[0].to_lower()

	var node := _get_particles_node_any(node_path)
	if node == null:
		return error_not_found("GPUParticles2D/3D at '%s'" % node_path)

	var old_state := _capture_particle_state(node)
	var preset_state := {}
	var mat := ParticleProcessMaterial.new()
	var is_2d: bool = node is GPUParticles2D

	# Default gravity for 2D (Y-down) vs 3D (Y-down)
	var gravity_down := Vector3(0, 98.0 if is_2d else 9.8, 0)
	var _gravity_up := Vector3(0, -98.0 if is_2d else -9.8, 0)
	var gravity_none := Vector3.ZERO

	match preset:
		"explosion":
			preset_state["amount"] = 32
			preset_state["lifetime"] = 0.6
			preset_state["one_shot"] = true
			preset_state["explosiveness"] = 1.0
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 100.0 if is_2d else 5.0
			mat.initial_velocity_max = 200.0 if is_2d else 10.0
			mat.gravity = gravity_down * 0.5
			mat.damping_min = 2.0
			mat.damping_max = 4.0
			mat.scale_min = 0.5
			mat.scale_max = 1.5
			mat.color = Color(1.0, 0.6, 0.1)
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color.WHITE},
				{"offset": 0.3, "color": Color(1.0, 0.8, 0.2)},
				{"offset": 0.7, "color": Color(1.0, 0.3, 0.0)},
				{"offset": 1.0, "color": Color(0.2, 0.0, 0.0, 0.0)},
			])

		"fire":
			preset_state["amount"] = 24
			preset_state["lifetime"] = 1.2
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 15.0
			mat.initial_velocity_min = 30.0 if is_2d else 1.5
			mat.initial_velocity_max = 60.0 if is_2d else 3.0
			mat.gravity = gravity_none
			mat.scale_min = 0.8
			mat.scale_max = 1.5
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color(1.0, 1.0, 0.5)},
				{"offset": 0.3, "color": Color(1.0, 0.6, 0.0)},
				{"offset": 0.7, "color": Color(0.8, 0.2, 0.0)},
				{"offset": 1.0, "color": Color(0.2, 0.0, 0.0, 0.0)},
			])

		"smoke":
			preset_state["amount"] = 16
			preset_state["lifetime"] = 3.0
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 25.0
			mat.initial_velocity_min = 10.0 if is_2d else 0.5
			mat.initial_velocity_max = 25.0 if is_2d else 1.2
			mat.gravity = gravity_none
			mat.scale_min = 1.5
			mat.scale_max = 3.0
			mat.damping_min = 1.0
			mat.damping_max = 2.0
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color(0.5, 0.5, 0.5, 0.6)},
				{"offset": 0.5, "color": Color(0.6, 0.6, 0.6, 0.3)},
				{"offset": 1.0, "color": Color(0.7, 0.7, 0.7, 0.0)},
			])

		"sparks":
			preset_state["amount"] = 48
			preset_state["lifetime"] = 0.4
			preset_state["one_shot"] = true
			preset_state["explosiveness"] = 0.95
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 200.0 if is_2d else 8.0
			mat.initial_velocity_max = 400.0 if is_2d else 16.0
			mat.gravity = gravity_down
			mat.scale_min = 0.1
			mat.scale_max = 0.3
			mat.damping_min = 1.0
			mat.damping_max = 3.0
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color(1.0, 1.0, 0.8)},
				{"offset": 0.5, "color": Color(1.0, 0.7, 0.2)},
				{"offset": 1.0, "color": Color(1.0, 0.3, 0.0, 0.0)},
			])

		"rain":
			preset_state["amount"] = 64
			preset_state["lifetime"] = 0.8
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, 1, 0) if is_2d else Vector3(0, -1, 0)
			mat.spread = 5.0
			mat.initial_velocity_min = 300.0 if is_2d else 12.0
			mat.initial_velocity_max = 400.0 if is_2d else 16.0
			mat.gravity = gravity_down
			mat.scale_min = 0.1
			mat.scale_max = 0.2
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(200, 0, 0) if is_2d else Vector3(5, 0, 5)
			mat.color = Color(0.6, 0.7, 1.0, 0.7)

		"snow":
			preset_state["amount"] = 48
			preset_state["lifetime"] = 4.0
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, 1, 0) if is_2d else Vector3(0, -1, 0)
			mat.spread = 20.0
			mat.initial_velocity_min = 20.0 if is_2d else 0.8
			mat.initial_velocity_max = 40.0 if is_2d else 1.5
			mat.gravity = Vector3(0, 20, 0) if is_2d else Vector3(0, -0.5, 0)
			mat.scale_min = 0.3
			mat.scale_max = 0.8
			mat.angular_velocity_min = -45.0
			mat.angular_velocity_max = 45.0
			mat.damping_min = 0.5
			mat.damping_max = 1.5
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(200, 0, 0) if is_2d else Vector3(5, 0, 5)
			mat.color = Color(1.0, 1.0, 1.0, 0.9)

		"magic":
			preset_state["amount"] = 24
			preset_state["lifetime"] = 2.0
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 20.0 if is_2d else 1.0
			mat.initial_velocity_max = 50.0 if is_2d else 2.5
			mat.gravity = gravity_none
			mat.orbit_velocity_min = 0.5
			mat.orbit_velocity_max = 1.5
			mat.scale_min = 0.3
			mat.scale_max = 0.8
			mat.damping_min = 1.0
			mat.damping_max = 2.0
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color(0.3, 0.5, 1.0)},
				{"offset": 0.25, "color": Color(1.0, 0.3, 0.8)},
				{"offset": 0.5, "color": Color(0.3, 1.0, 0.5)},
				{"offset": 0.75, "color": Color(1.0, 0.8, 0.2)},
				{"offset": 1.0, "color": Color(0.5, 0.3, 1.0, 0.0)},
			])

		"dust":
			preset_state["amount"] = 12
			preset_state["lifetime"] = 5.0
			preset_state["one_shot"] = false
			preset_state["explosiveness"] = 0.0
			mat.direction = Vector3(0, -1, 0) if is_2d else Vector3(0, 1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 3.0 if is_2d else 0.1
			mat.initial_velocity_max = 8.0 if is_2d else 0.3
			mat.gravity = gravity_none
			mat.scale_min = 0.2
			mat.scale_max = 0.5
			mat.damping_min = 0.5
			mat.damping_max = 1.0
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(100, 100, 0) if is_2d else Vector3(3, 3, 3)
			_apply_gradient(mat, [
				{"offset": 0.0, "color": Color(0.8, 0.75, 0.65, 0.0)},
				{"offset": 0.2, "color": Color(0.8, 0.75, 0.65, 0.3)},
				{"offset": 0.8, "color": Color(0.8, 0.75, 0.65, 0.3)},
				{"offset": 1.0, "color": Color(0.8, 0.75, 0.65, 0.0)},
			])

		_:
			return error_invalid_params("Unknown preset: '%s'. Valid presets: explosion, fire, smoke, sparks, rain, snow, magic, dust" % preset)

	preset_state["process_material"] = mat
	_register_particle_state_undo(node, old_state, preset_state, "MCP: Apply particle preset")

	return success({"node_path": node_path, "preset": preset, "applied": true})


func _capture_particle_state(node: Node) -> Dictionary:
	var state := {}
	for property: String in ["amount", "lifetime", "one_shot", "explosiveness", "randomness", "emitting", "process_material"]:
		if property in node:
			state[property] = node.get(property)
	return state


func _register_particle_state_undo(node: Node, old_state: Dictionary, new_state: Dictionary, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	for property: String in new_state:
		undo_redo.add_do_property(node, property, new_state[property])
		if new_state[property] is Resource:
			undo_redo.add_do_reference(new_state[property])
		undo_redo.add_undo_property(node, property, old_state.get(property, null))
		if old_state.get(property, null) is Resource:
			undo_redo.add_undo_reference(old_state[property])
	undo_redo.commit_action()


func _apply_gradient(mat: ParticleProcessMaterial, stops: Array) -> void:
	# Assign offsets/colors wholesale: Gradient.remove_point cannot drop below
	# 2 points, so clearing the default points one by one leaves a stray stop.
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		offsets.append(stop["offset"])
		colors.append(stop["color"])
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var grad_tex := GradientTexture1D.new()
	grad_tex.width = 64  # Smaller texture to avoid GPU issues in compatibility mode
	grad_tex.gradient = gradient
	# Defer color_ramp assignment to avoid editor crash during rendering
	mat.set_deferred("color_ramp", grad_tex)


func _get_particle_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := _get_particles_node_any(node_path)
	if node == null:
		return error_not_found("GPUParticles2D/3D at '%s'" % node_path)

	var info: Dictionary = {
		"node_path": node_path,
		"type": node.get_class(),
		"amount": node.get("amount"),
		"lifetime": node.get("lifetime"),
		"one_shot": node.get("one_shot"),
		"explosiveness": node.get("explosiveness"),
		"randomness": node.get("randomness"),
		"emitting": node.get("emitting"),
	}

	var mat: ParticleProcessMaterial = node.get("process_material")
	if mat != null and mat is ParticleProcessMaterial:
		var mat_info: Dictionary = {
			"direction": str(mat.direction),
			"spread": mat.spread,
			"initial_velocity_min": mat.initial_velocity_min,
			"initial_velocity_max": mat.initial_velocity_max,
			"gravity": str(mat.gravity),
			"scale_min": mat.scale_min,
			"scale_max": mat.scale_max,
			"color": str(mat.color),
			"angular_velocity_min": mat.angular_velocity_min,
			"angular_velocity_max": mat.angular_velocity_max,
			"orbit_velocity_min": mat.orbit_velocity_min,
			"orbit_velocity_max": mat.orbit_velocity_max,
			"damping_min": mat.damping_min,
			"damping_max": mat.damping_max,
			"attractor_interaction_enabled": mat.attractor_interaction_enabled,
		}

		# Emission shape
		var shape_name: String
		match mat.emission_shape:
			ParticleProcessMaterial.EMISSION_SHAPE_POINT: shape_name = "point"
			ParticleProcessMaterial.EMISSION_SHAPE_SPHERE: shape_name = "sphere"
			ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE: shape_name = "sphere_surface"
			ParticleProcessMaterial.EMISSION_SHAPE_BOX: shape_name = "box"
			ParticleProcessMaterial.EMISSION_SHAPE_RING: shape_name = "ring"
			_: shape_name = "unknown(%d)" % mat.emission_shape

		mat_info["emission_shape"] = shape_name

		match mat.emission_shape:
			ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE:
				mat_info["emission_sphere_radius"] = mat.emission_sphere_radius
			ParticleProcessMaterial.EMISSION_SHAPE_BOX:
				mat_info["emission_box_extents"] = str(mat.emission_box_extents)
			ParticleProcessMaterial.EMISSION_SHAPE_RING:
				mat_info["emission_ring_radius"] = mat.emission_ring_radius
				mat_info["emission_ring_inner_radius"] = mat.emission_ring_inner_radius
				mat_info["emission_ring_height"] = mat.emission_ring_height

		# Color gradient
		if mat.color_ramp != null and mat.color_ramp is GradientTexture1D:
			var grad_tex: GradientTexture1D = mat.color_ramp
			if grad_tex.gradient != null:
				var gradient_stops: Array = []
				var grad: Gradient = grad_tex.gradient
				for i in grad.get_point_count():
					gradient_stops.append({
						"offset": grad.get_offset(i),
						"color": str(grad.get_color(i)),
					})
				mat_info["color_ramp"] = gradient_stops

		info["material"] = mat_info
	else:
		info["material"] = null

	return success(info)


func _set_particle_emitting(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _get_particles_node_any(r0[0])
	if node == null:
		return error_not_found("GPUParticles2D/3D at '%s'" % r0[0])
	var emitting: bool = optional_bool(params, "emitting", true)
	node.set("emitting", emitting)
	if params.has("one_shot"):
		node.set("one_shot", bool(params["one_shot"]))
	if params.has("explosiveness"):
		node.set("explosiveness", float(params["explosiveness"]))
	if params.has("randomness"):
		node.set("randomness", float(params["randomness"]))
	if params.has("lifetime"):
		node.set("lifetime", float(params["lifetime"]))
	if params.has("preprocess"):
		node.set("preprocess", float(params["preprocess"]))
	if params.has("speed_scale"):
		node.set("speed_scale", float(params["speed_scale"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "emitting": node.get("emitting")})


func _set_particle_amount(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _get_particles_node_any(r0[0])
	if node == null:
		return error_not_found("GPUParticles")
	var amount: int = optional_int(params, "amount", 8)
	node.set("amount", amount)
	if params.has("amount_ratio"):
		node.set("amount_ratio", float(params["amount_ratio"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "amount": amount})


func _set_particle_trail(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _get_particles_node_any(r0[0])
	if node == null:
		return error_not_found("GPUParticles")
	if not ("trail_enabled" in node):
		return error_invalid_params("This particle node has no trail_enabled (GPUParticles3D trails / check version)")
	node.set("trail_enabled", optional_bool(params, "enabled", true))
	if params.has("lifetime") and "trail_lifetime" in node:
		node.set("trail_lifetime", float(params["lifetime"]))
	if params.has("sections") and "trail_sections" in node:
		node.set("trail_sections", int(params["sections"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "trail_enabled": node.get("trail_enabled")})


func _set_particle_subemitter(params: Dictionary) -> Dictionary:
	## Wire sub_emitter NodePath on GPUParticles to another particle system.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sub_r := require_string(params, "sub_emitter_path")
	if sub_r[1] != null:
		return sub_r[1]
	var node := _get_particles_node_any(r0[0])
	if node == null:
		return error_not_found("GPUParticles")
	if not ("sub_emitter" in node):
		return error_invalid_params("No sub_emitter property")
	node.set("sub_emitter", NodePath(sub_r[0]))
	if params.has("mode") and "sub_emitter_mode" in node:
		# 0=disabled, 1=constant, 2=at_end, 3=at_collision - accept int or string
		var mode = params["mode"]
		if mode is String:
			match str(mode):
				"constant": node.set("sub_emitter_mode", 1)
				"at_end": node.set("sub_emitter_mode", 2)
				"at_collision": node.set("sub_emitter_mode", 3)
				_: node.set("sub_emitter_mode", 0)
		else:
			node.set("sub_emitter_mode", int(mode))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "sub_emitter": sub_r[0]})


func _set_particle_collision(params: Dictionary) -> Dictionary:
	## Enable collision mode on GPUParticles2D/3D (responds to GPUParticlesCollision* nodes).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _get_particles_node_any(r0[0])
	if node == null:
		return error_not_found("GPUParticles")
	var applied := {}
	if "collision_mode" in node:
		var mode = params.get("mode", params.get("collision_mode", "rigid"))
		if mode is String:
			match str(mode).to_lower():
				"disabled", "off":
					node.set("collision_mode", 0)
				"rigid":
					node.set("collision_mode", 1)
				"hide_on_contact", "hide":
					node.set("collision_mode", 2)
				_:
					node.set("collision_mode", int(mode) if str(mode).is_valid_int() else 1)
		else:
			node.set("collision_mode", int(mode))
		applied["collision_mode"] = node.get("collision_mode")
	if params.has("collision_friction") and "collision_friction" in node:
		node.set("collision_friction", float(params["collision_friction"]))
		applied["collision_friction"] = node.get("collision_friction")
	if params.has("collision_bounce") and "collision_bounce" in node:
		node.set("collision_bounce", float(params["collision_bounce"]))
		applied["collision_bounce"] = node.get("collision_bounce")
	if params.has("collision_base_size") and "collision_base_size" in node:
		node.set("collision_base_size", float(params["collision_base_size"]))
		applied["collision_base_size"] = node.get("collision_base_size")
	if applied.is_empty():
		return error_invalid_params("No collision properties applied (check GPUParticles version)")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _add_gpu_particles_collision(params: Dictionary) -> Dictionary:
	## Add GPUParticlesCollisionBox3D / Sphere / HeightField or 2D equivalents.
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var shape: String = optional_string(params, "shape", "box")
	var dim: String = optional_string(params, "dimension", "")
	if dim.is_empty():
		dim = "3d" if parent is Node3D else "2d"
	var node: Node = null
	if dim == "3d":
		match shape:
			"sphere":
				if ClassDB.class_exists("GPUParticlesCollisionSphere3D"):
					node = ClassDB.instantiate("GPUParticlesCollisionSphere3D")
					if params.has("radius"):
						node.set("radius", float(params["radius"]))
			"heightfield", "height_field":
				if ClassDB.class_exists("GPUParticlesCollisionHeightField3D"):
					node = ClassDB.instantiate("GPUParticlesCollisionHeightField3D")
			_:
				if ClassDB.class_exists("GPUParticlesCollisionBox3D"):
					node = ClassDB.instantiate("GPUParticlesCollisionBox3D")
					if "size" in node:
						node.set("size", Vector3(
							float(params.get("size_x", params.get("width", 2.0))),
							float(params.get("size_y", params.get("height", 2.0))),
							float(params.get("size_z", params.get("depth", 2.0)))
						))
	else:
		match shape:
			"sphere", "circle":
				if ClassDB.class_exists("GPUParticlesCollisionSphere2D"):
					node = ClassDB.instantiate("GPUParticlesCollisionSphere2D")
			_:
				if ClassDB.class_exists("GPUParticlesCollisionBox2D"):
					node = ClassDB.instantiate("GPUParticlesCollisionBox2D")
	if node == null:
		return error_internal("GPUParticlesCollision* class not available for shape=%s dim=%s" % [shape, dim])
	node.name = optional_string(params, "name", node.get_class())
	add_child_with_undo(parent, node, root, "MCP: Add GPUParticlesCollision")
	return success({"node_path": str(root.get_path_to(node)), "type": node.get_class(), "shape": shape})
