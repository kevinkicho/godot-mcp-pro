@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Import option schemas by asset type — agent-facing Import dock documentation.


func get_commands() -> Dictionary:
	return {
		"list_import_option_schema": _list_import_option_schema,
		"list_import_types": _list_import_types,
		"apply_import_schema_preset": _apply_import_schema_preset,
		"get_import_options_for_path": _get_import_options_for_path,
		"list_import_schema_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"types": ["texture", "scene_3d", "audio", "font", "csv", "wav", "ogg"],
		"related": ["get_import_info", "set_import_options", "apply_texture_import_preset", "apply_scene_import_preset"],
	})


func _schemas() -> Dictionary:
	return {
		"texture": {
			"importer": "texture",
			"common_params": {
				"compress/mode": {"type": "int", "values": {"lossless": 0, "lossy": 1, "vram_compressed": 2, "vram_uncompressed": 3, "basis_universal": 4}, "hint": "VRAM compressed for 3D"},
				"compress/high_quality": {"type": "bool"},
				"compress/lossy_quality": {"type": "float", "range": [0.0, 1.0]},
				"mipmaps/generate": {"type": "bool"},
				"process/fix_alpha": {"type": "bool"},
				"detect_3d/compress_to": {"type": "int", "hint": "0 disabled, 1 VRAM, 2 Basis"},
			},
			"presets": ["2d_pixel", "2d_ui", "3d_albedo", "3d_normal"],
		},
		"scene_3d": {
			"importer": "scene",
			"common_params": {
				"nodes/root_type": {"type": "string"},
				"meshes/ensure_tangents": {"type": "bool"},
				"meshes/generate_lods": {"type": "bool"},
				"meshes/create_shadow_meshes": {"type": "bool"},
				"meshes/light_baking": {"type": "int", "hint": "0 disabled, 1 static, 2 static lightmaps"},
				"animation/import": {"type": "bool"},
				"animation/fps": {"type": "int"},
				"skins/use_named_skins": {"type": "bool"},
			},
			"presets": ["game_prop", "character_animated", "static_level"],
		},
		"audio": {
			"importer": "wav / ogg / mp3",
			"common_params": {
				"force/8_bit": {"type": "bool"},
				"force/mono": {"type": "bool"},
				"force/max_rate": {"type": "bool"},
				"edit/trim": {"type": "bool"},
				"edit/normalize": {"type": "bool"},
				"compress/mode": {"type": "int"},
				"loop": {"type": "bool"},
				"loop_offset": {"type": "float"},
			},
			"presets": ["sfx_oneshot", "music_loop"],
		},
		"font": {
			"importer": "font_data_dynamic",
			"common_params": {
				"Fallbacks": {"type": "array"},
				"Compress": {"type": "bool"},
				"Allow System Fallback": {"type": "bool"},
			},
			"presets": ["ui_font"],
		},
		"csv": {
			"importer": "csv_translation",
			"common_params": {
				"compress": {"type": "bool"},
				"delimiter": {"type": "int", "hint": "0 comma, 1 semicolon, 2 tab"},
			},
			"presets": ["translations"],
		},
		"fbx": {
			"importer": "scene (FBX)",
			"common_params": {
				"nodes/root_type": {"type": "string"},
				"meshes/ensure_tangents": {"type": "bool"},
				"meshes/generate_lods": {"type": "bool"},
				"animation/import": {"type": "bool"},
				"animation/fps": {"type": "int"},
				"fbx/importer": {"type": "int", "hint": "0 ufbx, 1 legacy (version-dependent)"},
				"fbx/allow_geometry_helper_nodes": {"type": "bool"},
				"skins/use_named_skins": {"type": "bool"},
			},
			"presets": ["character_animated", "static_level", "game_prop"],
		},
		"ogg_vorbis": {
			"importer": "oggvorbisstr",
			"common_params": {
				"loop": {"type": "bool"},
				"loop_offset": {"type": "float"},
				"bpm": {"type": "float"},
				"beat_count": {"type": "int"},
				"bar_beats": {"type": "int"},
			},
			"presets": ["music_loop", "sfx_oneshot"],
		},
	}


func _list_import_types(_params: Dictionary) -> Dictionary:
	var s := _schemas()
	return success({"types": s.keys(), "schemas": s})


func _list_import_option_schema(params: Dictionary) -> Dictionary:
	var type_name: String = optional_string(params, "type", "texture").to_lower()
	var s := _schemas()
	if not s.has(type_name):
		# alias
		if type_name in ["png", "jpg", "jpeg", "webp", "svg"]:
			type_name = "texture"
		elif type_name in ["gltf", "glb", "fbx", "obj"]:
			type_name = "scene_3d"
		elif type_name in ["wav", "ogg", "mp3"]:
			type_name = "audio"
	if not s.has(type_name):
		return error_invalid_params("Unknown type — call list_import_types")
	return success({"type": type_name, "schema": s[type_name]})


func _get_import_options_for_path(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var ext := path.get_extension().to_lower()
	var type_name := "texture"
	match ext:
		"png", "jpg", "jpeg", "webp", "svg", "tga", "bmp":
			type_name = "texture"
		"gltf", "glb", "fbx", "obj", "dae", "blend":
			type_name = "scene_3d"
		"wav", "ogg", "mp3":
			type_name = "audio"
		"ttf", "otf", "woff", "woff2":
			type_name = "font"
		"csv":
			type_name = "csv"
	var schema = _schemas().get(type_name, {})
	# Live .import params
	var live := {}
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		var cfg := ConfigFile.new()
		if cfg.load(import_path) == OK and cfg.has_section("params"):
			for k in cfg.get_section_keys("params"):
				live[k] = cfg.get_value("params", k)
	return success({
		"path": path,
		"inferred_type": type_name,
		"schema": schema,
		"current_params": live,
		"has_import_file": FileAccess.file_exists(import_path),
	})


func _apply_import_schema_preset(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	var preset: String = optional_string(params, "preset", "")
	var type_name: String = optional_string(params, "type", "")
	if type_name.is_empty():
		var info := _get_import_options_for_path({"path": path})
		var ir = info.get("result", info)
		if ir is Dictionary:
			type_name = str(ir.get("inferred_type", "texture"))
	var options: Dictionary = {}
	match type_name:
		"texture":
			match preset:
				"2d_pixel":
					options = {"compress/mode": 0, "mipmaps/generate": false, "process/fix_alpha": true}
				"2d_ui":
					options = {"compress/mode": 0, "mipmaps/generate": false}
				"3d_albedo":
					options = {"compress/mode": 2, "mipmaps/generate": true}
				"3d_normal":
					options = {"compress/mode": 2, "mipmaps/generate": true, "compress/normal_map": 1}
				_:
					options = {"compress/mode": 2, "mipmaps/generate": true}
		"scene_3d":
			match preset:
				"character_animated":
					options = {
						"animation/import": true,
						"animation/fps": 30,
						"meshes/generate_lods": true,
						"meshes/ensure_tangents": true,
						"skins/use_named_skins": true,
					}
				"static_level":
					options = {
						"animation/import": false,
						"meshes/generate_lods": true,
						"meshes/create_shadow_meshes": true,
						"meshes/light_baking": 1,
					}
				_:
					options = {"meshes/generate_lods": true, "meshes/ensure_tangents": true}
		"audio":
			match preset:
				"music_loop":
					options = {"loop": true, "edit/normalize": false}
				_:
					options = {"loop": false, "edit/trim": true}
		_:
			if params.has("options") and params["options"] is Dictionary:
				options = params["options"]
			else:
				return error_invalid_params("Provide preset or options{}")
	if params.has("options") and params["options"] is Dictionary:
		for k in params["options"]:
			options[k] = params["options"][k]
	# Write via set_import_options pattern
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return error_not_found(".import for %s — import asset first" % path)
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return error_internal("load import failed")
	var applied := {}
	for k in options:
		cfg.set_value("params", str(k), options[k])
		applied[str(k)] = options[k]
	cfg.save(import_path)
	if optional_bool(params, "reimport", true):
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.reimport_files(PackedStringArray([path]))
	return success({
		"path": path,
		"type": type_name,
		"preset": preset,
		"applied": applied,
		"reimport": optional_bool(params, "reimport", true),
	})
