@tool
extends Node

var editor_plugin: EditorPlugin

var _command_handlers: Dictionary = {}  # method_name -> Callable
var _disabled_tools: Dictionary = {}  # method_name -> true

const TOOL_CONFIG_PATH := "user://mcp_tool_config.cfg"


func _ready() -> void:
	_load_tool_config()
	_register_commands()


func _register_commands() -> void:
	var command_classes := [
		preload("res://addons/godot_mcp/commands/project_commands.gd"),
		preload("res://addons/godot_mcp/commands/scene_commands.gd"),
		preload("res://addons/godot_mcp/commands/node_commands.gd"),
		preload("res://addons/godot_mcp/commands/script_commands.gd"),
		preload("res://addons/godot_mcp/commands/editor_commands.gd"),
		preload("res://addons/godot_mcp/commands/input_commands.gd"),
		preload("res://addons/godot_mcp/commands/runtime_commands.gd"),
		preload("res://addons/godot_mcp/commands/animation_commands.gd"),
		preload("res://addons/godot_mcp/commands/tilemap_commands.gd"),
		preload("res://addons/godot_mcp/commands/theme_commands.gd"),
		preload("res://addons/godot_mcp/commands/profiling_commands.gd"),
		preload("res://addons/godot_mcp/commands/batch_commands.gd"),
		preload("res://addons/godot_mcp/commands/shader_commands.gd"),
		preload("res://addons/godot_mcp/commands/export_commands.gd"),
		preload("res://addons/godot_mcp/commands/resource_commands.gd"),
		preload("res://addons/godot_mcp/commands/input_map_commands.gd"),
		preload("res://addons/godot_mcp/commands/scene_3d_commands.gd"),
		preload("res://addons/godot_mcp/commands/physics_commands.gd"),
		preload("res://addons/godot_mcp/commands/analysis_commands.gd"),
		preload("res://addons/godot_mcp/commands/animation_tree_commands.gd"),
		preload("res://addons/godot_mcp/commands/skeleton_commands.gd"),
		preload("res://addons/godot_mcp/commands/scene_2d_commands.gd"),
		preload("res://addons/godot_mcp/commands/io_commands.gd"),
		preload("res://addons/godot_mcp/commands/audio_commands.gd"),
		preload("res://addons/godot_mcp/commands/navigation_commands.gd"),
		preload("res://addons/godot_mcp/commands/particle_commands.gd"),
		preload("res://addons/godot_mcp/commands/test_commands.gd"),
		preload("res://addons/godot_mcp/commands/android_commands.gd"),
		preload("res://addons/godot_mcp/commands/compat_commands.gd"),
		preload("res://addons/godot_mcp/commands/agent_commands.gd"),
		preload("res://addons/godot_mcp/commands/class_commands.gd"),
		preload("res://addons/godot_mcp/commands/import_commands.gd"),
		preload("res://addons/godot_mcp/commands/filesystem_commands.gd"),
		preload("res://addons/godot_mcp/commands/i18n_commands.gd"),
		preload("res://addons/godot_mcp/commands/multiplayer_commands.gd"),
		preload("res://addons/godot_mcp/commands/tileset_commands.gd"),
		preload("res://addons/godot_mcp/commands/scene_unique_commands.gd"),
		preload("res://addons/godot_mcp/commands/xr_commands.gd"),
		preload("res://addons/godot_mcp/commands/ui_list_commands.gd"),
		preload("res://addons/godot_mcp/commands/debugger_commands.gd"),
		preload("res://addons/godot_mcp/commands/visual_shader_commands.gd"),
		preload("res://addons/godot_mcp/commands/csharp_commands.gd"),
		preload("res://addons/godot_mcp/commands/tween_commands.gd"),
		preload("res://addons/godot_mcp/commands/plugin_scaffold_commands.gd"),
		preload("res://addons/godot_mcp/commands/texture_commands.gd"),
		preload("res://addons/godot_mcp/commands/gdextension_commands.gd"),
		preload("res://addons/godot_mcp/commands/dialogue_commands.gd"),
		preload("res://addons/godot_mcp/commands/container_commands.gd"),
		preload("res://addons/godot_mcp/commands/scene_flow_commands.gd"),
		preload("res://addons/godot_mcp/commands/gameplay_template_commands.gd"),
		preload("res://addons/godot_mcp/commands/material_2d_commands.gd"),
		preload("res://addons/godot_mcp/commands/utility_node_commands.gd"),
		preload("res://addons/godot_mcp/commands/control_extra_commands.gd"),
		# Headless production macros (human IDE high-frequency actions)
		preload("res://addons/godot_mcp/commands/production_commands.gd"),
		# Modern game systems (controllers, AI, HUD, combat, render presets)
		preload("res://addons/godot_mcp/commands/character_system_commands.gd"),
		preload("res://addons/godot_mcp/commands/ai_system_commands.gd"),
		preload("res://addons/godot_mcp/commands/game_ui_system_commands.gd"),
		preload("res://addons/godot_mcp/commands/modern_render_commands.gd"),
	]

	for cmd_class in command_classes:
		var cmd: Node = cmd_class.new()
		cmd.editor_plugin = editor_plugin
		add_child(cmd)
		var methods: Dictionary = cmd.get_commands()
		for method_name: String in methods:
			_command_handlers[method_name] = methods[method_name]

	print("[MCP] Registered %d commands" % _command_handlers.size())


## Serialize all command execution so file-IPC game tools cannot race on the
## single mcp_game_request / mcp_input_commands files.
var _exec_busy: bool = false
var _exec_queue: Array = []  # Array of {method, params, resolve_placeholder not used — we await chain}


func execute(method: String, params: Dictionary) -> Dictionary:
	if not _command_handlers.has(method):
		return {
			"error": {
				"code": -32601,
				"message": "Method not found: %s" % method,
				"data": {"available_methods": _command_handlers.keys()}
			}
		}

	if _disabled_tools.has(method):
		return {
			"error": {
				"code": -32603,
				"message": "Tool '%s' is disabled in MCP Server settings" % method
			}
		}

	# Queue if another command is in-flight (await-based serial chain).
	while _exec_busy:
		await get_tree().process_frame

	_exec_busy = true
	var result: Dictionary = {}
	var handler: Callable = _command_handlers[method]
	result = await handler.call(params)
	_exec_busy = false
	return result


func get_available_methods() -> Array:
	return _command_handlers.keys()


func is_tool_disabled(method: String) -> bool:
	return _disabled_tools.has(method)


func set_tool_disabled(method: String, disabled: bool) -> void:
	if disabled:
		_disabled_tools[method] = true
	else:
		_disabled_tools.erase(method)
	_save_tool_config()


func set_all_tools_disabled(disabled: bool) -> void:
	if disabled:
		for method: String in _command_handlers:
			_disabled_tools[method] = true
	else:
		_disabled_tools.clear()
	_save_tool_config()


func _load_tool_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TOOL_CONFIG_PATH) != OK:
		return
	if not cfg.has_section("disabled_tools"):
		return
	for method: String in cfg.get_section_keys("disabled_tools"):
		if cfg.get_value("disabled_tools", method, false):
			_disabled_tools[method] = true


func _save_tool_config() -> void:
	var cfg := ConfigFile.new()
	for method: String in _disabled_tools:
		cfg.set_value("disabled_tools", method, true)
	cfg.save(TOOL_CONFIG_PATH)
