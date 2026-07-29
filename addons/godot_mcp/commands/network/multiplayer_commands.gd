@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Networking / multiplayer - tutorials/networking

const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")


func get_commands() -> Dictionary:
	return {
		"setup_multiplayer_spawner": _setup_multiplayer_spawner,
		"setup_multiplayer_synchronizer": _setup_multiplayer_synchronizer,
		"get_multiplayer_info": _get_multiplayer_info,
		"set_multiplayer_authority": _set_multiplayer_authority,
		"add_spawnable_scene": _add_spawnable_scene,
		"add_replication_property": _add_replication_property,
		"create_multiplayer_template_script": _create_multiplayer_template_script,
		"set_multiplayer_project_settings": _set_multiplayer_project_settings,
		"setup_http_request": _setup_http_request,
		"list_rpc_config": _list_rpc_config,
	}


func _setup_multiplayer_spawner(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var name: String = optional_string(params, "name", "MultiplayerSpawner")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	if not ClassDB.class_exists("MultiplayerSpawner"):
		return error_internal("MultiplayerSpawner not available in this Godot build")
	var spawner: Node = ClassDB.instantiate("MultiplayerSpawner")
	spawner.name = name
	var spawn_path: String = optional_string(params, "spawn_path", "..")
	if "spawn_path" in spawner:
		spawner.set("spawn_path", NodePath(spawn_path))
	# Optional scene list
	if params.has("spawnable_scenes") and params["spawnable_scenes"] is Array:
		for sc in params["spawnable_scenes"]:
			var p := str(sc)
			if not p.begins_with("res://"):
				p = "res://" + p
			if spawner.has_method("add_spawnable_scene"):
				spawner.call("add_spawnable_scene", p)
	add_child_with_undo(parent, spawner, root, "MCP: Add MultiplayerSpawner")
	NodeUtils.set_owner_recursive(spawner, root)
	return success({
		"node_path": str(root.get_path_to(spawner)),
		"type": "MultiplayerSpawner",
	})


func _setup_multiplayer_synchronizer(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var name: String = optional_string(params, "name", "MultiplayerSynchronizer")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	if not ClassDB.class_exists("MultiplayerSynchronizer"):
		return error_internal("MultiplayerSynchronizer not available")
	var sync: Node = ClassDB.instantiate("MultiplayerSynchronizer")
	sync.name = name
	var root_path: String = optional_string(params, "root_path", "..")
	if "root_path" in sync:
		sync.set("root_path", NodePath(root_path))
	add_child_with_undo(parent, sync, root, "MCP: Add MultiplayerSynchronizer")
	return success({
		"node_path": str(root.get_path_to(sync)),
		"type": "MultiplayerSynchronizer",
		"hint": "Configure replication config in inspector or via update_property on the synchronizer",
	})


func _get_multiplayer_info(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	var nodes: Array = []
	if root:
		_find_mp(root, root, nodes)
	return success({
		"multiplayer_nodes": nodes,
		"has_multiplayer_api": Engine.has_singleton("MultiplayerAPI") or ClassDB.class_exists("MultiplayerAPI"),
	})


func _find_mp(node: Node, root: Node, out: Array) -> void:
	var cname := node.get_class()
	if cname in ["MultiplayerSpawner", "MultiplayerSynchronizer", "MultiplayerPeer"]:
		out.append({"path": str(root.get_path_to(node)), "type": cname})
	for ch in node.get_children():
		_find_mp(ch, root, out)


func _set_multiplayer_authority(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var peer_id: int = optional_int(params, "peer_id", 1)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(result[0])
	if node == null:
		return error_not_found("Node '%s'" % result[0])
	node.set_multiplayer_authority(peer_id)
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"peer_id": peer_id,
		"authority": node.get_multiplayer_authority(),
	})


func _add_spawnable_scene(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var scene_r := require_res_path(params, "scene_path")
	if scene_r[1] != null:
		return scene_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is MultiplayerSpawner:
		return error_not_found("MultiplayerSpawner at '%s'" % r0[0])
	var spawner: MultiplayerSpawner = node
	if spawner.has_method("add_spawnable_scene"):
		spawner.add_spawnable_scene(scene_r[0])
	else:
		return error_internal("add_spawnable_scene unavailable")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "scene_path": scene_r[0]})


func _add_replication_property(params: Dictionary) -> Dictionary:
	## Add a property path to MultiplayerSynchronizer replication config.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var prop_r := require_string(params, "property")
	if prop_r[1] != null:
		return prop_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is MultiplayerSynchronizer:
		return error_not_found("MultiplayerSynchronizer at '%s'" % r0[0])
	var sync: MultiplayerSynchronizer = node
	var config: SceneReplicationConfig = sync.replication_config
	if config == null:
		config = SceneReplicationConfig.new()
		sync.replication_config = config
	var path := NodePath(prop_r[0])
	if config.has_method("add_property"):
		config.add_property(path)
	else:
		return error_internal("SceneReplicationConfig.add_property unavailable")
	# Optional spawn / sync / watch flags (Godot 4.x)
	if params.has("spawn") and config.has_method("property_set_spawn"):
		config.property_set_spawn(path, bool(params["spawn"]))
	if params.has("sync") and config.has_method("property_set_sync"):
		config.property_set_sync(path, bool(params["sync"]))
	if params.has("watch") and config.has_method("property_set_watch"):
		config.property_set_watch(path, bool(params["watch"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "property": prop_r[0]})


func _create_multiplayer_template_script(params: Dictionary) -> Dictionary:
	## Write a project-neutral ENet host/join GDScript template under res://.
	var path: String = optional_string(params, "path", "res://scripts/multiplayer_enet.gd")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var port: int = optional_int(params, "port", 7777)
	var max_clients: int = optional_int(params, "max_clients", 8)
	var content := """extends Node
## Generated by Godot MCP - ENet multiplayer host/join template (project-neutral).

const DEFAULT_PORT := %d
const MAX_CLIENTS := %d

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected

func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_wire_signals()
	return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_wire_signals()
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func _wire_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()

@rpc("any_peer", "reliable")
func rpc_chat(message: String) -> void:
	print("[chat] ", multiplayer.get_remote_sender_id(), ": ", message)
""" % [port, max_clients]
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({
		"path": path,
		"port": port,
		"max_clients": max_clients,
		"hint": "Attach as autoload or child node; call host()/join(). Use @rpc methods for RPCs.",
	})


func _set_multiplayer_project_settings(params: Dictionary) -> Dictionary:
	## Common multiplayer-related ProjectSettings.
	var applied := {}
	if params.has("server_relay"):
		ProjectSettings.set_setting("network/limits/websocket_client/max_in_buffer_kb", int(params.get("ws_max_in_buffer_kb", 64)))
	if params.has("physics_jitter_fix"):
		ProjectSettings.set_setting("physics/common/physics_jitter_fix", float(params["physics_jitter_fix"]))
		applied["physics_jitter_fix"] = params["physics_jitter_fix"]
	if params.has("max_clients_hint"):
		applied["max_clients_hint"] = int(params["max_clients_hint"])
		applied["note"] = "Use create_multiplayer_template_script for ENet max_clients; ProjectSettings has few multiplayer knobs."
	# Offline multiplayer root path is scene-level; document multiplayer poll
	if params.has("multiplayer_poll"):
		# Not a standard project setting in all versions - skip if unknown
		pass
	ProjectSettings.save()
	return success({"applied": applied, "ok": true})


func _setup_http_request(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent '%s'" % parent_path)
	var http := HTTPRequest.new()
	http.name = optional_string(params, "name", "HTTPRequest")
	if params.has("timeout"):
		http.timeout = float(params["timeout"])
	if params.has("use_threads"):
		http.use_threads = bool(params["use_threads"])
	if params.has("download_file"):
		http.download_file = str(params["download_file"])
	add_child_with_undo(parent, http, root, "MCP: Add HTTPRequest")
	return success({"node_path": str(root.get_path_to(http)), "type": "HTTPRequest"})


func _list_rpc_config(params: Dictionary) -> Dictionary:
	## List methods annotated for multiplayer on a node's script (best-effort via script source).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node '%s'" % r0[0])
	var script: Script = node.get_script()
	if script == null:
		return success({"node_path": r0[0], "rpcs": [], "message": "No script attached"})
	var path := script.resource_path
	var rpcs: Array = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return success({"node_path": r0[0], "rpcs": [], "message": "Script has no res:// path"})
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return error_internal("Cannot read script")
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	var pending_rpc := ""
	for i in lines.size():
		var line: String = lines[i].strip_edges()
		if line.begins_with("@rpc"):
			pending_rpc = line
		elif pending_rpc != "" and line.begins_with("func "):
			var mname := line.trim_prefix("func ").split("(")[0].strip_edges()
			rpcs.append({"line": i + 1, "annotation": pending_rpc, "method": mname})
			pending_rpc = ""
	return success({"node_path": r0[0], "script": path, "rpcs": rpcs, "count": rpcs.size()})
