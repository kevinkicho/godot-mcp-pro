@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## i18n polish — open-scene extract, CSV locale tables, string wrap helpers.


func get_commands() -> Dictionary:
	return {
		"extract_strings_from_open_scene": _extract_strings_from_open_scene,
		"export_translation_csv": _export_translation_csv,
		"import_translation_csv": _import_translation_csv,
		"wrap_script_strings_with_tr": _wrap_script_strings_with_tr,
		"list_i18n_csv_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["extract_translatable_strings", "export_pot_template", "load_csv_translations", "set_locale"],
		"flow": [
			"extract_strings_from_open_scene",
			"export_translation_csv locales=[en,es,ja]",
			"import_translation_csv path=… then load_csv_translations",
		],
	})


func _extract_strings_from_open_scene(params: Dictionary) -> Dictionary:
	## Walk edited scene for Control text / placeholder / tooltip and Node names optionally.
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var include_names: bool = optional_bool(params, "include_node_names", false)
	var min_len: int = clampi(optional_int(params, "min_length", 2), 1, 50)
	var found: Dictionary = {}  # key -> sources
	_walk_ui(root, root, found, include_names, min_len)
	var out: Array = []
	for k in found:
		out.append({"key": k, "sources": found[k]})
	out.sort_custom(func(a, b): return str(a.get("key")) < str(b.get("key")))
	return success({
		"scene": root.scene_file_path,
		"count": out.size(),
		"strings": out,
		"hint": "export_translation_csv or export_pot_template with these keys",
	})


func _walk_ui(n: Node, root: Node, found: Dictionary, include_names: bool, min_len: int) -> void:
	var path := str(root.get_path_to(n))
	if n is Control:
		for prop in ["text", "placeholder_text", "tooltip_text"]:
			if prop in n:
				var v = n.get(prop)
				if v is String and str(v).strip_edges().length() >= min_len:
					_add(found, str(v).strip_edges(), path + ":" + prop)
		if n is Window or n is AcceptDialog:
			if "title" in n:
				var t = n.get("title")
				if t is String and str(t).length() >= min_len:
					_add(found, str(t), path + ":title")
		if n is RichTextLabel and "text" in n:
			pass  # already covered
	if n is Label3D and "text" in n:
		var lt = n.get("text")
		if lt is String and str(lt).length() >= min_len:
			_add(found, str(lt), path + ":text")
	if include_names and n.name.length() >= min_len and not str(n.name).begins_with("@"):
		_add(found, str(n.name), path + ":name")
	for c in n.get_children():
		_walk_ui(c, root, found, include_names, min_len)


func _add(found: Dictionary, key: String, source: String) -> void:
	if key.is_empty() or key.begins_with("res://"):
		return
	if not found.has(key):
		found[key] = []
	var srcs: Array = found[key]
	if srcs.size() < 8 and not (source in srcs):
		srcs.append(source)


func _export_translation_csv(params: Dictionary) -> Dictionary:
	## keys + locales → CSV (first column keys, then locale columns).
	var out_path: String = optional_string(params, "path", "res://locale/translations.csv")
	if not out_path.begins_with("res://"):
		out_path = "res://" + out_path.trim_prefix("/")
	var locales: Array = params.get("locales", ["en"])
	if locales is PackedStringArray:
		locales = Array(locales)
	if locales.is_empty():
		locales = ["en"]
	var keys: Array = []
	if params.has("strings") and params["strings"] is Array:
		for s in params["strings"]:
			if s is Dictionary:
				keys.append(str(s.get("key", s.get("msgid", ""))))
			else:
				keys.append(str(s))
	elif optional_bool(params, "from_open_scene", true) and get_edited_root():
		var ext := _extract_strings_from_open_scene(params)
		var er = ext.get("result", ext)
		if er is Dictionary:
			for item in er.get("strings", []):
				if item is Dictionary:
					keys.append(str(item.get("key", "")))
	elif optional_bool(params, "from_project_scan", false):
		var router = get_parent()
		if router and router.has_method("execute"):
			var r = await router.execute("extract_translatable_strings", {
				"path": optional_string(params, "scan_path", "res://"),
				"max_files": optional_int(params, "max_files", 200),
			})
			var rr = r.get("result", r)
			if rr is Dictionary:
				for item in rr.get("strings", []):
					if item is Dictionary:
						keys.append(str(item.get("key", "")))
	# Existing translations fill
	var existing: Dictionary = {}  # locale -> {key: text}
	if params.has("fill_from_translation_server") and bool(params["fill_from_translation_server"]):
		pass
	var derr := ensure_parent_dir(out_path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % out_path)
	# Header
	var header := PackedStringArray(["keys"])
	for loc in locales:
		header.append(str(loc))
	f.store_csv_line(header)
	var seen := {}
	var n := 0
	for k in keys:
		var key := str(k)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		var row := PackedStringArray([key])
		for loc in locales:
			# default: first locale gets key as source text, others empty
			if str(loc) == str(locales[0]):
				row.append(key)
			else:
				row.append("")
		f.store_csv_line(row)
		n += 1
	f.close()
	EditorInterface.get_resource_filesystem().update_file(out_path)
	return success({
		"path": out_path,
		"entries": n,
		"locales": locales,
		"hint": "Translate empty columns, then import_translation_csv or load_csv_translations",
	})


func _import_translation_csv(params: Dictionary) -> Dictionary:
	## Read CSV and create Translation resources + optional project registration.
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var path: String = path_r[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot read CSV")
	var header := f.get_csv_line()
	if header.size() < 2:
		return error_invalid_params("CSV needs keys + at least one locale column")
	var locales: Array = []
	for i in range(1, header.size()):
		locales.append(str(header[i]))
	var tables: Dictionary = {}  # locale -> Translation
	for loc in locales:
		var tr := Translation.new()
		tr.locale = str(loc)
		tables[str(loc)] = tr
	var count := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2:
			continue
		var key := str(row[0])
		if key.is_empty() or key == "keys":
			continue
		for i in range(1, mini(row.size(), header.size())):
			var loc := str(header[i])
			var val := str(row[i])
			if val.is_empty():
				continue
			(tables[loc] as Translation).add_message(key, val)
			count += 1
	f.close()
	var out_dir: String = optional_string(params, "output_dir", path.get_base_dir())
	var saved: Array = []
	for loc in tables:
		var tr: Translation = tables[loc]
		var op := out_dir.rstrip("/") + "/translation_%s.tres" % loc
		if not op.begins_with("res://"):
			op = "res://" + op.trim_prefix("/")
		ensure_parent_dir(op)
		var err := ResourceSaver.save(tr, op)
		if err == OK:
			saved.append(op)
			if optional_bool(params, "register", true):
				var tlist: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
				if not (op in tlist):
					tlist.append(op)
					ProjectSettings.set_setting("internationalization/locale/translations", tlist)
			TranslationServer.add_translation(tr)
	if optional_bool(params, "register", true):
		ProjectSettings.save()
	EditorInterface.get_resource_filesystem().scan()
	return success({"saved": saved, "message_pairs": count, "locales": locales})


func _wrap_script_strings_with_tr(params: Dictionary) -> Dictionary:
	## Best-effort: replace Label text assignments "Foo" with tr("Foo") in a script (dry_run default).
	var path_r := require_res_path(params, "path")
	if path_r[1] != null:
		return path_r[1]
	var path: String = path_r[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var dry: bool = optional_bool(params, "dry_run", true)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("read failed")
	var text := f.get_as_text()
	f.close()
	var re := RegEx.new()
	# text = "Something" or .text = "Something" not already tr(
	re.compile("(\\.(?:text|placeholder_text|tooltip_text)\\s*=\\s*)\"([^\"]{2,})\"")
	var matches := re.search_all(text)
	var replacements: Array = []
	var new_text := text
	# Replace from end to preserve indices
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var prefix := m.get_string(1)
		var s := m.get_string(2)
		if s.begins_with("res://"):
			continue
		var full := m.get_string(0)
		var repl := "%str(\"%s\")" % [prefix, s.replace("\"", "\\\"")]
		# skip if already tr(
		var start := m.get_start()
		if start > 3 and text.substr(maxi(0, start - 3), 3) == "tr(":
			continue
		replacements.append({"from": full, "to": repl, "string": s})
		new_text = new_text.substr(0, m.get_start()) + repl + new_text.substr(m.get_end())
	if dry:
		return success({"dry_run": true, "would_replace": replacements.size(), "samples": replacements.slice(0, mini(10, replacements.size()))})
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		return error_internal("write failed")
	w.store_string(new_text)
	w.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"dry_run": false, "replaced": replacements.size(), "path": path})
