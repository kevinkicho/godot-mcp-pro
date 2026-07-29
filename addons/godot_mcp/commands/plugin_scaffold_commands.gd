@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Scaffold a basic EditorPlugin under res://addons/<name>/.


func get_commands() -> Dictionary:
	return {
		"create_editor_plugin": _create_editor_plugin,
		"list_project_plugins": _list_project_plugins,
	}


func _list_project_plugins(_params: Dictionary) -> Dictionary:
	var plugins: Array = []
	var dir := DirAccess.open("res://addons")
	if dir == null:
		return success({"plugins": [], "count": 0})
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if dir.current_is_dir() and not name.begins_with("."):
			var cfg_path := "res://addons/%s/plugin.cfg" % name
			if FileAccess.file_exists(cfg_path):
				var cfg := ConfigFile.new()
				cfg.load(cfg_path)
				plugins.append({
					"folder": name,
					"name": cfg.get_value("plugin", "name", name),
					"version": cfg.get_value("plugin", "version", ""),
					"description": cfg.get_value("plugin", "description", ""),
					"script": cfg.get_value("plugin", "script", ""),
					"cfg": cfg_path,
				})
		name = dir.get_next()
	dir.list_dir_end()
	return success({"plugins": plugins, "count": plugins.size()})


func _create_editor_plugin(params: Dictionary) -> Dictionary:
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var folder: String = optional_string(params, "folder", "")
	if folder.is_empty():
		folder = str(name_r[0]).to_lower().replace(" ", "_").validate_filename()
	var base := "res://addons/%s" % folder
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)) and not optional_bool(params, "overwrite", false):
		# DirAccess.dir_exists for res
		var d := DirAccess.open("res://addons")
		if d and d.dir_exists(folder) and not optional_bool(params, "overwrite", false):
			return error(-32000, "Addon folder exists: %s" % base, {"suggestion": "overwrite=true or different folder"})
	var display_name: String = optional_string(params, "display_name", name_r[0])
	var description: String = optional_string(params, "description", "Editor plugin scaffolded by Godot MCP")
	var author: String = optional_string(params, "author", "mcp")
	var version: String = optional_string(params, "version", "0.1.0")
	var with_dock: bool = optional_bool(params, "with_dock", true)
	# Ensure dirs
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var cfg := """[plugin]

name="%s"
description="%s"
author="%s"
version="%s"
script="plugin.gd"
""" % [display_name, description, author, version]
	_write_raw(base + "/plugin.cfg", cfg)
	var plugin_gd := """@tool
extends EditorPlugin

const PLUGIN_NAME := "%s"
""" % display_name
	if with_dock:
		plugin_gd += """
var _dock: Control

func _enter_tree() -> void:
	_dock = preload("res://addons/%s/dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
""" % folder
	else:
		plugin_gd += """
func _enter_tree() -> void:
	print("[", PLUGIN_NAME, "] enabled")

func _exit_tree() -> void:
	print("[", PLUGIN_NAME, "] disabled")
"""
	_write_raw(base + "/plugin.gd", plugin_gd)
	var files: Array = [base + "/plugin.cfg", base + "/plugin.gd"]
	if with_dock:
		var dock_gd := """@tool
extends VBoxContainer

func _ready() -> void:
	var label := Label.new()
	label.text = "%s dock"
	add_child(label)
""" % display_name
		_write_raw(base + "/dock.gd", dock_gd)
		# Minimal tscn
		var tscn := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/%s/dock.gd" id="1"]

[node name="Dock" type="VBoxContainer"]
script = ExtResource("1")
""" % folder
		_write_raw(base + "/dock.tscn", tscn)
		files.append(base + "/dock.gd")
		files.append(base + "/dock.tscn")
	EditorInterface.get_resource_filesystem().scan()
	return success({
		"folder": base,
		"files": files,
		"with_dock": with_dock,
		"hint": "Project > Project Settings > Plugins — enable '%s'. Or add to [editor_plugins] enabled list." % display_name,
	})


func _write_raw(path: String, content: String) -> void:
	## Scaffold always overwrites template files.
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()
