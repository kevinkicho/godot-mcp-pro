@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## ClassDB example snippets - generate agent-usable usage patterns from ClassDB metadata.


func get_commands() -> Dictionary:
	return {
		"get_class_usage_examples": _get_examples,
		"list_instantiateable_classes": _list_instantiateable,
		"suggest_class_for_task": _suggest_for_task,
		"list_classdb_examples_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["describe_class", "list_class_methods", "list_class_properties", "add_node"],
	})


func _get_examples(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "class_name")
	if r0[1] != null:
		return r0[1]
	var cname: String = r0[0]
	if not ClassDB.class_exists(cname):
		return error_not_found("Class '%s'" % cname)
	var can_inst := ClassDB.can_instantiate(cname)
	var methods: Array = []
	for m in ClassDB.class_get_method_list(cname, true):
		methods.append(str(m.get("name", "")))
	var props: Array = []
	for p in ClassDB.class_get_property_list(cname, true):
		var pn: String = str(p.get("name", ""))
		if pn.is_empty() or pn.begins_with("_"):
			continue
		props.append(pn)
	var parent := ClassDB.get_parent_class(cname)
	var examples: Array = []
	if can_inst:
		examples.append({
			"title": "Instantiate",
			"gdscript": "var n = %s.new()\nadd_child(n)" % cname,
			"mcp": "add_node type=%s parent_path=." % cname,
		})
	if cname.ends_with("2D") or cname.ends_with("3D") or cname in ["Node", "Node2D", "Node3D", "Control"]:
		examples.append({
			"title": "Add via MCP",
			"mcp": "add_node parent_path=. type=%s name=My%s" % [cname, cname],
		})
	if "position" in props:
		examples.append({
			"title": "Set position",
			"gdscript": "node.position = Vector2(0, 0) # or Vector3",
			"mcp": "update_property node_path=... property=position value={x:0,y:0}",
		})
	# Method call examples for first few non-virtual methods
	var shown := 0
	for m in methods:
		if str(m).begins_with("_") or str(m) in ["get", "set", "call", "emit_signal"]:
			continue
		examples.append({
			"title": "Call %s" % m,
			"gdscript": "node.%s()" % m,
			"mcp": "call_node_method node_path=... method=%s" % m,
		})
		shown += 1
		if shown >= 5:
			break
	examples.append({
		"title": "Inspect",
		"mcp": "describe_class class_name=%s; list_class_properties class_name=%s" % [cname, cname],
	})
	return success({
		"class_name": cname,
		"parent": parent,
		"can_instantiate": can_inst,
		"is_node": ClassDB.is_parent_class(cname, "Node"),
		"method_count": methods.size(),
		"property_count": props.size(),
		"examples": examples,
		"docs": "https://docs.godotengine.org/en/stable/classes/class_%s.html" % cname.to_lower(),
	})


func _list_instantiateable(params: Dictionary) -> Dictionary:
	var base: String = optional_string(params, "base_class", "Node")
	var limit: int = optional_int(params, "limit", 100)
	var out: Array = []
	for c in ClassDB.get_class_list():
		var cn := str(c)
		if not ClassDB.can_instantiate(cn):
			continue
		if not base.is_empty() and not ClassDB.is_parent_class(cn, base) and cn != base:
			continue
		out.append(cn)
		if out.size() >= limit:
			break
	out.sort()
	return success({"base_class": base, "classes": out, "count": out.size(), "truncated": out.size() >= limit})


func _suggest_for_task(params: Dictionary) -> Dictionary:
	var task: String = optional_string(params, "task", "").to_lower()
	if task.is_empty():
		return error_invalid_params("task required e.g. '2d player' 'save file' 'button'")
	var suggestions: Array = []
	var map := {
		"player": ["CharacterBody2D", "CharacterBody3D", "AnimationPlayer"],
		"enemy": ["CharacterBody2D", "NavigationAgent2D", "Area2D"],
		"button": ["Button", "TextureButton", "TouchScreenButton"],
		"label": ["Label", "RichTextLabel"],
		"tile": ["TileMapLayer", "TileSet"],
		"camera": ["Camera2D", "Camera3D", "XRCamera3D"],
		"light": ["PointLight2D", "DirectionalLight3D", "OmniLight3D"],
		"audio": ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"],
		"save": ["FileAccess", "ConfigFile", "ResourceSaver"],
		"network": ["MultiplayerSpawner", "MultiplayerSynchronizer", "HTTPRequest"],
		"ui": ["Control", "CanvasLayer", "Panel", "VBoxContainer"],
		"physics": ["RigidBody2D", "RigidBody3D", "StaticBody2D", "Area2D"],
		"particle": ["GPUParticles2D", "GPUParticles3D", "CPUParticles2D"],
		"xr": ["XROrigin3D", "XRController3D", "XRCamera3D"],
		"path": ["Path2D", "Path3D", "PathFollow2D", "PathFollow3D"],
		"nav": ["NavigationRegion2D", "NavigationAgent2D", "NavigationRegion3D"],
	}
	for k in map:
		if task.contains(k):
			for c in map[k]:
				suggestions.append({"class_name": c, "reason": "matched keyword '%s'" % k})
	if suggestions.is_empty():
		suggestions.append({"class_name": "Node2D", "reason": "default 2D container"})
		suggestions.append({"class_name": "Node3D", "reason": "default 3D container"})
		suggestions.append({"class_name": "Control", "reason": "default UI root"})
	return success({"task": task, "suggestions": suggestions, "hint": "get_class_usage_examples class_name=..."})
