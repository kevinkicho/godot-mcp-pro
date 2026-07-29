@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Full ClassDB surface - covers official class-reference docs for every engine type.


func get_commands() -> Dictionary:
	return {
		"describe_class": _describe_class,
		"list_classes": _list_classes,
		"get_class_inheritance": _get_class_inheritance,
		"list_class_methods": _list_class_methods,
		"list_class_signals": _list_class_signals,
		"list_class_properties": _list_class_properties,
		"list_class_constants": _list_class_constants,
		"class_has_method": _class_has_method,
		"get_global_class_list": _get_global_class_list,
	}


func _describe_class(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		# Try global script class
		for entry in ProjectSettings.get_global_class_list():
			if str(entry.get("class", "")) == class_name_str:
				return success({
					"class_name": class_name_str,
					"kind": "global_script_class",
					"path": entry.get("path", ""),
					"base": entry.get("base", ""),
					"language": entry.get("language", ""),
				})
		return error_not_found("Class '%s'" % class_name_str, "Use list_classes to search")

	var parent := ClassDB.get_parent_class(class_name_str)
	var include_inherited: bool = optional_bool(params, "include_inherited", false)

	return success({
		"class_name": class_name_str,
		"kind": "engine_class",
		"parent": parent,
		"is_abstract": not ClassDB.can_instantiate(class_name_str),
		"can_instantiate": ClassDB.can_instantiate(class_name_str),
		"is_api_disabled": ClassDB.is_class_enabled(class_name_str) == false if ClassDB.has_method("is_class_enabled") else false,
		"inheritance": _inheritance_chain(class_name_str),
		"methods": _methods_of(class_name_str, include_inherited),
		"signals": _signals_of(class_name_str, include_inherited),
		"properties": _properties_of(class_name_str, include_inherited),
		"integer_constants": ClassDB.class_get_integer_constant_list(class_name_str, not include_inherited),
		"enum_list": ClassDB.class_get_enum_list(class_name_str, not include_inherited),
		"docs_hint": "https://docs.godotengine.org/en/stable/classes/class_%s.html" % class_name_str.to_lower(),
	})


func _list_classes(params: Dictionary) -> Dictionary:
	var filter: String = optional_string(params, "filter", "").to_lower()
	var parent_filter: String = optional_string(params, "parent", "")
	var instantiable_only: bool = optional_bool(params, "instantiable_only", false)
	var max_results: int = optional_int(params, "max_results", 200)

	var out: Array = []
	for c in ClassDB.get_class_list():
		var name_str := str(c)
		if not filter.is_empty() and not name_str.to_lower().contains(filter):
			continue
		if not parent_filter.is_empty() and not ClassDB.is_parent_class(name_str, parent_filter):
			continue
		if instantiable_only and not ClassDB.can_instantiate(name_str):
			continue
		out.append({
			"name": name_str,
			"parent": ClassDB.get_parent_class(name_str),
			"can_instantiate": ClassDB.can_instantiate(name_str),
		})
		if out.size() >= max_results:
			break

	return success({"classes": out, "count": out.size(), "truncated": out.size() >= max_results})


func _get_class_inheritance(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	return success({
		"class_name": class_name_str,
		"chain": _inheritance_chain(class_name_str),
		"children": ClassDB.get_inheriters_from_class(class_name_str),
	})


func _list_class_methods(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	var include_inherited: bool = optional_bool(params, "include_inherited", false)
	return success({
		"class_name": class_name_str,
		"methods": _methods_of(class_name_str, include_inherited),
	})


func _list_class_signals(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	var include_inherited: bool = optional_bool(params, "include_inherited", false)
	return success({
		"class_name": class_name_str,
		"signals": _signals_of(class_name_str, include_inherited),
	})


func _list_class_properties(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	var include_inherited: bool = optional_bool(params, "include_inherited", false)
	return success({
		"class_name": class_name_str,
		"properties": _properties_of(class_name_str, include_inherited),
	})


func _list_class_constants(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var class_name_str: String = result[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	var no_inheritance := not optional_bool(params, "include_inherited", false)
	var constants: Dictionary = {}
	for cname in ClassDB.class_get_integer_constant_list(class_name_str, no_inheritance):
		constants[str(cname)] = ClassDB.class_get_integer_constant(class_name_str, cname)
	var enums: Dictionary = {}
	for ename in ClassDB.class_get_enum_list(class_name_str, no_inheritance):
		var evalues: Dictionary = {}
		for vname in ClassDB.class_get_enum_constants(class_name_str, ename):
			evalues[str(vname)] = ClassDB.class_get_integer_constant(class_name_str, vname)
		enums[str(ename)] = evalues
	return success({"class_name": class_name_str, "constants": constants, "enums": enums})


func _class_has_method(params: Dictionary) -> Dictionary:
	var result := require_string(params, "class_name")
	if result[1] != null:
		return result[1]
	var result2 := require_string(params, "method")
	if result2[1] != null:
		return result2[1]
	var class_name_str: String = result[0]
	var method: String = result2[0]
	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s'" % class_name_str)
	return success({
		"class_name": class_name_str,
		"method": method,
		"has_method": ClassDB.class_has_method(class_name_str, method, true),
	})


func _get_global_class_list(_params: Dictionary) -> Dictionary:
	var classes: Array = []
	for entry in ProjectSettings.get_global_class_list():
		classes.append({
			"class": entry.get("class", ""),
			"path": entry.get("path", ""),
			"base": entry.get("base", ""),
			"language": entry.get("language", ""),
		})
	return success({"classes": classes, "count": classes.size()})


func _inheritance_chain(class_name_str: String) -> Array:
	var chain: Array = [class_name_str]
	var cur := class_name_str
	while true:
		var p := ClassDB.get_parent_class(cur)
		if p.is_empty() or p == cur:
			break
		chain.append(p)
		cur = p
	return chain


func _methods_of(class_name_str: String, include_inherited: bool) -> Array:
	var out: Array = []
	var no_inheritance := not include_inherited
	for m in ClassDB.class_get_method_list(class_name_str, no_inheritance):
		if not m is Dictionary:
			continue
		var args: Array = []
		for a in m.get("args", []):
			if a is Dictionary:
				args.append({
					"name": a.get("name", ""),
					"type": type_string(a.get("type", 0)),
					"class_name": str(a.get("class_name", "")),
				})
		out.append({
			"name": m.get("name", ""),
			"args": args,
			"return": {
				"type": type_string(m.get("return", {}).get("type", 0) if m.get("return") is Dictionary else 0),
			},
			"flags": m.get("flags", 0),
		})
	return out


func _signals_of(class_name_str: String, include_inherited: bool) -> Array:
	var out: Array = []
	var no_inheritance := not include_inherited
	for s in ClassDB.class_get_signal_list(class_name_str, no_inheritance):
		if not s is Dictionary:
			continue
		var args: Array = []
		for a in s.get("args", []):
			if a is Dictionary:
				args.append({"name": a.get("name", ""), "type": type_string(a.get("type", 0))})
		out.append({"name": s.get("name", ""), "args": args})
	return out


func _properties_of(class_name_str: String, include_inherited: bool) -> Array:
	var out: Array = []
	var no_inheritance := not include_inherited
	for p in ClassDB.class_get_property_list(class_name_str, no_inheritance):
		if not p is Dictionary:
			continue
		out.append({
			"name": p.get("name", ""),
			"type": type_string(p.get("type", 0)),
			"hint": p.get("hint", 0),
			"hint_string": p.get("hint_string", ""),
			"usage": p.get("usage", 0),
			"class_name": str(p.get("class_name", "")),
		})
	return out
