@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## MultiplayerSynchronizer replication config bulk - biggest net multiplayer gain.


func get_commands() -> Dictionary:
	return {
		"configure_multiplayer_synchronizer": _configure_sync,
		"add_replication_properties_bulk": _add_props_bulk,
		"list_replication_config": _list_config,
		"set_rpc_config_on_node": _set_rpc,
		"list_multiplayer_sync_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_multiplayer_synchronizer", "add_replication_property", "setup_multiplayer_spawner", "pipeline_multiplayer_enet"],
	})


func _find_sync(path: String) -> MultiplayerSynchronizer:
	var n := find_node_by_path(path)
	if n is MultiplayerSynchronizer:
		return n as MultiplayerSynchronizer
	return null


func _configure_sync(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sync := _find_sync(r0[0])
	if sync == null:
		return error_not_found("MultiplayerSynchronizer")
	var applied := {}
	if params.has("root_path"):
		sync.root_path = NodePath(str(params["root_path"]))
		applied["root_path"] = str(sync.root_path)
	if params.has("replication_interval"):
		sync.replication_interval = float(params["replication_interval"])
		applied["replication_interval"] = sync.replication_interval
	if params.has("delta_interval"):
		sync.delta_interval = float(params["delta_interval"])
		applied["delta_interval"] = sync.delta_interval
	if params.has("visibility_update_mode"):
		sync.visibility_update_mode = int(params["visibility_update_mode"]) as MultiplayerSynchronizer.VisibilityUpdateMode
		applied["visibility_update_mode"] = sync.visibility_update_mode
	if params.has("public_visibility"):
		sync.public_visibility = bool(params["public_visibility"])
		applied["public_visibility"] = sync.public_visibility
	if params.has("properties") and params["properties"] is Array:
		var bulk := _add_props_bulk({
			"node_path": r0[0],
			"properties": params["properties"],
			"clear_existing": optional_bool(params, "clear_existing", false),
		})
		applied["properties_result"] = bulk.get("result", bulk)
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "applied": applied})


func _add_props_bulk(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sync := _find_sync(r0[0])
	if sync == null:
		return error_not_found("MultiplayerSynchronizer")
	if not params.has("properties") or not (params["properties"] is Array):
		return error_invalid_params("properties array required - [\"position\", \"velocity\"] or [{path, spawn, sync, watch}]")
	var config: SceneReplicationConfig = sync.replication_config
	if config == null:
		config = SceneReplicationConfig.new()
		sync.replication_config = config
	if optional_bool(params, "clear_existing", false):
		# Remove all properties
		var existing: Array = []
		if config.has_method("get_properties"):
			existing = config.get_properties()
		for p in existing:
			if config.has_method("remove_property"):
				config.remove_property(p)
	var added: Array = []
	for item in params["properties"]:
		var prop_path: NodePath
		var spawn := true
		var sync_prop := true
		var watch := false
		if item is String:
			prop_path = NodePath(str(item))
		elif item is Dictionary:
			prop_path = NodePath(str(item.get("path", item.get("property", ""))))
			spawn = bool(item.get("spawn", true))
			sync_prop = bool(item.get("sync", item.get("replication_mode", true)))
			watch = bool(item.get("watch", false))
		else:
			continue
		if str(prop_path).is_empty():
			continue
		if config.has_method("add_property"):
			config.add_property(prop_path)
		# Godot 4 SceneReplicationConfig property options
		if config.has_method("property_set_spawn"):
			config.property_set_spawn(prop_path, spawn)
		if config.has_method("property_set_replication_mode"):
			# 0 never, 1 always, 2 on_change - map bool sync
			var mode := 1 if sync_prop else 0
			if item is Dictionary and item.has("replication_mode"):
				mode = int(item["replication_mode"])
			config.property_set_replication_mode(prop_path, mode)
		elif config.has_method("property_set_sync"):
			config.property_set_sync(prop_path, sync_prop)
		if config.has_method("property_set_watch"):
			config.property_set_watch(prop_path, watch)
		added.append(str(prop_path))
	sync.replication_config = config
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"added": added,
		"count": added.size(),
	})


func _list_config(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var sync := _find_sync(r0[0])
	if sync == null:
		return error_not_found("MultiplayerSynchronizer")
	var config: SceneReplicationConfig = sync.replication_config
	var props: Array = []
	if config and config.has_method("get_properties"):
		for p in config.get_properties():
			var entry := {"path": str(p)}
			if config.has_method("property_get_spawn"):
				entry["spawn"] = config.property_get_spawn(p)
			if config.has_method("property_get_sync"):
				entry["sync"] = config.property_get_sync(p)
			if config.has_method("property_get_watch"):
				entry["watch"] = config.property_get_watch(p)
			if config.has_method("property_get_replication_mode"):
				entry["replication_mode"] = config.property_get_replication_mode(p)
			props.append(entry)
	return success({
		"node_path": r0[0],
		"root_path": str(sync.root_path),
		"replication_interval": sync.replication_interval,
		"delta_interval": sync.delta_interval,
		"public_visibility": sync.public_visibility,
		"properties": props,
		"count": props.size(),
	})


func _set_rpc(params: Dictionary) -> Dictionary:
	## Call node.set_rpc or configure via script - document RPC for a method name.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null:
		return error_not_found("Node")
	var method: String = optional_string(params, "method", "")
	if method.is_empty():
		return error_invalid_params("method required")
	# Build RPCConfig if available (Godot 4)
	if not node.has_method(method) and not optional_bool(params, "force", false):
		return error_invalid_params("Node has no method '%s' (pass force=true to set config anyway)" % method)
	var mode: String = optional_string(params, "rpc_mode", "authority").to_lower()
	var transfer: String = optional_string(params, "transfer_mode", "reliable").to_lower()
	var call_local: bool = optional_bool(params, "call_local", true)
	var channel: int = optional_int(params, "channel", 0)
	# Godot 4.x: node.rpc_config(method, config_dict) in some versions
	var cfg := {
		"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY if mode in ["authority", "auth"] else MultiplayerAPI.RPC_MODE_ANY_PEER,
		"transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE if transfer == "reliable" else (
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if transfer == "unreliable_ordered" else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		),
		"call_local": call_local,
		"channel": channel,
	}
	if node.has_method("rpc_config"):
		node.rpc_config(StringName(method), cfg)
	elif multiplayer and multiplayer.has_method("get"):
		# Fallback message
		return success({
			"node_path": r0[0],
			"method": method,
			"config": cfg,
			"applied_via": "none",
			"hint": "Add @rpc annotation on the method in GDScript for reliable config, or use rpc_config if available",
		})
	mark_current_scene_unsaved()
	return success({
		"node_path": r0[0],
		"method": method,
		"config": cfg,
		"applied_via": "rpc_config",
	})
