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
	# Defer: EditorFileSystem may not have finished scanning a freshly copied addon.
	# Immediate DirAccess can see only a subset of *_commands.gd files.
	_register_commands()
	call_deferred("_reregister_when_fs_ready")


func _reregister_when_fs_ready() -> void:
	## Second pass after one frame; third pass after filesystem scan if available.
	await get_tree().process_frame
	var before := _command_handlers.size()
	var discovered := _discover_command_scripts().size()
	if discovered > _loaded_modules.size() or before < 100:
		print("[MCP] Re-registering commands (handlers=%d modules=%d discovered_paths=%d)" % [
			before, _loaded_modules.size(), discovered
		])
		reload_commands({})
	# Hook filesystem if editor available
	if Engine.is_editor_hint() and editor_plugin:
		var fs := EditorInterface.get_resource_filesystem()
		if fs and not fs.filesystem_changed.is_connected(_on_filesystem_changed):
			fs.filesystem_changed.connect(_on_filesystem_changed)


var _fs_reregister_cooldown: float = 0.0


func _on_filesystem_changed() -> void:
	## After addon files import, ensure full module set is loaded (once).
	if _loaded_modules.size() >= 100:
		return
	var discovered := _discover_command_scripts().size()
	if discovered > _loaded_modules.size():
		print("[MCP] Filesystem changed — re-registering (%d paths > %d modules)" % [
			discovered, _loaded_modules.size()
		])
		reload_commands({})


## Force re-scan of command modules (after addon install/reload).
func reload_commands(params: Dictionary = {}) -> Dictionary:
	# Free previous module nodes (children of router)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_register_commands()
	return {
		"result": {
			"registered": _command_handlers.size(),
			"modules": _loaded_modules.size(),
			"domains": _domain_index.size(),
			"discovered_paths": _discover_command_scripts().size(),
		}
	}


func _register_commands() -> void:
	## Auto-discover commands/**/**_commands.gd (recursive domain folders).
	_command_handlers.clear()
	_command_source.clear()
	_loaded_modules.clear()
	_domain_index.clear()
	var scripts: Array = _discover_command_scripts()
	var registered := 0
	var modules := 0
	var failed: Array = []
	print("[MCP] Discovering command modules under %s (%d paths)" % [COMMANDS_DIR, scripts.size()])
	for path in scripts:
		var scr: GDScript = load(path) as GDScript
		if scr == null:
			push_warning("[MCP] Failed to load command module: %s" % path)
			failed.append({"path": path, "reason": "load_null"})
			continue
		var cmd: Node = null
		# Isolate instantiation failures so one bad module cannot stop registration.
		cmd = scr.new() as Node
		if cmd == null:
			push_warning("[MCP] Failed to instantiate: %s" % path)
			failed.append({"path": path, "reason": "instantiate_null"})
			continue
		if not cmd.has_method("get_commands"):
			cmd.free()
			failed.append({"path": path, "reason": "no_get_commands"})
			continue
		cmd.editor_plugin = editor_plugin
		add_child(cmd)
		var methods: Dictionary = {}
		methods = cmd.get_commands()
		if methods.is_empty():
			remove_child(cmd)
			cmd.free()
			failed.append({"path": path, "reason": "empty_commands"})
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

	print("[MCP] Registered %d commands from %d modules in %d domains (failed_modules=%d)" % [
		registered, modules, _domain_index.size(), failed.size()
	])
	if failed.size() > 0:
		push_warning("[MCP] Module load failures (first 20): %s" % str(failed.slice(0, mini(20, failed.size()))))
	# Built-in meta command always available for recovery
	_command_handlers["mcp_reload_commands"] = reload_commands
	_command_source["mcp_reload_commands"] = "command_router.gd"
	_command_handlers["mcp_registration_stats"] = _registration_stats
	_command_source["mcp_registration_stats"] = "command_router.gd"


func _registration_stats(_params: Dictionary = {}) -> Dictionary:
	return {
		"result": {
			"registered": _command_handlers.size(),
			"modules": _loaded_modules.size(),
			"domains": _domain_index.size(),
			"module_names": _loaded_modules.map(func(m): return m.get("name", "")),
		}
	}

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
