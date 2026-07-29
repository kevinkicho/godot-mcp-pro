@tool
extends Node

var editor_plugin: EditorPlugin

var _command_handlers: Dictionary = {}  # method_name -> Callable
var _command_source: Dictionary = {}  # method_name -> module path (res://)
var _disabled_tools: Dictionary = {}  # method_name -> true
var _loaded_modules: Array = []  # {name, path, domain, command_count}
var _domain_index: Dictionary = {}  # domain -> [module names]

const TOOL_CONFIG_PATH := "user://mcp_tool_config.cfg"
const COMMANDS_DIR := "res://addons/godot_mcp/commands"


func _ready() -> void:
	_load_tool_config()
	_register_commands()


func _register_commands() -> void:
	## Auto-discover commands/**/**_commands.gd (recursive domain folders).
	_command_handlers.clear()
	_command_source.clear()
	_loaded_modules.clear()
	_domain_index.clear()
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
			remove_child(cmd)
			cmd.free()
			continue
		modules += 1
		var base_name: String = path.get_file().get_basename()
		var domain: String = _domain_from_path(path)
		_loaded_modules.append({
			"name": base_name,
			"path": path,
			"domain": domain,
			"command_count": methods.size(),
		})
		if not _domain_index.has(domain):
			_domain_index[domain] = []
		(_domain_index[domain] as Array).append(base_name)
		for method_name: String in methods:
			if _command_handlers.has(method_name):
				push_warning("[MCP] Duplicate command '%s' from %s (overwriting %s)" % [
					method_name, path.get_file(), _command_source.get(method_name, "?")
				])
			_command_handlers[method_name] = methods[method_name]
			_command_source[method_name] = path
			registered += 1

	print("[MCP] Registered %d commands from %d modules in %d domains (recursive auto-discover)" % [
		registered, modules, _domain_index.size()
	])


func _domain_from_path(path: String) -> String:
	## res://addons/godot_mcp/commands/<domain>/foo_commands.gd → domain
	## res://addons/godot_mcp/commands/foo_commands.gd → "root"
	var rel := path.trim_prefix(COMMANDS_DIR).trim_prefix("/").trim_prefix("\\")
	if rel.contains("/"):
		return rel.get_slice("/", 0)
	if rel.contains("\\"):
		return rel.get_slice("\\", 0)
	return "root"


func _discover_command_scripts() -> Array:
	var paths: Array = []
	_discover_command_scripts_recursive(COMMANDS_DIR, paths)
	paths.sort()
	return paths


func _discover_command_scripts_recursive(dir_path: String, paths: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		if dir_path == COMMANDS_DIR:
			push_error("[MCP] Cannot open commands dir: %s" % COMMANDS_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.begins_with("."):
			fname = dir.get_next()
			continue
		var child := dir_path.path_join(fname)
		if dir.current_is_dir():
			_discover_command_scripts_recursive(child, paths)
		elif fname.ends_with("_commands.gd"):
			paths.append(child)
		fname = dir.get_next()
	dir.list_dir_end()


func get_loaded_modules() -> Array:
	return _loaded_modules.duplicate(true)


func get_command_domains() -> Dictionary:
	return _domain_index.duplicate(true)


func get_command_source(method: String) -> String:
	return str(_command_source.get(method, ""))


func get_modules_by_domain(domain: String = "") -> Dictionary:
	if domain.is_empty():
		return {
			"domains": _domain_index.keys(),
			"modules": _loaded_modules.duplicate(true),
			"domain_index": _domain_index.duplicate(true),
		}
	var list: Array = []
	for m in _loaded_modules:
		if str(m.get("domain", "")) == domain:
			list.append(m)
	return {"domain": domain, "modules": list, "count": list.size()}


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


func get_available_methods_detailed() -> Array:
	## method + source module path + domain for agent discovery.
	var out: Array = []
	for m in _command_handlers.keys():
		var src := str(_command_source.get(m, ""))
		out.append({
			"method": m,
			"module": src.get_file().get_basename() if not src.is_empty() else "",
			"path": src,
			"domain": _domain_from_path(src) if not src.is_empty() else "root",
		})
	out.sort_custom(func(a, b): return str(a.get("method")) < str(b.get("method")))
	return out


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
