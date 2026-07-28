@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Internationalization — tutorials/i18n


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
