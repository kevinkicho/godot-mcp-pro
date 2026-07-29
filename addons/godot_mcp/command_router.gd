@tool
extends Node

var editor_plugin: EditorPlugin

var _command_handlers: Dictionary = {}  # method_name -> Callable
var _disabled_tools: Dictionary = {}  # method_name -> true
var _loaded_modules: Array = []  # module basenames for diagnostics

const TOOL_CONFIG_PATH := "user://mcp_tool_config.cfg"
const COMMANDS_DIR := "res://addons/godot_mcp/commands"


func _ready() -> void:
	_load_tool_config()
	_register_commands()


func _register_commands() -> void:
	## Auto-discover commands/*_commands.gd (skip base_command and non-modules).
	_command_handlers.clear()
	_loaded_modules.clear()
	var scripts: Array = _discover_command_scripts()
	var registered := 0
	var modules := 0
	for path in scripts:
		var scr: GDScript = load(path) as GDScript
		if scr == null:
			push_warning("[MCP] Failed to load command module: %s" % path)
			continue
		var cmd: Node = scr.new()
		if cmd == null:
			continue
		if not cmd.has_method("get_commands"):
			cmd.free()
			continue
		cmd.editor_plugin = editor_plugin
		add_child(cmd)
		var methods: Dictionary = cmd.get_commands()
		if methods.is_empty():
			# Still keep node if it registered nothing (rare); free to avoid clutter
			remove_child(cmd)
			cmd.free()
			continue
		modules += 1
		_loaded_modules.append(path.get_file().get_basename())
		for method_name: String in methods:
			if _command_handlers.has(method_name):
				push_warning("[MCP] Duplicate command '%s' from %s (overwriting)" % [method_name, path.get_file()])
			_command_handlers[method_name] = methods[method_name]
			registered += 1

	print("[MCP] Registered %d commands from %d modules (auto-discover)" % [registered, modules])


func _discover_command_scripts() -> Array:
	var paths: Array = []
	var dir := DirAccess.open(COMMANDS_DIR)
	if dir == null:
		push_error("[MCP] Cannot open commands dir: %s" % COMMANDS_DIR)
		return paths
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with("_commands.gd"):
			# Exclude base if ever named that way; only *_commands.gd match
			paths.append(COMMANDS_DIR.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func get_loaded_modules() -> Array:
	return _loaded_modules.duplicate()


## Serialize all command execution so file-IPC game tools cannot race on the
## single mcp_game_request / mcp_input_commands files.
var _exec_busy: bool = false
var _exec_queue: Array = []  # reserved


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
	for key in cfg.get_section_keys("disabled_tools"):
		if bool(cfg.get_value("disabled_tools", key, false)):
			_disabled_tools[key] = true


func _save_tool_config() -> void:
	var cfg := ConfigFile.new()
	for method: String in _disabled_tools:
		cfg.set_value("disabled_tools", method, true)
	cfg.save(TOOL_CONFIG_PATH)
