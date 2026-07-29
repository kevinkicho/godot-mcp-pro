@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## XR / OpenXR surface - project settings + scene node scaffold.


func get_commands() -> Dictionary:
	return {
		"setup_xr_origin": _setup_xr_origin,
		"set_xr_project_settings": _set_xr_project_settings,
		"get_xr_info": _get_xr_info,
		"add_xr_controller": _add_xr_controller,
		"list_xr_interfaces": _list_xr_interfaces,
		"create_openxr_action_map": _create_openxr_action_map,
		"openxr_add_action_set": _openxr_add_action_set,
		"openxr_add_action": _openxr_add_action,
		"openxr_get_action_map_info": _openxr_get_action_map_info,
		"set_openxr_action_map_path": _set_openxr_action_map_path,
		"add_xr_hand_modifier": _add_xr_hand_modifier,
		"list_openxr_interaction_profiles": _list_openxr_interaction_profiles,
		"openxr_add_interaction_profile": _openxr_add_interaction_profile,
		"openxr_bind_action": _openxr_bind_action,
		"openxr_create_default_controller_bindings": _openxr_create_default_controller_bindings,
	}


func _setup_xr_origin(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var origin := XROrigin3D.new()
	origin.name = optional_string(params, "name", "XROrigin3D")
	add_child_with_undo(parent, origin, root, "MCP: Add XROrigin3D")
	var cam := XRCamera3D.new()
	cam.name = "XRCamera3D"
	origin.add_child(cam)
	cam.owner = root
	var add_hands: bool = optional_bool(params, "controllers", true)
	if add_hands:
		for side in ["Left", "Right"]:
			var ctrl := XRController3D.new()
			ctrl.name = "XRController3D_%s" % side
			ctrl.tracker = "left_hand" if side == "Left" else "right_hand"
			origin.add_child(ctrl)
			ctrl.owner = root
	return success({
		"node_path": str(root.get_path_to(origin)),
		"type": "XROrigin3D",
		"has_camera": true,
		"controllers": add_hands,
		"hint": "Enable OpenXR in Project Settings (set_xr_project_settings) and export with XR support.",
	})


func _add_xr_controller(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", "")
	if parent_path.is_empty():
		return error_invalid_params("parent_path to XROrigin3D required")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var ctrl := XRController3D.new()
	ctrl.name = optional_string(params, "name", "XRController3D")
	ctrl.tracker = optional_string(params, "tracker", "left_hand")
	if params.has("pose"):
		ctrl.pose = str(params["pose"])
	add_child_with_undo(parent, ctrl, root, "MCP: Add XRController3D")
	return success({"node_path": str(root.get_path_to(ctrl)), "tracker": ctrl.tracker})


func _set_xr_project_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	# Common OpenXR / XR settings (Godot 4)
	var enable: bool = optional_bool(params, "enabled", true)
	if ProjectSettings.has_setting("xr/openxr/enabled") or true:
		ProjectSettings.set_setting("xr/openxr/enabled", enable)
		applied["xr/openxr/enabled"] = enable
	if params.has("form_factor"):
		# 0=Other, 1=Handheld, 2=HeadMounted - store as int if present
		ProjectSettings.set_setting("xr/openxr/form_factor", int(params["form_factor"]))
		applied["xr/openxr/form_factor"] = int(params["form_factor"])
	if params.has("submit_depth_buffer"):
		ProjectSettings.set_setting("xr/openxr/submit_depth_buffer", bool(params["submit_depth_buffer"]))
		applied["xr/openxr/submit_depth_buffer"] = bool(params["submit_depth_buffer"])
	if params.has("startup_alert"):
		ProjectSettings.set_setting("xr/openxr/startup_alert", bool(params["startup_alert"]))
		applied["xr/openxr/startup_alert"] = bool(params["startup_alert"])
	# Also enable plugins path note
	if optional_bool(params, "use_xr_interface", true):
		applied["hint"] = "Call XRServer.find_interface / initialize at runtime; export with OpenXR enabled."
	ProjectSettings.save()
	return success({"applied": applied})


func _get_xr_info(_params: Dictionary) -> Dictionary:
	var info := {
		"openxr_enabled": ProjectSettings.get_setting("xr/openxr/enabled", false),
		"has_xr_server": ClassDB.class_exists("XRServer"),
		"has_openxr": ClassDB.class_exists("OpenXRInterface") or ClassDB.class_exists("XRInterface"),
	}
	var root := get_edited_root()
	var nodes: Array = []
	if root:
		_find_xr(root, root, nodes)
	info["scene_xr_nodes"] = nodes
	return success(info)


func _find_xr(node: Node, root: Node, out: Array) -> void:
	var c := node.get_class()
	if c.begins_with("XR") or c.begins_with("OpenXR"):
		out.append({"path": str(root.get_path_to(node)), "type": c})
	for ch in node.get_children():
		_find_xr(ch, root, out)


func _list_xr_interfaces(_params: Dictionary) -> Dictionary:
	var names: Array = []
	if ClassDB.class_exists("XRServer"):
		# XRServer is a singleton at runtime; in editor list known classes
		for cname in ["OpenXRInterface", "WebXRInterface", "MobileVRInterface"]:
			if ClassDB.class_exists(cname):
				names.append(cname)
	return success({
		"interfaces": names,
		"note": "Runtime XRServer.get_interfaces() available when playing with XR enabled.",
	})


func _create_openxr_action_map(params: Dictionary) -> Dictionary:
	## Create OpenXRActionMap resource (interaction profile / actions container).
	if not ClassDB.class_exists("OpenXRActionMap"):
		return error_internal("OpenXRActionMap not available in this Godot build")
	var path: String = optional_string(params, "path", "res://openxr_action_map.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var am: Resource = ClassDB.instantiate("OpenXRActionMap")
	# Optional default action set
	var set_name: String = optional_string(params, "action_set", "godot")
	if ClassDB.class_exists("OpenXRActionSet"):
		var aset: Resource = ClassDB.instantiate("OpenXRActionSet")
		if "name" in aset:
			aset.set("name", set_name)
		if "localized_name" in aset:
			aset.set("localized_name", optional_string(params, "localized_name", set_name.capitalize()))
		if "priority" in aset:
			aset.set("priority", optional_int(params, "priority", 0))
		if am.has_method("add_action_set"):
			am.call("add_action_set", aset)
		elif "action_sets" in am:
			var arr: Array = am.get("action_sets")
			arr.append(aset)
			am.set("action_sets", arr)
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(am, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	if optional_bool(params, "set_as_default", true):
		ProjectSettings.set_setting("xr/openxr/default_action_map", path)
		ProjectSettings.set_setting("xr/openxr/enabled", true)
		ProjectSettings.save()
	return success({
		"path": path,
		"action_set": set_name,
		"set_as_default": optional_bool(params, "set_as_default", true),
		"type": "OpenXRActionMap",
	})


func _load_action_map(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


func _openxr_add_action_set(params: Dictionary) -> Dictionary:
	if not ClassDB.class_exists("OpenXRActionSet"):
		return error_internal("OpenXRActionSet unavailable")
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var am := _load_action_map(res[0])
	if am == null:
		return error_not_found("OpenXRActionMap at %s" % res[0])
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var aset: Resource = ClassDB.instantiate("OpenXRActionSet")
	aset.set("name", name_r[0])
	if "localized_name" in aset:
		aset.set("localized_name", optional_string(params, "localized_name", name_r[0]))
	if am.has_method("add_action_set"):
		am.call("add_action_set", aset)
	var err := ResourceSaver.save(am, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({"path": res[0], "action_set": name_r[0]})


func _openxr_add_action(params: Dictionary) -> Dictionary:
	## Add OpenXRAction to a named action set inside the map.
	if not ClassDB.class_exists("OpenXRAction"):
		return error_internal("OpenXRAction unavailable")
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var am := _load_action_map(res[0])
	if am == null:
		return error_not_found("OpenXRActionMap")
	var set_name: String = optional_string(params, "action_set", "godot")
	var action_name_r := require_string(params, "name")
	if action_name_r[1] != null:
		return action_name_r[1]
	var action_type_str: String = optional_string(params, "action_type", "boolean")
	# OpenXRAction.ActionType: BOOL=0, FLOAT=1, VECTOR2=2, POSE=3
	var action_type := 0
	match action_type_str.to_lower():
		"float": action_type = 1
		"vector2", "vec2": action_type = 2
		"pose": action_type = 3
		_: action_type = 0
	var action: Resource = ClassDB.instantiate("OpenXRAction")
	action.set("name", action_name_r[0])
	if "localized_name" in action:
		action.set("localized_name", optional_string(params, "localized_name", action_name_r[0]))
	if "action_type" in action:
		action.set("action_type", action_type)
	elif "type" in action:
		action.set("type", action_type)
	# Find action set
	var found_set: Resource = null
	if am.has_method("get_action_set_count") and am.has_method("get_action_set"):
		for i in am.call("get_action_set_count"):
			var s: Resource = am.call("get_action_set", i)
			if s and str(s.get("name")) == set_name:
				found_set = s
				break
	elif "action_sets" in am:
		for s in am.get("action_sets"):
			if s is Resource and str(s.get("name")) == set_name:
				found_set = s
				break
	if found_set == null:
		return error_not_found("Action set '%s' - create with openxr_add_action_set" % set_name)
	if found_set.has_method("add_action"):
		found_set.call("add_action", action)
	elif "actions" in found_set:
		var acts: Array = found_set.get("actions")
		acts.append(action)
		found_set.set("actions", acts)
	var err := ResourceSaver.save(am, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"action_set": set_name,
		"action": action_name_r[0],
		"action_type": action_type_str,
	})


func _openxr_get_action_map_info(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", str(ProjectSettings.get_setting("xr/openxr/default_action_map", "")))
	if path.is_empty():
		return success({"exists": false, "message": "No default action map set"})
	var am := _load_action_map(path)
	if am == null:
		return error_not_found(path)
	var sets: Array = []
	if am.has_method("get_action_set_count"):
		for i in am.call("get_action_set_count"):
			var s: Resource = am.call("get_action_set", i)
			var actions: Array = []
			if s and s.has_method("get_action_count"):
				for j in s.call("get_action_count"):
					var a: Resource = s.call("get_action", j)
					if a:
						actions.append({"name": str(a.get("name")), "type": a.get("action_type") if "action_type" in a else null})
			elif s and "actions" in s:
				for a in s.get("actions"):
					if a is Resource:
						actions.append({"name": str(a.get("name"))})
			sets.append({"name": str(s.get("name")) if s else "", "actions": actions})
	elif "action_sets" in am:
		for s in am.get("action_sets"):
			if s is Resource:
				sets.append({"name": str(s.get("name")), "class": s.get_class()})
	return success({"path": path, "action_sets": sets, "count": sets.size()})


func _set_openxr_action_map_path(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	ProjectSettings.set_setting("xr/openxr/default_action_map", res[0])
	if optional_bool(params, "enable_openxr", true):
		ProjectSettings.set_setting("xr/openxr/enabled", true)
	ProjectSettings.save()
	return success({"default_action_map": res[0], "openxr_enabled": ProjectSettings.get_setting("xr/openxr/enabled", false)})


func _add_xr_hand_modifier(params: Dictionary) -> Dictionary:
	## XRHandModifier3D / XRNode3D style hand tracking node when available.
	var parent_path: String = optional_string(params, "parent_path", "")
	if parent_path.is_empty():
		return error_invalid_params("parent_path required (usually under XROrigin3D)")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var class_name_str: String = optional_string(params, "type", "XRHandModifier3D")
	if not ClassDB.class_exists(class_name_str):
		# Fallback
		if ClassDB.class_exists("XRNode3D"):
			class_name_str = "XRNode3D"
		else:
			return error_internal("%s not available - use describe_class XR* for this Godot version" % class_name_str)
	var node: Node = ClassDB.instantiate(class_name_str)
	node.name = optional_string(params, "name", class_name_str)
	if "hand" in node and params.has("hand"):
		# 0=left 1=right often
		var hand = params["hand"]
		if hand is String:
			node.set("hand", 0 if str(hand).to_lower().begins_with("l") else 1)
		else:
			node.set("hand", int(hand))
	if "tracker" in node and params.has("tracker"):
		node.set("tracker", str(params["tracker"]))
	add_child_with_undo(parent, node, root, "MCP: Add XR hand node")
	return success({"node_path": str(root.get_path_to(node)), "type": class_name_str})


func _list_openxr_interaction_profiles(_params: Dictionary) -> Dictionary:
	## Common OpenXR interaction profile paths used for controller bindings.
	var profiles := [
		{"id": "khr_simple", "path": "/interaction_profiles/khr/simple_controller", "name": "Simple Controller"},
		{"id": "oculus_touch", "path": "/interaction_profiles/oculus/touch_controller", "name": "Oculus Touch"},
		{"id": "valve_index", "path": "/interaction_profiles/valve/index_controller", "name": "Valve Index"},
		{"id": "htc_vive", "path": "/interaction_profiles/htc/vive_controller", "name": "HTC Vive"},
		{"id": "microsoft_motion", "path": "/interaction_profiles/microsoft/motion_controller", "name": "Microsoft Motion"},
		{"id": "hp_mixed", "path": "/interaction_profiles/hp/mixed_reality_controller", "name": "HP Mixed Reality"},
		{"id": "samsung_odyssey", "path": "/interaction_profiles/samsung/odyssey_controller", "name": "Samsung Odyssey"},
		{"id": "htc_vive_cosmos", "path": "/interaction_profiles/htc/vive_cosmos_controller", "name": "Vive Cosmos"},
		{"id": "htc_vive_focus3", "path": "/interaction_profiles/htc/vive_focus3_controller", "name": "Vive Focus 3"},
		{"id": "huawei", "path": "/interaction_profiles/huawei/controller", "name": "Huawei"},
		{"id": "pico_neo3", "path": "/interaction_profiles/bytedance/pico_neo3_controller", "name": "Pico Neo 3"},
		{"id": "pico4", "path": "/interaction_profiles/bytedance/pico4_controller", "name": "Pico 4"},
		{"id": "meta_touch_pro", "path": "/interaction_profiles/facebook/touch_controller_pro", "name": "Meta Touch Pro"},
		{"id": "meta_touch_plus", "path": "/interaction_profiles/meta/touch_controller_plus", "name": "Meta Touch Plus"},
	]
	return success({
		"profiles": profiles,
		"count": profiles.size(),
		"note": "Use openxr_add_interaction_profile + openxr_bind_action, or openxr_create_default_controller_bindings.",
	})


func _openxr_add_interaction_profile(params: Dictionary) -> Dictionary:
	## Add OpenXRInteractionProfile to action map (if class exists).
	if not ClassDB.class_exists("OpenXRInteractionProfile"):
		return error_internal("OpenXRInteractionProfile not available in this Godot build")
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var am := _load_action_map(res[0])
	if am == null:
		return error_not_found("OpenXRActionMap")
	var profile_path: String = optional_string(params, "profile_path", "")
	var profile_id: String = optional_string(params, "profile_id", "oculus_touch")
	if profile_path.is_empty():
		var catalog = _list_openxr_interaction_profiles({})
		var profiles: Array = catalog.get("result", {}).get("profiles", [])
		for p in profiles:
			if p is Dictionary and str(p.get("id", "")) == profile_id:
				profile_path = str(p.get("path", ""))
				break
		if profile_path.is_empty():
			profile_path = "/interaction_profiles/oculus/touch_controller"
	var profile: Resource = ClassDB.instantiate("OpenXRInteractionProfile")
	if "interaction_profile_path" in profile:
		profile.set("interaction_profile_path", profile_path)
	elif "profile_path" in profile:
		profile.set("profile_path", profile_path)
	if am.has_method("add_interaction_profile"):
		am.call("add_interaction_profile", profile)
	elif "interaction_profiles" in am:
		var arr: Array = am.get("interaction_profiles")
		arr.append(profile)
		am.set("interaction_profiles", arr)
	else:
		return error_internal("Cannot add interaction profile to OpenXRActionMap (API mismatch)")
	var err := ResourceSaver.save(am, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"path": res[0],
		"profile_path": profile_path,
		"profile_id": profile_id,
		"added": true,
	})


func _openxr_bind_action(params: Dictionary) -> Dictionary:
	## Bind an action to a path on an interaction profile (OpenXRIPBinding).
	if not ClassDB.class_exists("OpenXRIPBinding") and not ClassDB.class_exists("OpenXRInteractionProfile"):
		return error_internal("OpenXR binding classes unavailable")
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var am := _load_action_map(res[0])
	if am == null:
		return error_not_found("OpenXRActionMap")
	var action_name_r := require_string(params, "action")
	if action_name_r[1] != null:
		return action_name_r[1]
	var binding_path_r := require_string(params, "binding_path")
	if binding_path_r[1] != null:
		return binding_path_r[1]
	# e.g. /user/hand/left/input/trigger/value
	var profile_path: String = optional_string(params, "profile_path", "/interaction_profiles/oculus/touch_controller")
	# Resolve action resource from map
	var action_res: Resource = _find_action_in_map(am, action_name_r[0])
	if action_res == null:
		return error_not_found("Action '%s' in map - use openxr_add_action first" % action_name_r[0])
	# Find or create interaction profile
	var profile: Resource = _find_interaction_profile(am, profile_path)
	if profile == null and ClassDB.class_exists("OpenXRInteractionProfile"):
		profile = ClassDB.instantiate("OpenXRInteractionProfile")
		if "interaction_profile_path" in profile:
			profile.set("interaction_profile_path", profile_path)
		if am.has_method("add_interaction_profile"):
			am.call("add_interaction_profile", profile)
		elif "interaction_profiles" in am:
			var arr: Array = am.get("interaction_profiles")
			arr.append(profile)
			am.set("interaction_profiles", arr)
	if profile == null:
		return error_internal("Could not create/find interaction profile")
	# Create binding
	if ClassDB.class_exists("OpenXRIPBinding"):
		var binding: Resource = ClassDB.instantiate("OpenXRIPBinding")
		if "action" in binding:
			binding.set("action", action_res)
		if binding.has_method("add_path"):
			binding.call("add_path", binding_path_r[0])
		elif "paths" in binding:
			var paths: PackedStringArray = binding.get("paths")
			paths.append(binding_path_r[0])
			binding.set("paths", paths)
		elif "path" in binding:
			binding.set("path", binding_path_r[0])
		if profile.has_method("add_binding"):
			profile.call("add_binding", binding)
		elif "bindings" in profile:
			var binds: Array = profile.get("bindings")
			binds.append(binding)
			profile.set("bindings", binds)
	else:
		return error_internal("OpenXRIPBinding class missing")
	var err := ResourceSaver.save(am, res[0])
	if err != OK:
		return error_internal(error_string(err))
	return success({
		"action": action_name_r[0],
		"binding_path": binding_path_r[0],
		"profile_path": profile_path,
	})


func _find_action_in_map(am: Resource, action_name: String) -> Resource:
	if am.has_method("get_action_set_count"):
		for i in am.call("get_action_set_count"):
			var s: Resource = am.call("get_action_set", i)
			if s == null:
				continue
			if s.has_method("get_action_count"):
				for j in s.call("get_action_count"):
					var a: Resource = s.call("get_action", j)
					if a and str(a.get("name")) == action_name:
						return a
			elif "actions" in s:
				for a in s.get("actions"):
					if a is Resource and str(a.get("name")) == action_name:
						return a
	elif "action_sets" in am:
		for s in am.get("action_sets"):
			if s is Resource and "actions" in s:
				for a in s.get("actions"):
					if a is Resource and str(a.get("name")) == action_name:
						return a
	return null


func _find_interaction_profile(am: Resource, profile_path: String) -> Resource:
	if am.has_method("get_interaction_profile_count"):
		for i in am.call("get_interaction_profile_count"):
			var p: Resource = am.call("get_interaction_profile", i)
			if p == null:
				continue
			var pp := str(p.get("interaction_profile_path")) if "interaction_profile_path" in p else str(p.get("profile_path", ""))
			if pp == profile_path:
				return p
	elif "interaction_profiles" in am:
		for p in am.get("interaction_profiles"):
			if p is Resource:
				var pp2 := str(p.get("interaction_profile_path")) if "interaction_profile_path" in p else ""
				if pp2 == profile_path:
					return p
	return null


func _openxr_create_default_controller_bindings(params: Dictionary) -> Dictionary:
	## Scaffold a usable action map: set + pose/trigger/grip/menu + oculus-style bindings.
	var path: String = optional_string(params, "path", "res://openxr_action_map.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	# Create map if missing
	if not ResourceLoader.exists(path):
		var cr := _create_openxr_action_map({
			"path": path,
			"action_set": optional_string(params, "action_set", "godot"),
			"set_as_default": optional_bool(params, "set_as_default", true),
		})
		if cr.has("error"):
			return cr
	var set_name: String = optional_string(params, "action_set", "godot")
	var actions := [
		{"name": "aim_pose", "action_type": "pose"},
		{"name": "grip_pose", "action_type": "pose"},
		{"name": "trigger", "action_type": "float"},
		{"name": "grip", "action_type": "float"},
		{"name": "menu_button", "action_type": "boolean"},
		{"name": "ax_button", "action_type": "boolean"},
		{"name": "by_button", "action_type": "boolean"},
	]
	var created: Array = []
	for a in actions:
		var r := _openxr_add_action({
			"path": path,
			"action_set": set_name,
			"name": a["name"],
			"action_type": a["action_type"],
		})
		# Ignore "already exists" style failures - still list
		created.append({"action": a["name"], "ok": not r.has("error")})
	var profile_path: String = optional_string(
		params, "profile_path",
		"/interaction_profiles/oculus/touch_controller"
	)
	_openxr_add_interaction_profile({"path": path, "profile_path": profile_path})
	# Left / right bindings for common paths
	var binds := [
		{"action": "aim_pose", "binding_path": "/user/hand/left/input/aim/pose"},
		{"action": "aim_pose", "binding_path": "/user/hand/right/input/aim/pose"},
		{"action": "grip_pose", "binding_path": "/user/hand/left/input/grip/pose"},
		{"action": "grip_pose", "binding_path": "/user/hand/right/input/grip/pose"},
		{"action": "trigger", "binding_path": "/user/hand/left/input/trigger/value"},
		{"action": "trigger", "binding_path": "/user/hand/right/input/trigger/value"},
		{"action": "grip", "binding_path": "/user/hand/left/input/squeeze/value"},
		{"action": "grip", "binding_path": "/user/hand/right/input/squeeze/value"},
		{"action": "menu_button", "binding_path": "/user/hand/left/input/menu/click"},
		{"action": "menu_button", "binding_path": "/user/hand/right/input/menu/click"},
		{"action": "ax_button", "binding_path": "/user/hand/left/input/x/click"},
		{"action": "ax_button", "binding_path": "/user/hand/right/input/a/click"},
		{"action": "by_button", "binding_path": "/user/hand/left/input/y/click"},
		{"action": "by_button", "binding_path": "/user/hand/right/input/b/click"},
	]
	var bound: Array = []
	for b in binds:
		var br := _openxr_bind_action({
			"path": path,
			"action": b["action"],
			"binding_path": b["binding_path"],
			"profile_path": profile_path,
		})
		bound.append({"binding": b["binding_path"], "ok": not br.has("error")})
	return success({
		"path": path,
		"action_set": set_name,
		"profile_path": profile_path,
		"actions": created,
		"bindings": bound,
		"set_as_default": optional_bool(params, "set_as_default", true),
		"hint": "Verify bindings in Project Settings > XR > OpenXR; device-specific paths may need tuning.",
	})
