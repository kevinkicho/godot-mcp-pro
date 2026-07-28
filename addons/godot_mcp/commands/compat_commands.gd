@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Coding-Solo / godot-mcp parity tools for Godot MCP Pro.
## These fill gaps so Pro can do everything the free CLI MCP server can
## (plus editor-native workflows Pro already provides).


func get_commands() -> Dictionary:
	return {
		"get_godot_version": _get_godot_version,
		"get_uid": _get_uid,
		"update_project_uids": _update_project_uids,
		"load_sprite": _load_sprite,
		"export_mesh_library": _export_mesh_library,
		"list_projects": _list_projects,
		"launch_editor": _launch_editor,
		"list_mcp_commands": _list_mcp_commands,
	}


func _get_godot_version(_params: Dictionary) -> Dictionary:
	var info: Dictionary = Engine.get_version_info()
	var parts: PackedStringArray = []
	parts.append(str(info.get("major", 0)))
	parts.append(str(info.get("minor", 0)))
	if int(info.get("patch", 0)) > 0:
		parts.append(str(info.get("patch", 0)))
	var version_string := ".".join(parts)
	var status: String = str(info.get("status", ""))
	if not status.is_empty() and status != "stable":
		version_string += "-%s" % status
	var hash: String = str(info.get("hash", ""))
	if hash.length() >= 9:
		version_string += " (%s)" % hash.substr(0, 9)
	return success({
		"version": version_string,
		"version_info": info,
		"executable": OS.get_executable_path(),
	})


func _get_uid(params: Dictionary) -> Dictionary:
	# Accept both Coding-Solo (file_path) and Pro (path) parameter names.
	var path: String = optional_string(params, "file_path", "")
	if path.is_empty():
		path = optional_string(params, "path", "")
	if path.is_empty():
		return error_invalid_params("Missing required parameter: file_path (or path)")

	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")

	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return error_not_found("File '%s'" % path)

	var uid := ResourceLoader.get_resource_uid(path)
	if uid != ResourceUID.INVALID_ID:
		return success({
			"file": path,
			"path": path,
			"uid": ResourceUID.id_to_text(uid),
			"exists": true,
			"absolute_path": ProjectSettings.globalize_path(path),
		})

	# Fallback: read companion .uid file (older / text resources)
	var uid_path := path + ".uid"
	if FileAccess.file_exists(uid_path):
		var f := FileAccess.open(uid_path, FileAccess.READ)
		if f:
			var content := f.get_as_text().strip_edges()
			f.close()
			return success({
				"file": path,
				"path": path,
				"uid": content,
				"exists": true,
				"source": "uid_file",
				"absolute_path": ProjectSettings.globalize_path(path),
			})

	return success({
		"file": path,
		"path": path,
		"exists": false,
		"message": "No UID assigned. Use update_project_uids to generate UIDs by resaving resources.",
		"absolute_path": ProjectSettings.globalize_path(path),
	})


func _update_project_uids(params: Dictionary) -> Dictionary:
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	if not root_path.ends_with("/"):
		root_path += "/"

	var include_addons: bool = optional_bool(params, "include_addons", false)
	var extensions: Array[String] = [".tscn", ".scn", ".tres", ".res"]
	var files: Array[String] = []
	for ext in extensions:
		_collect_files(root_path, ext, files, include_addons)

	var success_count := 0
	var error_count := 0
	var errors: Array = []

	var skipped_open: Array = []
	for file_path in files:
		# Never offline-resave a scene currently open in the editor (data loss risk).
		if is_scene_resource_path(file_path) and is_scene_path_open(file_path):
			skipped_open.append(normalize_project_path(file_path))
			continue
		var resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			error_count += 1
			errors.append({"path": file_path, "error": "Failed to load"})
			continue
		var save_err := ResourceSaver.save(resource, file_path)
		if save_err == OK:
			success_count += 1
		else:
			error_count += 1
			errors.append({"path": file_path, "error": error_string(save_err)})

	# Nudge the editor filesystem so .uid files appear
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()

	return success({
		"rescanned_path": root_path,
		"files_found": files.size(),
		"saved": success_count,
		"errors": error_count,
		"skipped_open_scenes": skipped_open,
		"error_details": errors.slice(0, 20),
		"message": "Resaved resources to refresh UID references (Godot 4.4+). Open scenes were skipped.",
	})


func _load_sprite(params: Dictionary) -> Dictionary:
	var node_path: String = optional_string(params, "node_path", "")
	if node_path.is_empty():
		return error_invalid_params("Missing required parameter: node_path")

	var texture_path: String = optional_string(params, "texture_path", "")
	if texture_path.is_empty():
		return error_invalid_params("Missing required parameter: texture_path")
	if not texture_path.begins_with("res://"):
		texture_path = "res://" + texture_path.trim_prefix("/")

	# Optional: open a different scene first (Coding-Solo style)
	var scene_path: String = optional_string(params, "scene_path", "")
	if not scene_path.is_empty():
		if not scene_path.begins_with("res://"):
			scene_path = "res://" + scene_path.trim_prefix("/")
		if not FileAccess.file_exists(scene_path):
			return error_not_found("Scene '%s'" % scene_path)
		if not is_scene_path_open(scene_path):
			EditorInterface.open_scene_from_path(scene_path)

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	# Coding-Solo often uses "root/..." paths
	var lookup := node_path
	if lookup.begins_with("root/"):
		lookup = lookup.substr(5)
	elif lookup == "root":
		lookup = "."

	var node := find_node_by_path(lookup)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not (node is Sprite2D or node is Sprite3D or node is TextureRect):
		return error_invalid_params(
			"Node '%s' is type %s; expected Sprite2D, Sprite3D, or TextureRect" % [node_path, node.get_class()]
		)

	if not ResourceLoader.exists(texture_path):
		return error_not_found("Texture '%s'" % texture_path)

	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return error_internal("Failed to load texture: %s" % texture_path)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP Load Sprite")
	if node is Sprite2D:
		undo_redo.add_do_property(node, "texture", texture)
		undo_redo.add_undo_property(node, "texture", (node as Sprite2D).texture)
	elif node is Sprite3D:
		undo_redo.add_do_property(node, "texture", texture)
		undo_redo.add_undo_property(node, "texture", (node as Sprite3D).texture)
	elif node is TextureRect:
		undo_redo.add_do_property(node, "texture", texture)
		undo_redo.add_undo_property(node, "texture", (node as TextureRect).texture)
	undo_redo.commit_action()
	mark_current_scene_unsaved()

	return success({
		"node_path": node_path,
		"texture_path": texture_path,
		"node_type": node.get_class(),
		"scene_path": root.scene_file_path,
	})


func _export_mesh_library(params: Dictionary) -> Dictionary:
	var scene_path: String = optional_string(params, "scene_path", "")
	if scene_path.is_empty():
		scene_path = optional_string(params, "path", "")
	if scene_path.is_empty():
		return error_invalid_params("Missing required parameter: scene_path")
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")

	var output_path: String = optional_string(params, "output_path", "")
	if output_path.is_empty():
		return error_invalid_params("Missing required parameter: output_path")
	if not output_path.begins_with("res://"):
		output_path = "res://" + output_path.trim_prefix("/")

	if not FileAccess.file_exists(scene_path):
		return error_not_found("Scene '%s'" % scene_path)

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return error_internal("Failed to load scene: %s" % scene_path)

	var scene_root: Node = packed.instantiate()
	if scene_root == null:
		return error_internal("Failed to instantiate scene: %s" % scene_path)

	var mesh_item_names: Array = params.get("mesh_item_names", [])
	var use_filter := mesh_item_names.size() > 0
	var mesh_library := MeshLibrary.new()
	var item_id := 0
	var added: Array = []

	for child in scene_root.get_children():
		if use_filter and not (child.name in mesh_item_names):
			continue

		var mesh_instance: MeshInstance3D = null
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
		else:
			for descendant in child.get_children():
				if descendant is MeshInstance3D:
					mesh_instance = descendant as MeshInstance3D
					break

		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		mesh_library.create_item(item_id)
		mesh_library.set_item_name(item_id, child.name)
		mesh_library.set_item_mesh(item_id, mesh_instance.mesh)

		# MeshLibrary shapes must be Shape/Transform pairs, not bare Shape refs.
		for collision_child in child.get_children():
			if collision_child is CollisionShape3D and (collision_child as CollisionShape3D).shape:
				var col := collision_child as CollisionShape3D
				mesh_library.set_item_shapes(item_id, [col.shape, col.transform])
				break

		# set_item_preview requires Texture2D — never pass Mesh (parse/runtime type errors).
		var preview_tex: Texture2D = null
		if EditorInterface.has_method("make_mesh_previews"):
			var previews: Array = EditorInterface.make_mesh_previews([mesh_instance.mesh], 64)
			if previews.size() > 0 and previews[0] is Texture2D:
				preview_tex = previews[0]
		if preview_tex != null:
			mesh_library.set_item_preview(item_id, preview_tex)

		added.append(child.name)
		item_id += 1

	scene_root.queue_free()

	if item_id == 0:
		return error(-32000, "No valid MeshInstance3D meshes found in scene '%s'" % scene_path, {
			"suggestion": "Ensure the scene has MeshInstance3D children (or nested under root children).",
		})

	var dir_err := ensure_parent_dir(output_path)
	if not dir_err.is_empty():
		return dir_err

	var save_err := ResourceSaver.save(mesh_library, output_path)
	if save_err != OK:
		return error_internal("Failed to save MeshLibrary: %s" % error_string(save_err))

	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(output_path)
		fs.scan()

	return success({
		"scene_path": scene_path,
		"output_path": output_path,
		"item_count": item_id,
		"items": added,
		"absolute_path": ProjectSettings.globalize_path(output_path),
	})


func _list_projects(params: Dictionary) -> Dictionary:
	var directory: String = optional_string(params, "directory", "")
	if directory.is_empty():
		return error_invalid_params("Missing required parameter: directory (absolute path to search)")

	directory = directory.replace("\\", "/")
	if not DirAccess.dir_exists_absolute(directory):
		return error_not_found("Directory '%s'" % directory)

	var recursive: bool = optional_bool(params, "recursive", false)
	var projects: Array = []
	_find_godot_projects(directory, recursive, projects, 0, 8)

	return success({
		"directory": directory,
		"recursive": recursive,
		"count": projects.size(),
		"projects": projects,
	})


func _launch_editor(params: Dictionary) -> Dictionary:
	var project_path: String = optional_string(params, "project_path", "")
	if project_path.is_empty():
		project_path = optional_string(params, "path", "")
	if project_path.is_empty():
		# Default: relaunch current project (usually already open)
		project_path = ProjectSettings.globalize_path("res://")

	project_path = project_path.replace("\\", "/").trim_suffix("/")
	var project_file := project_path.path_join("project.godot")
	if not FileAccess.file_exists(project_file):
		return error_not_found(
			"Godot project at '%s'" % project_path,
			"Provide a directory containing project.godot"
		)

	var godot_exe := OS.get_executable_path()
	var args: PackedStringArray = ["--path", project_path, "-e"]
	var pid := OS.create_process(godot_exe, args)
	if pid < 0:
		return error_internal("Failed to spawn Godot editor process")

	return success({
		"project_path": project_path,
		"executable": godot_exe,
		"pid": pid,
		"message": "Launched Godot editor for project.",
	})


func _list_mcp_commands(params: Dictionary) -> Dictionary:
	var router := get_parent()
	if router == null or not router.has_method("get_available_methods"):
		return error_internal("Command router unavailable")
	var methods: Array = router.get_available_methods()
	methods.sort()
	var grouped := _group_commands_by_surface(methods)
	var filter: String = optional_string(params, "surface", optional_string(params, "filter", ""))
	var out_commands: Array = methods
	if not filter.is_empty():
		var fl := filter.to_lower()
		out_commands = []
		for m in methods:
			var ms := str(m).to_lower()
			if ms.contains(fl) or (grouped.has(fl) and str(m) in grouped[fl]):
				out_commands.append(m)
		if grouped.has(fl):
			out_commands = grouped[fl].duplicate()
			out_commands.sort()
	return success({
		"count": methods.size(),
		"commands": out_commands if filter.is_empty() else out_commands,
		"total_count": methods.size(),
		"filtered_count": out_commands.size(),
		"surfaces": grouped.keys(),
		"by_surface": grouped if optional_bool(params, "group", true) else {},
		"hint": "Human-worker surfaces: animation, skeleton, inspector, scene, script, assets, physics, ui, playtest. Use surface=animation to filter.",
	})


func _group_commands_by_surface(methods: Array) -> Dictionary:
	## Map plugin commands → human editor surfaces (for agent discovery parity).
	var groups := {
		"animation": [],
		"skeleton": [],
		"inspector": [],
		"scene": [],
		"script": [],
		"assets": [],
		"physics": [],
		"audio": [],
		"ui": [],
		"playtest": [],
		"project": [],
		"export": [],
		"navigation": [],
		"multiplayer": [],
		"i18n": [],
		"tiles": [],
		"classdb": [],
		"agent": [],
		"other": [],
	}
	for m in methods:
		var name := str(m)
		var nl := name.to_lower()
		var bucket := "other"
		if nl.begins_with("sprite_frames") or nl.contains("animation") or nl.contains("blend_") or nl.contains("state_machine") or nl.contains("tree_parameter") or nl.begins_with("travel_"):
			bucket = "animation"
		elif nl.contains("skeleton") or nl.contains("bone") or nl.contains("bone_map") or nl.contains("bone_attachment"):
			bucket = "skeleton"
		elif nl.contains("parallax") or nl.contains("camera_2d") or nl.contains("occluder") or nl.contains("canvas_modulate") or nl.contains("point_light"):
			bucket = "scene"
		elif nl.begins_with("config_file") or nl.begins_with("json_") or nl.begins_with("user_"):
			bucket = "project"
		elif nl.begins_with("debugger_") or nl.contains("breakpoint") or nl.begins_with("list_debugger") or nl.begins_with("open_script_at") or nl.begins_with("set_debug_"):
			bucket = "playtest"
		elif nl.contains("visual_shader") or nl.contains("shader"):
			bucket = "other"
		elif nl.contains("openxr") or nl.begins_with("xr_") or nl.contains("setup_xr") or nl.contains("list_xr"):
			bucket = "other"
		elif nl in ["inspect_node", "list_property_info", "update_property", "update_properties", "clear_property", "get_node_properties", "add_resource", "remove_resource", "connect_signal", "disconnect_signal", "get_signals", "set_meta", "list_meta", "get_meta", "remove_meta", "select_nodes", "get_editor_selection", "clear_editor_selection"]:
			bucket = "inspector"
		elif nl.contains("scene") or nl in ["add_node", "delete_node", "duplicate_node", "move_node", "rename_node", "get_scene_tree", "open_scene", "save_scene", "create_scene"] or nl.begins_with("set_node_groups") or nl.begins_with("get_node_groups") or nl.begins_with("find_nodes"):
			bucket = "scene"
		elif nl.contains("script") or nl in ["create_script", "edit_script", "read_script", "attach_script", "validate_script"]:
			bucket = "script"
		elif nl.contains("import") or nl.begins_with("res_") or nl in ["scan_filesystem", "get_filesystem_tree", "reimport_files", "wait_for_import", "load_sprite"]:
			bucket = "assets"
		elif nl.contains("physics") or nl.contains("collision") or nl.contains("joint") or nl.contains("raycast") or nl.begins_with("setup_area") or nl.begins_with("setup_physics"):
			bucket = "physics"
		elif nl.contains("audio"):
			bucket = "audio"
		elif nl.contains("theme") or nl.contains("anchor") or nl.begins_with("setup_control") or nl.contains("button"):
			bucket = "ui"
		elif nl.contains("play") or nl.contains("simulate") or nl.contains("screenshot") or nl.contains("game_") or nl in ["stop_scene", "get_editor_errors", "get_output_log", "assert_node_state"]:
			bucket = "playtest"
		elif nl.contains("project") or nl.contains("autoload") or nl.contains("input_action") or nl.contains("project_setting"):
			bucket = "project"
		elif nl.contains("export") or nl.contains("android"):
			bucket = "export"
		elif nl.contains("navigation"):
			bucket = "navigation"
		elif nl.contains("multiplayer"):
			bucket = "multiplayer"
		elif nl.contains("locale") or nl.contains("translation") or nl.contains("i18n"):
			bucket = "i18n"
		elif nl.contains("tile"):
			bucket = "tiles"
		elif nl in ["describe_class", "list_classes", "get_global_class_list"] or nl.begins_with("class_"):
			bucket = "classdb"
		elif nl in ["health_check", "agent_workflow_guide", "list_docs_coverage", "list_mcp_commands"]:
			bucket = "agent"
		groups[bucket].append(name)
	# Drop empty buckets
	var cleaned := {}
	for k in groups:
		if (groups[k] as Array).size() > 0:
			cleaned[k] = groups[k]
	return cleaned


func _collect_files(path: String, extension: String, out: Array[String], include_addons: bool) -> void:
	var base := path.rstrip("/")
	if base == "res:":
		base = "res://"
	var dir := DirAccess.open(base if base.ends_with("://") else base)
	if dir == null:
		# res:// open quirk: try with trailing slash
		dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String
		if base.ends_with("://"):
			full = base + name
		else:
			full = base.path_join(name)
		if dir.current_is_dir():
			if name == "addons" and not include_addons and (base == "res://" or base == "res:"):
				name = dir.get_next()
				continue
			_collect_files(full, extension, out, include_addons)
		elif name.ends_with(extension):
			out.append(full)
		name = dir.get_next()


func _find_godot_projects(directory: String, recursive: bool, out: Array, depth: int, max_depth: int) -> void:
	var project_file := directory.path_join("project.godot")
	if FileAccess.file_exists(project_file):
		var name := directory.get_file()
		var cfg := ConfigFile.new()
		if cfg.load(project_file) == OK:
			var cfg_name = cfg.get_value("application", "config/name", name)
			if typeof(cfg_name) == TYPE_STRING and not (cfg_name as String).is_empty():
				name = cfg_name
		out.append({"path": directory, "name": name})
		# A project directory is a leaf for discovery (don't recurse into it)
		return

	if not recursive and depth > 0:
		return
	if depth >= max_depth:
		return

	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		if dir.current_is_dir():
			var child_path := directory.path_join(entry)
			if recursive or depth == 0:
				_find_godot_projects(child_path, recursive, out, depth + 1, max_depth)
		entry = dir.get_next()
