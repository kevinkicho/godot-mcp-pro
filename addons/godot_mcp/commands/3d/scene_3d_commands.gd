@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")
const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")


func get_commands() -> Dictionary:
	return {
		"add_mesh_instance": _add_mesh_instance,
		"setup_lighting": _setup_lighting,
		"set_material_3d": _set_material_3d,
		"setup_environment": _setup_environment,
		"setup_camera_3d": _setup_camera_3d,
		"add_gridmap": _add_gridmap,
		"add_reflection_probe": _add_reflection_probe,
		"add_decal": _add_decal,
		"add_voxel_gi": _add_voxel_gi,
		"add_lightmap_gi": _add_lightmap_gi,
		"set_render_layers": _set_render_layers,
		"setup_csg_box": _setup_csg_box,
		"bake_voxel_gi": _bake_voxel_gi,
		"request_lightmap_bake": _request_lightmap_bake,
		"setup_path_3d": _setup_path_3d,
		"setup_csg_sphere": _setup_csg_sphere,
		"setup_csg_cylinder": _setup_csg_cylinder,
		"add_fog_volume": _add_fog_volume,
		"add_occluder_instance_3d": _add_occluder_instance_3d,
		"set_environment_fog": _set_environment_fog,
		"setup_world_environment": _setup_world_environment,
		"setup_compositor": _setup_compositor,
		"add_compositor_effect": _add_compositor_effect,
	}


## ─── Helpers ───────────────────────────────────────────────────────────────

func _optional_float(params: Dictionary, key: String, default: float) -> float:
	if params.has(key):
		return float(params[key])
	return default


func _parse_color_param(params: Dictionary, key: String, default: Color) -> Color:
	if not params.has(key):
		return default
	var val: Variant = params[key]
	if val is String:
		return PropertyParser.parse_value(val, TYPE_COLOR)
	if val is Dictionary:
		return Color(
			float(val.get("r", default.r)),
			float(val.get("g", default.g)),
			float(val.get("b", default.b)),
			float(val.get("a", default.a))
		)
	return default


func _parse_vector3_param(params: Dictionary, key: String, default: Vector3) -> Vector3:
	if not params.has(key):
		return default
	var val: Variant = params[key]
	if val is String:
		return PropertyParser.parse_value(val, TYPE_VECTOR3)
	if val is Dictionary:
		return Vector3(
			float(val.get("x", default.x)),
			float(val.get("y", default.y)),
			float(val.get("z", default.z))
		)
	if val is Array and val.size() >= 3:
		return Vector3(float(val[0]), float(val[1]), float(val[2]))
	return default


func _add_child_with_undo(node: Node, parent: Node, root: Node, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()


## ─── 1. add_mesh_instance ──────────────────────────────────────────────────

func _add_mesh_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "MeshInstance3D")
	var mesh_type: String = optional_string(params, "mesh_type", "")
	var mesh_file: String = optional_string(params, "mesh_file", "")

	if mesh_type.is_empty() and mesh_file.is_empty():
		return error_invalid_params("Either 'mesh_type' or 'mesh_file' is required")

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name

	if not mesh_file.is_empty():
		# Load .glb / .gltf / .obj
		if not ResourceLoader.exists(mesh_file):
			mesh_instance.queue_free()
			return error_not_found("Mesh file '%s'" % mesh_file, "Provide a valid res:// path to .glb, .gltf, or .obj")
		var loaded: Resource = load(mesh_file)
		if loaded is Mesh:
			mesh_instance.mesh = loaded as Mesh
		elif loaded is PackedScene:
			# For .glb/.gltf we instantiate and steal the first MeshInstance3D's mesh
			var scene_instance: Node = (loaded as PackedScene).instantiate()
			var found_mesh: Mesh = null
			var search_nodes: Array[Node] = [scene_instance]
			while not search_nodes.is_empty():
				var n: Node = search_nodes.pop_front()
				if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
					found_mesh = (n as MeshInstance3D).mesh
					break
				for child in n.get_children():
					search_nodes.append(child)
			scene_instance.queue_free()
			if found_mesh == null:
				mesh_instance.queue_free()
				return error_invalid_params("No mesh found in '%s'" % mesh_file)
			mesh_instance.mesh = found_mesh
		else:
			mesh_instance.queue_free()
			return error_invalid_params("'%s' is not a Mesh or PackedScene" % mesh_file)
	else:
		# Primitive mesh
		var mesh_classes := {
			"BoxMesh": BoxMesh,
			"SphereMesh": SphereMesh,
			"CylinderMesh": CylinderMesh,
			"CapsuleMesh": CapsuleMesh,
			"PlaneMesh": PlaneMesh,
			"PrismMesh": PrismMesh,
			"TorusMesh": TorusMesh,
			"QuadMesh": QuadMesh,
		}
		if not mesh_classes.has(mesh_type):
			mesh_instance.queue_free()
			return error_invalid_params("Unknown mesh_type '%s'. Available: %s" % [mesh_type, mesh_classes.keys()])
		var mesh_res: Mesh = mesh_classes[mesh_type].new()
		# Apply mesh properties if provided
		var mesh_properties: Dictionary = params.get("mesh_properties", {})
		for prop_name: String in mesh_properties:
			if prop_name in mesh_res:
				var current: Variant = mesh_res.get(prop_name)
				mesh_res.set(prop_name, PropertyParser.parse_value(mesh_properties[prop_name], typeof(current)))
		mesh_instance.mesh = mesh_res

	# Transform
	var position := _parse_vector3_param(params, "position", Vector3.ZERO)
	var rotation_deg := _parse_vector3_param(params, "rotation", Vector3.ZERO)
	var scale_vec := _parse_vector3_param(params, "scale", Vector3.ONE)

	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_deg
	mesh_instance.scale = scale_vec

	_add_child_with_undo(mesh_instance, parent, root, "MCP: Add MeshInstance3D")

	return success({
		"node_path": str(root.get_path_to(mesh_instance)),
		"name": str(mesh_instance.name),
		"mesh_type": mesh_type if mesh_file.is_empty() else mesh_file,
	})


## ─── 2. setup_lighting ────────────────────────────────────────────────────

func _setup_lighting(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var light_type: String = optional_string(params, "light_type", "")
	var preset: String = optional_string(params, "preset", "")
	var node_name: String = optional_string(params, "name", "")

	# Preset configurations
	if not preset.is_empty():
		match preset:
			"sun":
				light_type = "DirectionalLight3D"
				if node_name.is_empty():
					node_name = "SunLight"
			"indoor":
				light_type = "OmniLight3D"
				if node_name.is_empty():
					node_name = "IndoorLight"
			"dramatic":
				light_type = "SpotLight3D"
				if node_name.is_empty():
					node_name = "DramaticLight"
			_:
				return error_invalid_params("Unknown preset '%s'. Available: sun, indoor, dramatic" % preset)

	if light_type.is_empty():
		return error_invalid_params("Either 'light_type' or 'preset' is required")

	var light: Light3D
	match light_type:
		"DirectionalLight3D":
			light = DirectionalLight3D.new()
		"OmniLight3D":
			light = OmniLight3D.new()
		"SpotLight3D":
			light = SpotLight3D.new()
		_:
			return error_invalid_params("Unknown light_type '%s'. Available: DirectionalLight3D, OmniLight3D, SpotLight3D" % light_type)

	if node_name.is_empty():
		node_name = light_type
	light.name = node_name

	# Common properties
	light.light_color = _parse_color_param(params, "color", Color.WHITE)
	light.light_energy = _optional_float(params, "energy", 1.0)
	light.shadow_enabled = optional_bool(params, "shadows", false)

	# Type-specific properties
	if light is OmniLight3D:
		var omni: OmniLight3D = light as OmniLight3D
		omni.omni_range = _optional_float(params, "range", 5.0)
		omni.omni_attenuation = _optional_float(params, "attenuation", 1.0)
	elif light is SpotLight3D:
		var spot: SpotLight3D = light as SpotLight3D
		spot.spot_range = _optional_float(params, "range", 5.0)
		spot.spot_attenuation = _optional_float(params, "attenuation", 1.0)
		spot.spot_angle = _optional_float(params, "spot_angle", 45.0)
		spot.spot_angle_attenuation = _optional_float(params, "spot_angle_attenuation", 1.0)

	# Apply preset defaults after type creation
	if not preset.is_empty():
		match preset:
			"sun":
				light.light_energy = _optional_float(params, "energy", 1.0)
				light.shadow_enabled = optional_bool(params, "shadows", true)
				light.rotation_degrees = _parse_vector3_param(params, "rotation", Vector3(-45, -30, 0))
			"indoor":
				light.light_energy = _optional_float(params, "energy", 0.8)
				light.light_color = _parse_color_param(params, "color", Color(1.0, 0.95, 0.85))
				if light is OmniLight3D:
					(light as OmniLight3D).omni_range = _optional_float(params, "range", 8.0)
			"dramatic":
				light.light_energy = _optional_float(params, "energy", 2.0)
				light.shadow_enabled = optional_bool(params, "shadows", true)
				if light is SpotLight3D:
					(light as SpotLight3D).spot_angle = _optional_float(params, "spot_angle", 25.0)
					(light as SpotLight3D).spot_range = _optional_float(params, "range", 10.0)

	# Position / rotation
	light.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("rotation"):
		light.rotation_degrees = _parse_vector3_param(params, "rotation", light.rotation_degrees)

	_add_child_with_undo(light, parent, root, "MCP: Add %s" % light_type)

	return success({
		"node_path": str(root.get_path_to(light)),
		"name": str(light.name),
		"light_type": light_type,
		"preset": preset,
	})


## ─── 3. set_material_3d ───────────────────────────────────────────────────

func _set_material_3d(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	if not node is MeshInstance3D:
		return error_invalid_params("Node '%s' is not a MeshInstance3D (is %s)" % [node_path, node.get_class()])

	var mesh_inst: MeshInstance3D = node as MeshInstance3D
	var surface_index: int = optional_int(params, "surface_index", 0)

	var mat := StandardMaterial3D.new()

	# Albedo
	mat.albedo_color = _parse_color_param(params, "albedo_color", Color.WHITE)
	if params.has("albedo_texture"):
		var tex_path: String = params["albedo_texture"]
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path) as Texture2D

	# PBR
	mat.metallic = _optional_float(params, "metallic", 0.0)
	mat.roughness = _optional_float(params, "roughness", 1.0)
	if params.has("metallic_texture"):
		var tex_path: String = params["metallic_texture"]
		if ResourceLoader.exists(tex_path):
			mat.metallic_texture = load(tex_path) as Texture2D
	if params.has("roughness_texture"):
		var tex_path: String = params["roughness_texture"]
		if ResourceLoader.exists(tex_path):
			mat.roughness_texture = load(tex_path) as Texture2D
	if params.has("normal_texture"):
		mat.normal_enabled = true
		var tex_path: String = params["normal_texture"]
		if ResourceLoader.exists(tex_path):
			mat.normal_texture = load(tex_path) as Texture2D

	# Emission
	if params.has("emission") or params.has("emission_color"):
		mat.emission_enabled = true
		mat.emission = _parse_color_param(params, "emission", _parse_color_param(params, "emission_color", Color.BLACK))
		mat.emission_energy_multiplier = _optional_float(params, "emission_energy", 1.0)
	if params.has("emission_texture"):
		mat.emission_enabled = true
		var tex_path: String = params["emission_texture"]
		if ResourceLoader.exists(tex_path):
			mat.emission_texture = load(tex_path) as Texture2D

	# Transparency
	if params.has("transparency"):
		var transparency_val: String = str(params["transparency"])
		match transparency_val.to_upper():
			"DISABLED", "0":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			"ALPHA", "1":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"ALPHA_SCISSOR", "2":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"ALPHA_HASH", "3":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			"ALPHA_DEPTH_PRE_PASS", "4":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS

	# Cull mode
	if params.has("cull_mode"):
		var cull_val: String = str(params["cull_mode"])
		match cull_val.to_upper():
			"BACK", "0":
				mat.cull_mode = BaseMaterial3D.CULL_BACK
			"FRONT", "1":
				mat.cull_mode = BaseMaterial3D.CULL_FRONT
			"DISABLED", "2":
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Apply
	var old_mat: Material = mesh_inst.get_surface_override_material(surface_index)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set material on %s" % mesh_inst.name)
	undo_redo.add_do_method(mesh_inst, "set_surface_override_material", surface_index, mat)
	undo_redo.add_undo_method(mesh_inst, "set_surface_override_material", surface_index, old_mat)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(mesh_inst)),
		"surface_index": surface_index,
		"albedo_color": str(mat.albedo_color),
		"metallic": mat.metallic,
		"roughness": mat.roughness,
	})


## ─── 4. setup_environment ─────────────────────────────────────────────────

func _setup_environment(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "WorldEnvironment")

	# Check if a WorldEnvironment already exists at the target
	var node_path: String = optional_string(params, "node_path", "")
	var world_env: WorldEnvironment = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is WorldEnvironment:
			world_env = existing as WorldEnvironment
			is_existing = true

	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = node_name

	var env: Environment = world_env.environment
	if env == null:
		env = Environment.new()

	# Background / Sky
	var bg_mode: String = optional_string(params, "background_mode", "sky")
	match bg_mode.to_lower():
		"sky":
			env.background_mode = Environment.BG_SKY
		"color":
			env.background_mode = Environment.BG_COLOR
			env.background_color = _parse_color_param(params, "background_color", Color(0.3, 0.3, 0.3))
		"canvas":
			env.background_mode = Environment.BG_CANVAS
		"clear_color":
			env.background_mode = Environment.BG_CLEAR_COLOR

	# Procedural sky
	if params.has("sky") and params["sky"] is Dictionary:
		var sky_params: Dictionary = params["sky"]
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = _parse_color_param(sky_params, "sky_top_color", Color(0.385, 0.454, 0.55))
		sky_mat.sky_horizon_color = _parse_color_param(sky_params, "sky_horizon_color", Color(0.646, 0.654, 0.67))
		sky_mat.ground_bottom_color = _parse_color_param(sky_params, "ground_bottom_color", Color(0.2, 0.169, 0.133))
		sky_mat.ground_horizon_color = _parse_color_param(sky_params, "ground_horizon_color", Color(0.646, 0.654, 0.67))
		sky_mat.sun_angle_max = _optional_float(sky_params, "sun_angle_max", 30.0) if sky_params.has("sun_angle_max") else 30.0
		sky_mat.sky_curve = _optional_float(sky_params, "sky_curve", 0.15) if sky_params.has("sky_curve") else 0.15

		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY

	# Ambient light
	if params.has("ambient_light_color"):
		env.ambient_light_color = _parse_color_param(params, "ambient_light_color", Color.WHITE)
	env.ambient_light_energy = _optional_float(params, "ambient_light_energy", 1.0) if params.has("ambient_light_energy") else env.ambient_light_energy
	if params.has("ambient_light_source"):
		var src: String = str(params["ambient_light_source"])
		match src.to_upper():
			"BACKGROUND", "0":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			"DISABLED", "1":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			"COLOR", "2":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			"SKY", "3":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	# Tonemap
	if params.has("tonemap_mode"):
		var tm: String = str(params["tonemap_mode"])
		match tm.to_upper():
			"LINEAR", "0":
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"REINHARDT", "1":
				env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
			"FILMIC", "2":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"ACES", "3":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
			"AGX", "4":
				env.tonemap_mode = 4  # Environment.TONE_MAPPER_AGX (Godot 4.4+)
	if params.has("tonemap_exposure"):
		env.tonemap_exposure = _optional_float(params, "tonemap_exposure", 1.0)
	if params.has("tonemap_white"):
		env.tonemap_white = _optional_float(params, "tonemap_white", 1.0)

	# Fog
	if params.has("fog_enabled"):
		env.fog_enabled = optional_bool(params, "fog_enabled", false)
	if env.fog_enabled or params.has("fog_light_color"):
		env.fog_light_color = _parse_color_param(params, "fog_light_color", Color(0.518, 0.553, 0.608))
		env.fog_density = _optional_float(params, "fog_density", 0.01) if params.has("fog_density") else env.fog_density
		env.fog_light_energy = _optional_float(params, "fog_light_energy", 1.0) if params.has("fog_light_energy") else env.fog_light_energy

	# Glow
	if params.has("glow_enabled"):
		env.glow_enabled = optional_bool(params, "glow_enabled", false)
	if env.glow_enabled:
		env.glow_intensity = _optional_float(params, "glow_intensity", 0.8) if params.has("glow_intensity") else env.glow_intensity
		env.glow_strength = _optional_float(params, "glow_strength", 1.0) if params.has("glow_strength") else env.glow_strength
		env.glow_bloom = _optional_float(params, "glow_bloom", 0.0) if params.has("glow_bloom") else env.glow_bloom

	# SSAO
	if params.has("ssao_enabled"):
		env.ssao_enabled = optional_bool(params, "ssao_enabled", false)
	if env.ssao_enabled:
		env.ssao_radius = _optional_float(params, "ssao_radius", 1.0) if params.has("ssao_radius") else env.ssao_radius
		env.ssao_intensity = _optional_float(params, "ssao_intensity", 2.0) if params.has("ssao_intensity") else env.ssao_intensity

	# SSR
	if params.has("ssr_enabled"):
		env.ssr_enabled = optional_bool(params, "ssr_enabled", false)
	if env.ssr_enabled:
		env.ssr_max_steps = optional_int(params, "ssr_max_steps", 64) if params.has("ssr_max_steps") else env.ssr_max_steps
		env.ssr_fade_in = _optional_float(params, "ssr_fade_in", 0.15) if params.has("ssr_fade_in") else env.ssr_fade_in
		env.ssr_fade_out = _optional_float(params, "ssr_fade_out", 2.0) if params.has("ssr_fade_out") else env.ssr_fade_out

	# SDFGI
	if params.has("sdfgi_enabled"):
		env.sdfgi_enabled = optional_bool(params, "sdfgi_enabled", false)

	world_env.environment = env

	if not is_existing:
		_add_child_with_undo(world_env, parent, root, "MCP: Add WorldEnvironment")

	var features: Array = []
	if env.fog_enabled: features.append("fog")
	if env.glow_enabled: features.append("glow")
	if env.ssao_enabled: features.append("ssao")
	if env.ssr_enabled: features.append("ssr")
	if env.sdfgi_enabled: features.append("sdfgi")

	return success({
		"node_path": str(root.get_path_to(world_env)),
		"name": str(world_env.name),
		"background_mode": bg_mode,
		"features": features,
		"is_existing": is_existing,
	})


## ─── 5. setup_camera_3d ──────────────────────────────────────────────────

func _setup_camera_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	# Check if we're configuring an existing camera
	var node_path: String = optional_string(params, "node_path", "")
	var camera: Camera3D = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is Camera3D:
			camera = existing as Camera3D
			is_existing = true
		elif existing != null:
			return error_invalid_params("Node '%s' is not a Camera3D (is %s)" % [node_path, existing.get_class()])

	if camera == null:
		camera = Camera3D.new()
		camera.name = optional_string(params, "name", "Camera3D")

	# Projection
	var projection_str: String = optional_string(params, "projection", "")
	if not projection_str.is_empty():
		match projection_str.to_lower():
			"perspective", "0":
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			"orthogonal", "orthographic", "1":
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			"frustum", "2":
				camera.projection = Camera3D.PROJECTION_FRUSTUM

	# Properties
	if params.has("fov"):
		camera.fov = _optional_float(params, "fov", 75.0)
	if params.has("size"):
		camera.size = _optional_float(params, "size", 1.0)
	if params.has("near"):
		camera.near = _optional_float(params, "near", 0.05)
	if params.has("far"):
		camera.far = _optional_float(params, "far", 4000.0)
	if params.has("cull_mask"):
		camera.cull_mask = optional_int(params, "cull_mask", 1048575)

	# Make current
	camera.current = optional_bool(params, "current", false)

	# Transform
	camera.position = _parse_vector3_param(params, "position", camera.position if is_existing else Vector3(0, 1, 3))
	if params.has("rotation"):
		camera.rotation_degrees = _parse_vector3_param(params, "rotation", camera.rotation_degrees)
	if params.has("look_at"):
		var target := _parse_vector3_param(params, "look_at", Vector3.ZERO)
		# We need to set position first, then use look_at
		camera.look_at(target)

	# Environment override
	if params.has("environment_path"):
		var env_path: String = params["environment_path"]
		if ResourceLoader.exists(env_path):
			var env_res: Resource = load(env_path)
			if env_res is Environment:
				camera.environment = env_res as Environment

	if not is_existing:
		_add_child_with_undo(camera, parent, root, "MCP: Add Camera3D")

	return success({
		"node_path": str(root.get_path_to(camera)),
		"name": str(camera.name),
		"projection": "perspective" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "orthogonal",
		"fov": camera.fov,
		"position": str(camera.position),
		"is_existing": is_existing,
	})


## ─── 6. add_gridmap ──────────────────────────────────────────────────────

func _add_gridmap(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "GridMap")

	# Check for existing GridMap to configure
	var node_path: String = optional_string(params, "node_path", "")
	var gridmap: GridMap = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is GridMap:
			gridmap = existing as GridMap
			is_existing = true
		elif existing != null:
			return error_invalid_params("Node '%s' is not a GridMap (is %s)" % [node_path, existing.get_class()])

	if gridmap == null:
		gridmap = GridMap.new()
		gridmap.name = node_name

	# Mesh library
	if params.has("mesh_library_path"):
		var lib_path: String = params["mesh_library_path"]
		if not ResourceLoader.exists(lib_path):
			if not is_existing:
				gridmap.queue_free()
			return error_not_found("MeshLibrary '%s'" % lib_path, "Provide a valid res:// path to a .meshlib or .tres file")
		var lib: Resource = load(lib_path)
		if lib is MeshLibrary:
			gridmap.mesh_library = lib as MeshLibrary
		else:
			if not is_existing:
				gridmap.queue_free()
			return error_invalid_params("'%s' is not a MeshLibrary" % lib_path)

	# Cell size
	if params.has("cell_size"):
		gridmap.cell_size = _parse_vector3_param(params, "cell_size", Vector3(2, 2, 2))

	# Position
	gridmap.position = _parse_vector3_param(params, "position", gridmap.position if is_existing else Vector3.ZERO)

	if not is_existing:
		_add_child_with_undo(gridmap, parent, root, "MCP: Add GridMap")

	# Set cells
	var cells: Array = params.get("cells", [])
	var cells_set: int = 0
	for cell in cells:
		if cell is Dictionary:
			var x: int = int(cell.get("x", 0))
			var y: int = int(cell.get("y", 0))
			var z: int = int(cell.get("z", 0))
			var item: int = int(cell.get("item", 0))
			var orientation: int = int(cell.get("orientation", 0))
			gridmap.set_cell_item(Vector3i(x, y, z), item, orientation)
			cells_set += 1

	return success({
		"node_path": str(root.get_path_to(gridmap)),
		"name": str(gridmap.name),
		"cells_set": cells_set,
		"is_existing": is_existing,
		"has_mesh_library": gridmap.mesh_library != null,
	})


## ─── Rendering depth (probes, GI, decals, layers, CSG) ────────────────────

func _add_reflection_probe(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var probe := ReflectionProbe.new()
	probe.name = optional_string(params, "name", "ReflectionProbe")
	probe.size = _parse_vector3_param(params, "size", Vector3(10, 10, 10))
	probe.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("update_mode"):
		var um: String = str(params["update_mode"])
		match um:
			"once":
				probe.update_mode = ReflectionProbe.UPDATE_ONCE
			"always":
				probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	if params.has("enable_shadows"):
		probe.enable_shadows = bool(params["enable_shadows"])
	_add_child_with_undo(probe, parent, root, "MCP: Add ReflectionProbe")
	return success({"node_path": str(root.get_path_to(probe)), "type": "ReflectionProbe"})


func _add_decal(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var decal := Decal.new()
	decal.name = optional_string(params, "name", "Decal")
	decal.size = _parse_vector3_param(params, "size", Vector3(2, 2, 2))
	decal.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	var tex: String = optional_string(params, "texture_albedo", optional_string(params, "texture_path", ""))
	if not tex.is_empty() and ResourceLoader.exists(tex):
		decal.texture_albedo = load(tex)
	if params.has("albedo_mix"):
		decal.albedo_mix = float(params["albedo_mix"])
	if params.has("modulate"):
		var c = params["modulate"]
		if c is String:
			decal.modulate = Color.html(c) if str(c).begins_with("#") else Color(c)
	_add_child_with_undo(decal, parent, root, "MCP: Add Decal")
	return success({"node_path": str(root.get_path_to(decal)), "type": "Decal"})


func _add_voxel_gi(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var gi := VoxelGI.new()
	gi.name = optional_string(params, "name", "VoxelGI")
	gi.size = _parse_vector3_param(params, "size", Vector3(20, 20, 20))
	gi.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("subdiv"):
		gi.subdiv = int(params["subdiv"])
	_add_child_with_undo(gi, parent, root, "MCP: Add VoxelGI")
	return success({
		"node_path": str(root.get_path_to(gi)),
		"type": "VoxelGI",
		"hint": "Bake VoxelGI in editor (or execute_editor_script) after placing geometry",
	})


func _add_lightmap_gi(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var gi := LightmapGI.new()
	gi.name = optional_string(params, "name", "LightmapGI")
	_add_child_with_undo(gi, parent, root, "MCP: Add LightmapGI")
	return success({
		"node_path": str(root.get_path_to(gi)),
		"type": "LightmapGI",
		"hint": "Mark meshes UV2 + bake lightmaps in editor",
	})


func _set_render_layers(params: Dictionary) -> Dictionary:
	## VisualInstance3D.layers / Camera3D.cull_mask bit helpers.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var applied := {}
	if params.has("layers") and "layers" in node:
		node.set("layers", int(params["layers"]))
		applied["layers"] = node.get("layers")
	if params.has("layer_bits") and params["layer_bits"] is Array and "layers" in node:
		var mask := 0
		for b in params["layer_bits"]:
			var bit := int(b)
			if bit >= 1 and bit <= 20:
				mask |= (1 << (bit - 1))
		node.set("layers", mask)
		applied["layers"] = mask
	if params.has("cull_mask") and "cull_mask" in node:
		node.set("cull_mask", int(params["cull_mask"]))
		applied["cull_mask"] = node.get("cull_mask")
	if applied.is_empty():
		return error_invalid_params("Provide layers, layer_bits (1-20 array), or cull_mask")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "type": node.get_class(), "applied": applied})


func _setup_csg_box(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var op: String = optional_string(params, "operation", "union")  # union|intersection|subtraction
	var box := CSGBox3D.new()
	box.name = optional_string(params, "name", "CSGBox3D")
	box.size = _parse_vector3_param(params, "size", Vector3(1, 1, 1))
	box.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	match op:
		"intersection":
			box.operation = CSGShape3D.OPERATION_INTERSECTION
		"subtraction", "subtract":
			box.operation = CSGShape3D.OPERATION_SUBTRACTION
		_:
			box.operation = CSGShape3D.OPERATION_UNION
	if params.has("use_collision"):
		box.use_collision = bool(params["use_collision"])
	_add_child_with_undo(box, parent, root, "MCP: Add CSGBox3D")
	return success({"node_path": str(root.get_path_to(box)), "type": "CSGBox3D", "operation": op})


func _bake_voxel_gi(params: Dictionary) -> Dictionary:
	## Call bake on VoxelGI if API available (editor-only bake).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is VoxelGI:
		return error_not_found("VoxelGI at '%s'" % r0[0])
	var gi: VoxelGI = node
	if gi.has_method("bake"):
		# bake(from_node = null, create_visual_debug = false) in some versions
		if params.has("from_node"):
			var from_n := find_node_by_path(str(params["from_node"]))
			gi.call("bake", from_n)
		else:
			gi.call("bake")
		mark_current_scene_unsaved()
		return success({"node_path": r0[0], "baked": true})
	return error_internal("VoxelGI.bake() not available - bake from editor UI or execute_editor_script")


func _request_lightmap_bake(params: Dictionary) -> Dictionary:
	## Find LightmapGI and attempt bake; document UI fallback.
	var path: String = optional_string(params, "node_path", "")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var gi: LightmapGI = null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is LightmapGI:
			gi = n as LightmapGI
	else:
		gi = _find_first_lightmap(root)
	if gi == null:
		return error_not_found("LightmapGI in scene - use add_lightmap_gi first")
	# Godot's LightmapGI bake is primarily editor plugin - try method
	if gi.has_method("bake"):
		gi.call("bake")
		mark_current_scene_unsaved()
		return success({"node_path": str(root.get_path_to(gi)), "baked": true, "via": "bake()"})
	# Try EditorInterface bake if exists
	return success({
		"node_path": str(root.get_path_to(gi)),
		"baked": false,
		"message": "Lightmap bake must be run from editor UV2 + Bake Lighmaps UI in this Godot version",
		"hint": "Ensure meshes have UV2 / lightmap unwrap; select LightmapGI and use Bake",
	})


func _find_first_lightmap(node: Node) -> LightmapGI:
	if node is LightmapGI:
		return node as LightmapGI
	for c in node.get_children():
		var f := _find_first_lightmap(c)
		if f:
			return f
	return null


func _setup_path_3d(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var path := Path3D.new()
	path.name = optional_string(params, "name", "Path3D")
	var curve := Curve3D.new()
	var points: Array = params.get("points", [])
	if points is Array and points.size() > 0:
		for p in points:
			if p is Dictionary:
				curve.add_point(Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
			elif p is Array and p.size() >= 3:
				curve.add_point(Vector3(float(p[0]), float(p[1]), float(p[2])))
	else:
		curve.add_point(Vector3.ZERO)
		curve.add_point(Vector3(0, 0, -5))
		curve.add_point(Vector3(5, 0, -10))
	path.curve = curve
	_add_child_with_undo(path, parent, root, "MCP: Add Path3D")
	var follow_path := ""
	if optional_bool(params, "with_follow", false):
		var follow := PathFollow3D.new()
		follow.name = "PathFollow3D"
		path.add_child(follow)
		follow.owner = root
		follow_path = str(root.get_path_to(follow))
	return success({
		"node_path": str(root.get_path_to(path)),
		"point_count": curve.point_count,
		"path_follow": follow_path,
	})


func _setup_csg_sphere(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var sphere := CSGSphere3D.new()
	sphere.name = optional_string(params, "name", "CSGSphere3D")
	sphere.radius = float(params.get("radius", 0.5))
	sphere.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("use_collision"):
		sphere.use_collision = bool(params["use_collision"])
	_add_child_with_undo(sphere, parent, root, "MCP: Add CSGSphere3D")
	return success({"node_path": str(root.get_path_to(sphere)), "type": "CSGSphere3D"})


func _setup_csg_cylinder(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var cyl := CSGCylinder3D.new()
	cyl.name = optional_string(params, "name", "CSGCylinder3D")
	cyl.radius = float(params.get("radius", 0.5))
	cyl.height = float(params.get("height", 2.0))
	cyl.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("use_collision"):
		cyl.use_collision = bool(params["use_collision"])
	_add_child_with_undo(cyl, parent, root, "MCP: Add CSGCylinder3D")
	return success({"node_path": str(root.get_path_to(cyl)), "type": "CSGCylinder3D"})


func _add_fog_volume(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	if not ClassDB.class_exists("FogVolume"):
		return error_internal("FogVolume not available")
	var fog: Node = ClassDB.instantiate("FogVolume")
	fog.name = optional_string(params, "name", "FogVolume")
	if "size" in fog:
		fog.set("size", _parse_vector3_param(params, "size", Vector3(10, 5, 10)))
	fog.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("shape") and "shape" in fog:
		# 0=ellipsoid 1=cone 2=cylinder 3=box
		match str(params["shape"]).to_lower():
			"ellipsoid": fog.set("shape", 0)
			"cone": fog.set("shape", 1)
			"cylinder": fog.set("shape", 2)
			_: fog.set("shape", 3)
	_add_child_with_undo(fog, parent, root, "MCP: Add FogVolume")
	return success({"node_path": str(root.get_path_to(fog)), "type": "FogVolume"})


func _add_occluder_instance_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var occ := OccluderInstance3D.new()
	occ.name = optional_string(params, "name", "OccluderInstance3D")
	var shape_type: String = optional_string(params, "shape", "box")
	var occluder: Resource = null
	match shape_type:
		"sphere":
			if ClassDB.class_exists("SphereOccluder3D"):
				occluder = ClassDB.instantiate("SphereOccluder3D")
				if params.has("radius"):
					occluder.set("radius", float(params["radius"]))
		"quad":
			if ClassDB.class_exists("QuadOccluder3D"):
				occluder = ClassDB.instantiate("QuadOccluder3D")
		_:
			if ClassDB.class_exists("BoxOccluder3D"):
				occluder = ClassDB.instantiate("BoxOccluder3D")
				if "size" in occluder:
					occluder.set("size", _parse_vector3_param(params, "size", Vector3(1, 1, 1)))
	if occluder:
		occ.occluder = occluder
	occ.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	_add_child_with_undo(occ, parent, root, "MCP: Add OccluderInstance3D")
	return success({"node_path": str(root.get_path_to(occ)), "shape": shape_type})


func _setup_world_environment(params: Dictionary) -> Dictionary:
	## Ensure a WorldEnvironment exists (3D) with Environment resource.
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	# Reuse existing WorldEnvironment if present in scene
	var existing: WorldEnvironment = null
	var q: Array = [root]
	while not q.is_empty():
		var n: Node = q.pop_front()
		if n is WorldEnvironment:
			existing = n
			break
		for c in n.get_children():
			q.append(c)
	var we: WorldEnvironment
	if existing and not optional_bool(params, "force_new", false):
		we = existing
	else:
		we = WorldEnvironment.new()
		we.name = optional_string(params, "name", "WorldEnvironment")
		_add_child_with_undo(we, parent, root, "MCP: Add WorldEnvironment")
	if we.environment == null:
		we.environment = Environment.new()
	var env: Environment = we.environment
	if params.has("background_mode"):
		match str(params["background_mode"]).to_lower():
			"clear_color", "color":
				env.background_mode = Environment.BG_COLOR
			"sky":
				env.background_mode = Environment.BG_SKY
			"canvas":
				env.background_mode = Environment.BG_CANVAS
			_:
				env.background_mode = Environment.BG_CLEAR_COLOR
	if params.has("ambient_light_color"):
		var c = params["ambient_light_color"]
		if c is String:
			env.ambient_light_color = Color.html(c) if str(c).begins_with("#") else Color(c)
	if params.has("ambient_light_energy"):
		env.ambient_light_energy = float(params["ambient_light_energy"])
	if params.has("tonemap_mode"):
		match str(params["tonemap_mode"]).to_lower():
			"aces":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
			"filmic":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"linear":
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if optional_bool(params, "glow_enabled", false):
		env.glow_enabled = true
		env.glow_intensity = float(params.get("glow_intensity", 0.8))
	if optional_bool(params, "ssao_enabled", false):
		env.ssao_enabled = true
	if optional_bool(params, "ssil_enabled", false) and "ssil_enabled" in env:
		env.ssil_enabled = true
	if optional_bool(params, "sdfgi_enabled", false):
		env.sdfgi_enabled = true
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(we)),
		"background_mode": env.background_mode,
		"glow_enabled": env.glow_enabled,
		"sdfgi_enabled": env.sdfgi_enabled,
	})


func _set_environment_fog(params: Dictionary) -> Dictionary:
	## Configure volumetric/depth fog on WorldEnvironment's Environment.
	var path: String = optional_string(params, "node_path", "")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var we: WorldEnvironment = null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is WorldEnvironment:
			we = n
	else:
		var q: Array = [root]
		while not q.is_empty():
			var n2: Node = q.pop_front()
			if n2 is WorldEnvironment:
				we = n2
				break
			for c in n2.get_children():
				q.append(c)
	if we == null:
		var created := _setup_world_environment({"parent_path": "."})
		if created.has("error"):
			return created
		we = find_node_by_path(str(created["result"]["node_path"])) as WorldEnvironment
	if we == null or we.environment == null:
		return error_internal("No Environment on WorldEnvironment")
	var env: Environment = we.environment
	var applied := {}
	if params.has("volumetric_fog_enabled") or optional_bool(params, "volumetric", false):
		env.volumetric_fog_enabled = bool(params.get("volumetric_fog_enabled", true))
		applied["volumetric_fog_enabled"] = env.volumetric_fog_enabled
	if params.has("volumetric_fog_density"):
		env.volumetric_fog_density = float(params["volumetric_fog_density"])
		applied["volumetric_fog_density"] = env.volumetric_fog_density
	if params.has("volumetric_fog_albedo"):
		var a = params["volumetric_fog_albedo"]
		if a is String:
			env.volumetric_fog_albedo = Color.html(a) if str(a).begins_with("#") else Color(a)
		applied["volumetric_fog_albedo"] = env.volumetric_fog_albedo.to_html()
	if params.has("fog_enabled") or optional_bool(params, "depth_fog", false):
		env.fog_enabled = bool(params.get("fog_enabled", true))
		applied["fog_enabled"] = env.fog_enabled
	if params.has("fog_density"):
		env.fog_density = float(params["fog_density"])
		applied["fog_density"] = env.fog_density
	if params.has("fog_light_color"):
		var fc = params["fog_light_color"]
		if fc is String:
			env.fog_light_color = Color.html(fc) if str(fc).begins_with("#") else Color(fc)
		applied["fog_light_color"] = env.fog_light_color.to_html()
	if applied.is_empty():
		# Default enable light volumetric fog
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.05
		applied = {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.05}
	mark_current_scene_unsaved()
	return success({"node_path": str(root.get_path_to(we)), "applied": applied})


func _find_world_environment(root: Node) -> WorldEnvironment:
	var q: Array = [root]
	while not q.is_empty():
		var n: Node = q.pop_front()
		if n is WorldEnvironment:
			return n as WorldEnvironment
		for c in n.get_children():
			q.append(c)
	return null


func _setup_compositor(params: Dictionary) -> Dictionary:
	## Attach a Compositor resource to WorldEnvironment (Godot 4.3+ post-FX pipeline).
	if not ClassDB.class_exists("Compositor"):
		return error_internal("Compositor class not available in this Godot build (need 4.3+)")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var path: String = optional_string(params, "node_path", "")
	var we: WorldEnvironment = null
	if not path.is_empty():
		var n := find_node_by_path(path)
		if n is WorldEnvironment:
			we = n
	else:
		we = _find_world_environment(root)
	if we == null:
		var created := _setup_world_environment({"parent_path": optional_string(params, "parent_path", ".")})
		if created.has("error"):
			return created
		we = find_node_by_path(str(created["result"]["node_path"])) as WorldEnvironment
	if we == null:
		return error_internal("Failed to get WorldEnvironment")
	if we.environment == null:
		we.environment = Environment.new()
	var compositor: Resource = null
	if "compositor" in we and we.get("compositor") != null:
		compositor = we.get("compositor")
	else:
		compositor = ClassDB.instantiate("Compositor")
		if "compositor" in we:
			we.set("compositor", compositor)
		else:
			return error_internal("WorldEnvironment has no compositor property")
	# Optional save path
	var save_path: String = optional_string(params, "path", "")
	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path.trim_prefix("/")
		var derr := ensure_parent_dir(save_path)
		if not derr.is_empty():
			return derr
		ResourceSaver.save(compositor, save_path)
		if "compositor" in we:
			we.set("compositor", load(save_path))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(we)),
		"has_compositor": we.get("compositor") != null if "compositor" in we else false,
		"compositor_path": save_path,
		"hint": "Use add_compositor_effect for effect instances; full effects need 4.3+ compositor API.",
	})


func _add_compositor_effect(params: Dictionary) -> Dictionary:
	## Add a compositor effect resource if API exists (best-effort by class name).
	if not ClassDB.class_exists("Compositor"):
		return error_internal("Compositor not available")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var we := _find_world_environment(root)
	if we == null:
		return error_not_found("WorldEnvironment - call setup_compositor first")
	if not ("compositor" in we) or we.get("compositor") == null:
		var sc := _setup_compositor({})
		if sc.has("error"):
			return sc
		we = _find_world_environment(root)
	var compositor: Resource = we.get("compositor")
	var effect_type: String = optional_string(params, "effect_type", "")
	# Common built-ins vary by version; allow any ClassDB CompositorEffect*
	if effect_type.is_empty():
		# Prefer a known effect if present
		for cand in ["CompositorEffect", "SkyCompositorEffect"]:
			if ClassDB.class_exists(cand) and ClassDB.can_instantiate(cand):
				effect_type = cand
				break
	if effect_type.is_empty() or not ClassDB.class_exists(effect_type):
		return error_invalid_params(
			"Provide effect_type class name (CompositorEffect subclass). Available via describe_class / list_classes parent=CompositorEffect"
		)
	if not ClassDB.can_instantiate(effect_type):
		return error_invalid_params("Cannot instantiate %s" % effect_type)
	var effect: Resource = ClassDB.instantiate(effect_type)
	if effect == null:
		return error_internal("Failed to create effect")
	if "enabled" in effect:
		effect.set("enabled", optional_bool(params, "enabled", true))
	# Append to compositor effects array if present
	if compositor.has_method("add_compositor_effect"):
		compositor.call("add_compositor_effect", effect)
	elif "compositor_effects" in compositor:
		var arr: Array = compositor.get("compositor_effects")
		arr.append(effect)
		compositor.set("compositor_effects", arr)
	else:
		return error_internal("Cannot attach effect to Compositor (API mismatch)")
	mark_current_scene_unsaved()
	return success({
		"effect_type": effect_type,
		"world_environment": str(root.get_path_to(we)),
		"enabled": effect.get("enabled") if "enabled" in effect else true,
	})
