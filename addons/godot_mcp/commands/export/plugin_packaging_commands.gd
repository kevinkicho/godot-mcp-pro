@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Editor plugin packaging helpers — zip addon folder, plugin.cfg validate.


func get_commands() -> Dictionary:
	return {
		"validate_editor_plugin_cfg": _validate_cfg,
		"list_addon_folders": _list_addons,
		"package_addon_folder": _package_addon,
		"create_plugin_readme": _create_readme,
		"list_plugin_packaging_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["create_editor_plugin", "list_project_plugins", "create_gdextension_project"],
	})


func _list_addons(_params: Dictionary) -> Dictionary:
	var addons: Array = []
	var da := DirAccess.open(ProjectSettings.globalize_path("res://addons"))
	if da == null:
		return success({"addons": [], "count": 0})
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if da.current_is_dir() and not fn.begins_with("."):
			var cfg := "res://addons/%s/plugin.cfg" % fn
			addons.append({
				"folder": fn,
				"path": "res://addons/%s" % fn,
				"has_plugin_cfg": FileAccess.file_exists(ProjectSettings.globalize_path(cfg)),
				"plugin_cfg": cfg if FileAccess.file_exists(ProjectSettings.globalize_path(cfg)) else "",
			})
		fn = da.get_next()
	da.list_dir_end()
	return success({"addons": addons, "count": addons.size()})


func _validate_cfg(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		path = optional_string(params, "addon", "")
		if not path.is_empty() and not path.begins_with("res://"):
			path = "res://addons/%s/plugin.cfg" % path
	if path.is_empty():
		return error_invalid_params("path or addon required")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return error_internal("Cannot parse plugin.cfg")
	var issues: Array = []
	var name_v: String = str(cfg.get_value("plugin", "name", ""))
	var desc: String = str(cfg.get_value("plugin", "description", ""))
	var author: String = str(cfg.get_value("plugin", "author", ""))
	var version: String = str(cfg.get_value("plugin", "version", ""))
	var script: String = str(cfg.get_value("plugin", "script", ""))
	if name_v.is_empty():
		issues.append("missing plugin/name")
	if script.is_empty():
		issues.append("missing plugin/script")
	else:
		var script_path := path.get_base_dir().path_join(script)
		if not FileAccess.file_exists(script_path):
			issues.append("script file missing: %s" % script_path)
	return success({
		"path": path,
		"name": name_v,
		"description": desc,
		"author": author,
		"version": version,
		"script": script,
		"ok": issues.is_empty(),
		"issues": issues,
	})


func _package_addon(params: Dictionary) -> Dictionary:
	## Copy addon to a package folder (zip requires external tools — we stage a clean folder).
	var addon: String = optional_string(params, "addon", "")
	if addon.is_empty():
		return error_invalid_params("addon folder name under res://addons required")
	var src := "res://addons/%s" % addon
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(src)):
		return error_not_found(src)
	var dest: String = optional_string(params, "dest_dir", "res://build/addon_packages/%s" % addon)
	var vr := validate_res_path(dest if dest.begins_with("res://") else "res://" + dest)
	if vr[1] != null:
		# allow absolute via project build
		dest = ProjectSettings.globalize_path("res://build/addon_packages/%s" % addon)
	else:
		dest = ProjectSettings.globalize_path(vr[0])
	DirAccess.make_dir_recursive_absolute(dest)
	_copy_dir(ProjectSettings.globalize_path(src), dest)
	# Write package manifest
	var manifest := {
		"addon": addon,
		"packaged_at": Time.get_datetime_string_from_system(true, true),
		"source": src,
		"note": "Zip this folder for Asset Library / distribution: %s" % dest,
	}
	var mf := FileAccess.open(dest.path_join("PACKAGE_MANIFEST.json"), FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(manifest, "\t"))
		mf.close()
	return success({
		"addon": addon,
		"package_dir": dest,
		"hint": "Compress package_dir to .zip for distribution; validate_editor_plugin_cfg first",
	})


func _copy_dir(from_abs: String, to_abs: String) -> void:
	DirAccess.make_dir_recursive_absolute(to_abs)
	var da := DirAccess.open(from_abs)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn.begins_with("."):
			fn = da.get_next()
			continue
		var f_from := from_abs.path_join(fn)
		var f_to := to_abs.path_join(fn)
		if da.current_is_dir():
			_copy_dir(f_from, f_to)
		else:
			DirAccess.copy_absolute(f_from, f_to)
		fn = da.get_next()
	da.list_dir_end()


func _create_readme(params: Dictionary) -> Dictionary:
	var addon: String = optional_string(params, "addon", "")
	if addon.is_empty():
		return error_invalid_params("addon required")
	var path := "res://addons/%s/README.md" % addon
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var name_v := addon
	var cfg_path := "res://addons/%s/plugin.cfg" % addon
	if FileAccess.file_exists(cfg_path):
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			name_v = str(cfg.get_value("plugin", "name", addon))
	var content := """# %s

## Install

1. Copy this folder to `res://addons/%s`
2. Project > Project Settings > Plugins > Enable

## Develop with Godot MCP

- `validate_editor_plugin_cfg addon=%s`
- `package_addon_folder addon=%s`

## License

Add your license here.
""" % [name_v, addon, addon, addon]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("write failed")
	f.store_string(content)
	f.close()
	return success({"path": path})
