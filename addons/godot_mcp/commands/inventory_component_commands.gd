@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Inventory component recipes — high-gain gameplay loop for RPG/action agents.


func get_commands() -> Dictionary:
	return {
		"create_inventory_component_script": _create_inventory,
		"create_item_resource_script": _create_item_res,
		"create_item_resource": _create_item_instance,
		"list_inventory_component_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["setup_inventory_ui", "create_quest_log_script", "setup_interaction_zone"],
	})


func _create_item_res(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/item_data.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	var content := """extends Resource
class_name ItemData
## Stackable item definition.

@export var id: StringName = &\"\"
@export var display_name: String = \"Item\"
@export_multiline var description: String = \"\"
@export var max_stack: int = 99
@export var icon: Texture2D
@export var tags: PackedStringArray = PackedStringArray()
@export var metadata: Dictionary = {}
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({"path": path, "class_name": "ItemData"})


func _create_inventory(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/inventory_component.gd")
	var vr := validate_res_path(path)
	if vr[1] != null:
		return vr[1]
	path = vr[0]
	# Ensure ItemData exists
	var item_script: String = optional_string(params, "item_script", "res://scripts/item_data.gd")
	if not FileAccess.file_exists(item_script):
		var ir := _create_item_res({"path": item_script, "overwrite": false})
		if ir.has("error") and not FileAccess.file_exists(item_script):
			pass  # continue anyway
	var content := """extends Node
class_name InventoryComponent
## Simple grid-less stack inventory.

signal changed
signal item_added(item: Resource, amount: int)
signal item_removed(item_id: StringName, amount: int)

@export var capacity: int = 20
## Array of {id, amount, item: ItemData}
var slots: Array = []

func _find_slot(item_id: StringName) -> int:
	for i in slots.size():
		if str(slots[i].get(\"id\", \"\")) == str(item_id):
			return i
	return -1

func get_count(item_id: StringName) -> int:
	var idx := _find_slot(item_id)
	if idx < 0:
		return 0
	return int(slots[idx].get(\"amount\", 0))

func can_add(item: Resource, amount: int = 1) -> bool:
	if item == null or amount <= 0:
		return false
	var item_id: StringName = item.get(\"id\") if \"id\" in item else StringName(str(item.resource_path))
	var max_stack: int = int(item.get(\"max_stack\")) if \"max_stack\" in item else 99
	var idx := _find_slot(item_id)
	if idx >= 0:
		return int(slots[idx][\"amount\"]) + amount <= max_stack or slots.size() < capacity
	return slots.size() < capacity

func add_item(item: Resource, amount: int = 1) -> int:
	## Returns amount actually added.
	if item == null or amount <= 0:
		return 0
	var item_id: StringName = item.get(\"id\") if \"id\" in item else StringName(item.resource_path.get_file())
	var max_stack: int = int(item.get(\"max_stack\")) if \"max_stack\" in item else 99
	var remaining := amount
	var idx := _find_slot(item_id)
	if idx >= 0:
		var cur: int = int(slots[idx][\"amount\"])
		var space: int = maxi(0, max_stack - cur)
		var add_n: int = mini(space, remaining)
		slots[idx][\"amount\"] = cur + add_n
		remaining -= add_n
	while remaining > 0 and slots.size() < capacity:
		var add_n2: int = mini(max_stack, remaining)
		slots.append({\"id\": item_id, \"amount\": add_n2, \"item\": item})
		remaining -= add_n2
	var added := amount - remaining
	if added > 0:
		item_added.emit(item, added)
		changed.emit()
	return added

func remove_item(item_id: StringName, amount: int = 1) -> int:
	var idx := _find_slot(item_id)
	if idx < 0 or amount <= 0:
		return 0
	var cur: int = int(slots[idx][\"amount\"])
	var rem: int = mini(cur, amount)
	slots[idx][\"amount\"] = cur - rem
	if int(slots[idx][\"amount\"]) <= 0:
		slots.remove_at(idx)
	item_removed.emit(item_id, rem)
	changed.emit()
	return rem

func to_save() -> Array:
	var out: Array = []
	for s in slots:
		out.append({\"id\": str(s.get(\"id\", \"\")), \"amount\": int(s.get(\"amount\", 0)), \"item_path\": s[\"item\"].resource_path if s.get(\"item\") is Resource else \"\"})
	return out

func from_save(data: Array) -> void:
	slots.clear()
	for e in data:
		if not e is Dictionary:
			continue
		var ip: String = str(e.get(\"item_path\", \"\"))
		var item: Resource = load(ip) if ip and ResourceLoader.exists(ip) else null
		slots.append({\"id\": StringName(str(e.get(\"id\", \"\"))), \"amount\": int(e.get(\"amount\", 0)), \"item\": item})
	changed.emit()
"""
	var wr := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if wr.has("error"):
		return wr
	return success({
		"path": path,
		"item_script": item_script,
		"api": ["add_item", "remove_item", "get_count", "to_save", "from_save"],
	})


func _create_item_instance(params: Dictionary) -> Dictionary:
	## Create an ItemData .tres resource.
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists", {"suggestion": "overwrite=true"})
	var item_script_path: String = optional_string(params, "item_script", "res://scripts/item_data.gd")
	if not FileAccess.file_exists(item_script_path):
		_create_item_res({"path": item_script_path, "overwrite": true})
	var script_res = load(item_script_path)
	if script_res == null:
		return error_internal("Cannot load item script")
	var item: Resource = script_res.new() if script_res.can_instantiate() else null
	# Resource scripts use new() on GDScript
	if item == null and script_res is GDScript:
		item = (script_res as GDScript).new()
	if item == null:
		return error_internal("Cannot instantiate ItemData")
	if "id" in item:
		item.set("id", StringName(optional_string(params, "id", path.get_file().get_basename())))
	if "display_name" in item:
		item.set("display_name", optional_string(params, "display_name", optional_string(params, "id", "Item")))
	if "max_stack" in item and params.has("max_stack"):
		item.set("max_stack", int(params["max_stack"]))
	if "description" in item and params.has("description"):
		item.set("description", str(params["description"]))
	if params.has("icon_path") and ResourceLoader.exists(str(params["icon_path"])) and "icon" in item:
		item.set("icon", load(str(params["icon_path"])))
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var err := ResourceSaver.save(item, path)
	if err != OK:
		return error_internal(error_string(err))
	EditorInterface.get_resource_filesystem().update_file(path)
	return success({"path": path, "id": optional_string(params, "id", path.get_file().get_basename())})
