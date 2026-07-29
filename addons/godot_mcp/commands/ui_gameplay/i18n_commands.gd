@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Internationalization - tutorials/i18n


func get_commands() -> Dictionary:
	return {
		"get_locale": _get_locale,
		"set_locale": _set_locale,
		"get_translation_projects": _get_translation_projects,
		"add_translation": _add_translation,
		"remove_translation": _remove_translation,
		"translate_string": _translate_string,
		"load_csv_translations": _load_csv_translations,
		"load_po_translation": _load_po_translation,
		"list_translations": _list_translations,
		"extract_translatable_strings": _extract_translatable_strings,
		"export_pot_template": _export_pot_template,
	}


func _get_locale(_params: Dictionary) -> Dictionary:
	return success({
		"locale": TranslationServer.get_locale(),
		"fallback": TranslationServer.get_tool_locale() if TranslationServer.has_method("get_tool_locale") else "",
		"loaded_locales": TranslationServer.get_loaded_locales(),
	})


func _set_locale(params: Dictionary) -> Dictionary:
	var result := require_string(params, "locale")
	if result[1] != null:
		return result[1]
	var locale: String = result[0]
	TranslationServer.set_locale(locale)
	return success({"locale": TranslationServer.get_locale()})


func _get_translation_projects(_params: Dictionary) -> Dictionary:
	var translations: Array = []
	var tlist = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for t in tlist:
		translations.append(str(t))
	return success({
		"translations": translations,
		"fallback": ProjectSettings.get_setting("internationalization/locale/fallback", "en"),
		"test": ProjectSettings.get_setting("internationalization/locale/test", ""),
	})


func _add_translation(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var tlist: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	if path in tlist:
		return success({"path": path, "already_present": true})
	tlist.append(path)
	ProjectSettings.set_setting("internationalization/locale/translations", tlist)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal(error_string(err))
	# Load into TranslationServer if resource exists
	if ResourceLoader.exists(path):
		var tr = load(path)
		if tr is Translation:
			TranslationServer.add_translation(tr)
	return success({"path": path, "added": true})


func _remove_translation(params: Dictionary) -> Dictionary:
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	var tlist: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	var new_list := PackedStringArray()
	for t in tlist:
		if str(t) != path:
			new_list.append(t)
	ProjectSettings.set_setting("internationalization/locale/translations", new_list)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal(error_string(err))
	return success({"path": path, "removed": true})


func _translate_string(params: Dictionary) -> Dictionary:
	var result := require_string(params, "message")
	if result[1] != null:
		return result[1]
	var msg: String = result[0]
	var context: String = optional_string(params, "context", "")
	var translated: String
	if context.is_empty():
		translated = TranslationServer.translate(msg)
	else:
		translated = TranslationServer.translate(msg, context)
	return success({"message": msg, "translated": translated, "locale": TranslationServer.get_locale()})


func _load_csv_translations(params: Dictionary) -> Dictionary:
	## Load a simple CSV translation file: key,en,es,... first row headers
	var res_path := require_res_path(params, "path")
	if res_path[1] != null:
		return res_path[1]
	var path: String = res_path[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal(error_string(FileAccess.get_open_error()))
	var header := f.get_csv_line()
	if header.size() < 2:
		return error_invalid_params("CSV needs key column + at least one locale column")
	var locales: Array = []
	var translations: Dictionary = {}  # locale -> Translation
	for i in range(1, header.size()):
		var locale := str(header[i]).strip_edges()
		locales.append(locale)
		var tr := Translation.new()
		tr.locale = locale
		translations[locale] = tr
	var rows := 0
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 2 or str(line[0]).is_empty():
			continue
		var key := str(line[0])
		for i in range(1, mini(line.size(), header.size())):
			var locale := str(header[i]).strip_edges()
			if translations.has(locale):
				translations[locale].add_message(key, str(line[i]))
		rows += 1
	f.close()
	var save: bool = optional_bool(params, "register", true)
	var saved_paths: Array = []
	for locale in translations:
		var tr: Translation = translations[locale]
		TranslationServer.add_translation(tr)
		if save:
			var out_path := path.get_basename() + "." + locale + ".translation"
			# Binary translation resource
			var err := ResourceSaver.save(tr, out_path)
			if err == OK:
				saved_paths.append(out_path)
	return success({
		"path": path,
		"locales": locales,
		"rows": rows,
		"registered": true,
		"saved_paths": saved_paths,
	})


func _load_po_translation(params: Dictionary) -> Dictionary:
	## Load a .po file via TranslationLoader / ResourceLoader if imported, or parse minimally.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	# Prefer Godot's importer output
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Translation:
			TranslationServer.add_translation(loaded)
			return success({"path": path, "locale": (loaded as Translation).locale, "type": "Translation"})
	# Minimal gettext .po parse for msgid/msgstr pairs
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot open %s" % path)
	var locale: String = optional_string(params, "locale", "")
	var tr := Translation.new()
	var msgid := ""
	var msgstr := ""
	var in_id := false
	var in_str := false
	var count := 0
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("\"Language: ") and locale.is_empty():
			locale = line.trim_prefix("\"Language: ").split("\\n")[0].strip_edges().trim_suffix("\"")
		if line.begins_with("msgid "):
			if not msgid.is_empty() and not msgstr.is_empty():
				tr.add_message(msgid, msgstr)
				count += 1
			msgid = _po_unquote(line.trim_prefix("msgid ").strip_edges())
			msgstr = ""
			in_id = true
			in_str = false
		elif line.begins_with("msgstr "):
			msgstr = _po_unquote(line.trim_prefix("msgstr ").strip_edges())
			in_id = false
			in_str = true
		elif line.begins_with("\"") and (in_id or in_str):
			var part := _po_unquote(line.strip_edges())
			if in_id:
				msgid += part
			else:
				msgstr += part
	if not msgid.is_empty():
		tr.add_message(msgid, msgstr)
		count += 1
	f.close()
	if locale.is_empty():
		locale = path.get_file().get_basename()
	tr.locale = locale
	TranslationServer.add_translation(tr)
	if optional_bool(params, "save", false):
		var out := path.get_basename() + ".translation"
		ResourceSaver.save(tr, out)
	return success({"path": path, "locale": locale, "messages": count, "registered": true})


func _po_unquote(s: String) -> String:
	s = s.strip_edges()
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		s = s.substr(1, s.length() - 2)
	return s.replace("\\n", "\n").replace("\\\"", "\"").replace("\\t", "\t")


func _list_translations(_params: Dictionary) -> Dictionary:
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	return success({
		"current_locale": TranslationServer.get_locale(),
		"loaded_locales": Array(locales),
		"count": locales.size(),
	})


func _extract_translatable_strings(params: Dictionary) -> Dictionary:
	## Scan scenes/scripts for user-facing strings (tr(), text=, placeholder_text, bbcode).
	var root_path: String = optional_string(params, "path", "res://")
	if not root_path.begins_with("res://"):
		root_path = "res://" + root_path.trim_prefix("/")
	var max_files: int = clampi(optional_int(params, "max_files", 300), 1, 2000)
	var include_addons: bool = optional_bool(params, "include_addons", false)
	var keys: Dictionary = {}  # key -> {sources:[]}
	var files: Array = []
	_collect_files(root_path, files, max_files, include_addons)
	var tr_re := RegEx.new()
	tr_re.compile("tr\\(\\s*[\"']([^\"']+)[\"']")
	var text_re := RegEx.new()
	text_re.compile("(?:text|placeholder_text|tooltip_text|title|bbcode_text)\\s*=\\s*[\"']([^\"']{2,})[\"']")
	for fpath in files:
		var content := _read_text(fpath)
		if content.is_empty():
			continue
		for re in [tr_re, text_re]:
			for m in re.search_all(content):
				var s := m.get_string(1).strip_edges()
				if s.is_empty() or s.begins_with("res://") or s.is_valid_float():
					continue
				if not keys.has(s):
					keys[s] = {"key": s, "sources": []}
				var srcs: Array = keys[s]["sources"]
				if srcs.size() < 5 and not (fpath in srcs):
					srcs.append(fpath)
	var out: Array = []
	for k in keys:
		out.append(keys[k])
	out.sort_custom(func(a, b): return str(a.get("key", "")) < str(b.get("key", "")))
	return success({
		"count": out.size(),
		"strings": out,
		"scanned_files": files.size(),
		"hint": "export_pot_template or write CSV keys then load_csv_translations",
	})


func _export_pot_template(params: Dictionary) -> Dictionary:
	## Write a minimal gettext .pot from extract results or provided keys.
	var out_path: String = optional_string(params, "path", "res://locale/messages.pot")
	if not out_path.begins_with("res://"):
		out_path = "res://" + out_path.trim_prefix("/")
	var strings: Array = []
	if params.has("strings") and params["strings"] is Array:
		strings = params["strings"]
	else:
		var ext := _extract_translatable_strings(params)
		if ext.has("error"):
			return ext
		var res: Dictionary = ext.get("result", ext)
		for item in res.get("strings", []):
			if item is Dictionary:
				strings.append(item.get("key", ""))
			else:
				strings.append(str(item))
	var abs := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % out_path)
	f.store_line("# MCP-generated POT template")
	f.store_line("msgid \"\"")
	f.store_line("msgstr \"\"")
	f.store_line("\"Content-Type: text/plain; charset=UTF-8\\n\"")
	f.store_line("")
	var n := 0
	var seen := {}
	for s in strings:
		var key := str(s)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		var esc := key.replace("\\", "\\\\").replace("\"", "\\\"")
		f.store_line("msgid \"%s\"" % esc)
		f.store_line("msgstr \"\"")
		f.store_line("")
		n += 1
	f.close()
	EditorInterface.get_resource_filesystem().scan()
	return success({"path": out_path, "entries": n})


func _collect_files(dir_path: String, out: Array, max_n: int, include_addons: bool) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = dir_path.rstrip("/") + "/" + name if dir_path != "res://" else "res://" + name
		if dir.current_is_dir():
			if name == ".godot":
				pass
			elif name == "addons" and not include_addons:
				pass
			else:
				_collect_files(full, out, max_n, include_addons)
		elif name.ends_with(".gd") or name.ends_with(".tscn") or name.ends_with(".cs"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
