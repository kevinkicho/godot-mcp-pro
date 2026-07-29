@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## ParticleProcessMaterial depth + attractors + draw passes (tutorials/shaders + VFX structure).


func get_commands() -> Dictionary:
	return {
		"set_particle_process_params": _set_particle_process_params,
		"set_particle_emission_shape": _set_particle_emission_shape,
		"set_particle_turbulence": _set_particle_turbulence,
		"set_particle_draw_pass": _set_particle_draw_pass,
		"add_gpu_particles_attractor": _add_gpu_particles_attractor,
		"create_cpu_particles": _create_cpu_particles,
		"restart_particles": _restart_particles,
		"list_particle_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_particles", "set_particle_material", "apply_particle_preset", "set_particle_trail"],
		"flow": [
			"create_particles -> set_particle_process_params",
			"set_particle_emission_shape / set_particle_turbulence",
			"set_particle_draw_pass mesh=...",
			"add_gpu_particles_attractor for force fields",
		],
	})


func _pany(path: String) -> Node:
	var n := find_node_by_path(path)
	if n is GPUParticles2D or n is GPUParticles3D or n is CPUParticles2D or n is CPUParticles3D:
		return n
	return null


func _ensure_ppm(node: Node) -> ParticleProcessMaterial:
	var mat = node.get("process_material") if "process_material" in node else null
	if mat is ParticleProcessMaterial:
		return (mat as ParticleProcessMaterial).duplicate(true) as ParticleProcessMaterial
	return ParticleProcessMaterial.new()


func _set_particle_process_params(params: Dictionary) -> Dictionary:
	## Bulk numerical ParticleProcessMaterial / CPU particle params.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _pany(r0[0])
	if node == null:
		return error_not_found("Particles node")
	var applied: Array = []

	# Node-level
	for k in ["amount", "lifetime", "one_shot", "preprocess", "explosiveness", "randomness",
			"speed_scale", "fixed_fps", "fract_delta", "visibility_aabb", "local_coords", "draw_order",
			"trail_enabled", "trail_lifetime", "emitting", "amount_ratio"]:
		if params.has(k) and k in node:
			node.set(k, params[k])
			applied.append(k)

	if node is GPUParticles2D or node is GPUParticles3D:
		var mat := _ensure_ppm(node)
		var keys := [
			"spread", "flatness", "initial_velocity_min", "initial_velocity_max",
			"angular_velocity_min", "angular_velocity_max", "orbit_velocity_min", "orbit_velocity_max",
			"radial_velocity_min", "radial_velocity_max", "linear_accel_min", "linear_accel_max",
			"radial_accel_min", "radial_accel_max", "tangential_accel_min", "tangential_accel_max",
			"damping_min", "damping_max", "scale_min", "scale_max", "hue_variation_min", "hue_variation_max",
			"anim_speed_min", "anim_speed_max", "anim_offset_min", "anim_offset_max",
			"collision_mode", "collision_friction", "collision_bounce", "particle_flag_align_y",
			"particle_flag_rotate_y", "particle_flag_disable_z", "attractor_interaction_enabled",
			"collision_use_scale", "sub_emitter_mode", "sub_emitter_frequency", "sub_emitter_amount_at_end",
		]
		for k in keys:
			if params.has(k) and k in mat:
				mat.set(k, params[k])
				applied.append("mat." + k)
		if params.has("direction"):
			mat.direction = _vec3(params["direction"], mat.direction)
			applied.append("mat.direction")
		if params.has("gravity"):
			mat.gravity = _vec3(params["gravity"], mat.gravity)
			applied.append("mat.gravity")
		if params.has("color"):
			mat.color = _color(params["color"])
			applied.append("mat.color")
		if params.has("emission_shape"):
			_apply_emission(mat, params)
			applied.append("mat.emission_shape")
		set_property_with_undo(node, "process_material", mat, "MCP: Particle process params")
	else:
		# CPU particles share many property names on the node
		for k in ["direction", "spread", "gravity", "initial_velocity_min", "initial_velocity_max",
				"scale_amount_min", "scale_amount_max", "color"]:
			if params.has(k) and k in node:
				var v = params[k]
				if k in ["direction", "gravity"] and v is Dictionary:
					if node is CPUParticles3D:
						node.set(k, _vec3(v, Vector3.ZERO))
					else:
						node.set(k, Vector2(float(v.get("x", 0)), float(v.get("y", 0))))
				elif k == "color":
					node.set(k, _color(v))
				else:
					node.set(k, v)
				applied.append(k)

	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _set_particle_emission_shape(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _pany(r0[0])
	if node == null or not (node is GPUParticles2D or node is GPUParticles3D):
		return error_not_found("GPUParticles2D/3D")
	var mat := _ensure_ppm(node)
	_apply_emission(mat, params)
	set_property_with_undo(node, "process_material", mat, "MCP: Particle emission shape")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "emission_shape": mat.emission_shape})


func _apply_emission(mat: ParticleProcessMaterial, params: Dictionary) -> void:
	var shape_str: String = str(params.get("emission_shape", params.get("shape", "point"))).to_lower()
	match shape_str:
		"sphere":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			if params.has("radius") or params.has("emission_sphere_radius"):
				mat.emission_sphere_radius = float(params.get("radius", params.get("emission_sphere_radius", 1.0)))
		"sphere_surface":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			if params.has("radius") or params.has("emission_sphere_radius"):
				mat.emission_sphere_radius = float(params.get("radius", params.get("emission_sphere_radius", 1.0)))
		"box":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			if params.has("extents") or params.has("emission_box_extents"):
				mat.emission_box_extents = _vec3(params.get("extents", params.get("emission_box_extents")), Vector3.ONE)
		"ring":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			if params.has("emission_ring_radius") or params.has("radius"):
				mat.emission_ring_radius = float(params.get("emission_ring_radius", params.get("radius", 1.0)))
			if params.has("emission_ring_inner_radius") or params.has("inner_radius"):
				mat.emission_ring_inner_radius = float(params.get("emission_ring_inner_radius", params.get("inner_radius", 0.0)))
			if params.has("emission_ring_height") or params.has("height"):
				mat.emission_ring_height = float(params.get("emission_ring_height", params.get("height", 0.0)))
		_:
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT


func _set_particle_turbulence(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _pany(r0[0])
	if node == null or not (node is GPUParticles2D or node is GPUParticles3D):
		return error_not_found("GPUParticles")
	var mat := _ensure_ppm(node)
	var applied := {}
	if "turbulence_enabled" in mat:
		mat.turbulence_enabled = optional_bool(params, "enabled", true)
		applied["turbulence_enabled"] = mat.turbulence_enabled
	for k in ["turbulence_noise_strength", "turbulence_noise_scale", "turbulence_noise_speed_random",
			"turbulence_influence_min", "turbulence_influence_max", "turbulence_initial_displacement_min",
			"turbulence_initial_displacement_max"]:
		var short_k := k.replace("turbulence_", "")
		if params.has(k) and k in mat:
			mat.set(k, float(params[k]))
			applied[k] = mat.get(k)
		elif params.has(short_k) and k in mat:
			mat.set(k, float(params[short_k]))
			applied[k] = mat.get(k)
	if params.has("turbulence_noise_speed") and "turbulence_noise_speed" in mat:
		mat.turbulence_noise_speed = _vec3(params["turbulence_noise_speed"], Vector3.ZERO)
		applied["turbulence_noise_speed"] = true
	set_property_with_undo(node, "process_material", mat, "MCP: Particle turbulence")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _set_particle_draw_pass(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var pass_idx: int = optional_int(params, "pass", 0)
	if node is GPUParticles3D:
		var p3 := node as GPUParticles3D
		var mesh_path: String = optional_string(params, "mesh_path", "")
		if not mesh_path.is_empty() and ResourceLoader.exists(mesh_path):
			var mesh = load(mesh_path)
			if mesh is Mesh:
				if pass_idx == 0:
					p3.draw_pass_1 = mesh
				elif pass_idx == 1 and "draw_pass_2" in p3:
					p3.draw_pass_2 = mesh
				elif pass_idx == 2 and "draw_pass_3" in p3:
					p3.draw_pass_3 = mesh
				elif pass_idx == 3 and "draw_pass_4" in p3:
					p3.draw_pass_4 = mesh
		if params.has("draw_passes"):
			p3.draw_passes = int(params["draw_passes"])
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "pass": pass_idx, "mesh_path": mesh_path})
	if node is GPUParticles2D:
		var p2 := node as GPUParticles2D
		var tex_path: String = optional_string(params, "texture_path", optional_string(params, "mesh_path", ""))
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			var tex = load(tex_path)
			if tex is Texture2D:
				p2.texture = tex
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "texture_path": tex_path})
	return error_invalid_params("GPUParticles2D/3D required")


func _add_gpu_particles_attractor(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var kind: String = optional_string(params, "kind", "sphere").to_lower()  # sphere | box | vector_field
	var node: Node3D
	match kind:
		"box":
			if ClassDB.class_exists("GPUParticlesAttractorBox3D"):
				node = ClassDB.instantiate("GPUParticlesAttractorBox3D")
			else:
				return error_internal("GPUParticlesAttractorBox3D unavailable")
		"vector_field":
			if ClassDB.class_exists("GPUParticlesAttractorVectorField3D"):
				node = ClassDB.instantiate("GPUParticlesAttractorVectorField3D")
			else:
				return error_internal("GPUParticlesAttractorVectorField3D unavailable")
		_:
			if ClassDB.class_exists("GPUParticlesAttractorSphere3D"):
				node = ClassDB.instantiate("GPUParticlesAttractorSphere3D")
			else:
				return error_internal("GPUParticlesAttractorSphere3D unavailable")
	node.name = optional_string(params, "name", "ParticlesAttractor")
	if params.has("strength") and "strength" in node:
		node.set("strength", float(params["strength"]))
	if params.has("attenuation") and "attenuation" in node:
		node.set("attenuation", float(params["attenuation"]))
	if params.has("directionality") and "directionality" in node:
		node.set("directionality", float(params["directionality"]))
	if params.has("radius") and "radius" in node:
		node.set("radius", float(params["radius"]))
	if params.has("size") and "size" in node:
		node.set("size", _vec3(params["size"], Vector3.ONE))
	if params.has("position"):
		node.position = _vec3(params["position"], Vector3.ZERO)
	add_child_with_undo(parent, node, root, "MCP: Particle attractor")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "kind": kind, "class": node.get_class()})


func _create_cpu_particles(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var is_3d: bool = optional_bool(params, "is_3d", false)
	var node: Node
	if is_3d:
		var p := CPUParticles3D.new()
		p.name = optional_string(params, "name", "CPUParticles3D")
		p.amount = optional_int(params, "amount", 32)
		p.lifetime = float(params.get("lifetime", 1.0))
		p.emitting = optional_bool(params, "emitting", true)
		node = p
	else:
		var p2 := CPUParticles2D.new()
		p2.name = optional_string(params, "name", "CPUParticles2D")
		p2.amount = optional_int(params, "amount", 32)
		p2.lifetime = float(params.get("lifetime", 1.0))
		p2.emitting = optional_bool(params, "emitting", true)
		node = p2
	add_child_with_undo(parent, node, root, "MCP: CPUParticles")
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(node)), "is_3d": is_3d})


func _restart_particles(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := _pany(r0[0])
	if node == null:
		return error_not_found("Particles")
	if node.has_method("restart"):
		node.call("restart")
	elif "emitting" in node:
		node.set("emitting", false)
		node.set("emitting", true)
	return success({"node_path": r0[0], "restarted": true})


func _vec3(v: Variant, default: Vector3) -> Vector3:
	if v is Dictionary:
		return Vector3(float(v.get("x", default.x)), float(v.get("y", default.y)), float(v.get("z", default.z)))
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is Vector3:
		return v
	return default


func _color(v: Variant) -> Color:
	if v is Color:
		return v
	var s := str(v)
	if s.begins_with("#"):
		return Color.html(s)
	return Color.WHITE
