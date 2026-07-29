@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Crafting recipes + hotbar UI - RPG/survival agent production surface.


func get_commands() -> Dictionary:
	return {
		"create_crafting_recipe_resource_script": _create_recipe_res,
		"create_crafting_system_script": _create_crafting,
		"create_hotbar_script": _create_hotbar,
		"setup_hotbar_ui": _setup_hotbar_ui,
		"setup_crafting_ui": _setup_crafting_ui,
		"create_recipe_json": _create_recipe_json,
		"list_crafting_hotbar_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_inventory_component_script", "create_item_resource", "setup_inventory_ui",
		"create_health_component_script", "setup_interaction_zone",
	], {
		"flow": [
			"create_item_resource for ingredients/results",
			"create_crafting_system_script + create_recipe_json",
			"setup_crafting_ui / setup_hotbar_ui",
		],
	})


func _create_recipe_res(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/crafting_recipe.gd")
	var content := """extends Resource
class_name CraftingRecipe
@export var id: StringName = &\"\"
@export var display_name: String = \"Recipe\"
@export var ingredients: Dictionary = {}  # item_id -> count
@export var results: Dictionary = {}      # item_id -> count
@export var craft_time: float = 0.0
@export var station: StringName = &\"hand\"  # hand, forge, workbench
@export var unlocked: bool = true
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "CraftingRecipe"})


func _create_crafting(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/crafting_system.gd")
	var content := """extends Node
class_name CraftingSystem
## Inventory-backed crafting.

signal craft_started(recipe_id: StringName)
signal craft_finished(recipe_id: StringName, ok: bool)

@export var inventory_path: NodePath
@export var recipes_path: String = \"res://data/recipes.json\"

var _recipes: Array = []

func _ready() -> void:
	reload_recipes()

func reload_recipes() -> void:
	_recipes.clear()
	if not FileAccess.file_exists(recipes_path):
		return
	var f := FileAccess.open(recipes_path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		_recipes = data
	elif data is Dictionary and data.has(\"recipes\"):
		_recipes = data[\"recipes\"]

func list_recipes(station: String = \"\") -> Array:
	if station.is_empty():
		return _recipes.duplicate()
	var out: Array = []
	for r in _recipes:
		if str(r.get(\"station\", \"hand\")) == station or str(r.get(\"station\", \"\")) == \"\":
			out.append(r)
	return out

func can_craft(recipe_id: String, inv: Object = null) -> bool:
	var r := _find(recipe_id)
	if r.is_empty():
		return false
	inv = inv if inv else get_node_or_null(inventory_path)
	if inv == null:
		return false
	var need: Dictionary = r.get(\"ingredients\", {})
	for item_id in need:
		var have := 0
		if inv.has_method(\"count_item\"):
			have = int(inv.call(\"count_item\", item_id))
		elif inv.has_method(\"get_count\"):
			have = int(inv.call(\"get_count\", item_id))
		if have < int(need[item_id]):
			return false
	return true

func craft(recipe_id: String, inv: Object = null) -> bool:
	if not can_craft(recipe_id, inv):
		craft_finished.emit(StringName(recipe_id), false)
		return false
	inv = inv if inv else get_node_or_null(inventory_path)
	var r := _find(recipe_id)
	craft_started.emit(StringName(recipe_id))
	var need: Dictionary = r.get(\"ingredients\", {})
	for item_id in need:
		if inv.has_method(\"remove_item\"):
			inv.call(\"remove_item\", item_id, int(need[item_id]))
	var results: Dictionary = r.get(\"results\", {})
	for item_id2 in results:
		if inv.has_method(\"add_item\"):
			inv.call(\"add_item\", item_id2, int(results[item_id2]))
	craft_finished.emit(StringName(recipe_id), true)
	return true

func _find(recipe_id: String) -> Dictionary:
	for r in _recipes:
		if str(r.get(\"id\", \"\")) == recipe_id:
			return r
	return {}
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "CraftingSystem"})


func _create_hotbar(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/hotbar.gd")
	var content := """extends Node
class_name Hotbar
## Number-key hotbar slots binding inventory item ids.

signal slot_changed(index: int, item_id: String)
signal activated(index: int, item_id: String)

@export var slot_count: int = 10
@export var inventory_path: NodePath
var slots: PackedStringArray = PackedStringArray()
var selected: int = 0

func _ready() -> void:
	slots.resize(slot_count)
	for i in slot_count:
		if slots[i] == null:
			slots[i] = \"\"

func set_slot(index: int, item_id: String) -> void:
	if index < 0 or index >= slot_count:
		return
	slots[index] = item_id
	slot_changed.emit(index, item_id)

func select(index: int) -> void:
	selected = clampi(index, 0, slot_count - 1)

func activate_selected() -> void:
	var id := slots[selected] if selected < slots.size() else \"\"
	activated.emit(selected, id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event.keycode
		if k >= KEY_1 and k <= KEY_9:
			select(k - KEY_1)
			activate_selected()
		elif k == KEY_0:
			select(9)
			activate_selected()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "Hotbar"})


func _setup_hotbar_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "HotbarLayer")
	layer.layer = optional_int(params, "layer", 20)
	add_child_with_undo(parent, layer, root, "MCP: Hotbar layer")
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -200
	bar.offset_right = 200
	bar.offset_top = -72
	bar.offset_bottom = -16
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child_with_undo(layer, bar, root, "MCP: Hotbar HBox")
	var n := optional_int(params, "slots", 10)
	for i in n:
		var panel := PanelContainer.new()
		panel.name = "Slot%d" % i
		panel.custom_minimum_size = Vector2(48, 48)
		add_child_with_undo(bar, panel, root, "MCP: slot")
		var lbl := Label.new()
		lbl.text = str((i + 1) % 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child_with_undo(panel, lbl, root, "MCP: slot label")
	var script_path: String = optional_string(params, "script_path", "res://scripts/hotbar.gd")
	if not FileAccess.file_exists(script_path):
		_create_hotbar({"path": script_path, "overwrite": false})
	var logic := Node.new()
	logic.name = "HotbarLogic"
	var scr: Script = load(script_path)
	if scr:
		logic.set_script(scr)
	add_child_with_undo(layer, logic, root, "MCP: Hotbar logic")
	mark_current_scene_unsaved()
	return success({
		"layer_path": str(root.get_path_to(layer)),
		"bar_path": str(root.get_path_to(bar)),
		"logic_path": str(root.get_path_to(logic)),
		"slots": n,
	})


func _setup_crafting_ui(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(optional_string(params, "parent_path", "."))
	if parent == null:
		return error_not_found("Parent")
	var layer := CanvasLayer.new()
	layer.name = optional_string(params, "name", "CraftingLayer")
	layer.layer = optional_int(params, "layer", 25)
	add_child_with_undo(parent, layer, root, "MCP: Crafting layer")
	var panel := PanelContainer.new()
	panel.name = "CraftingPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -160
	panel.offset_bottom = 160
	add_child_with_undo(layer, panel, root, "MCP: Crafting panel")
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child_with_undo(panel, vbox, root, "MCP: vbox")
	var title := Label.new()
	title.text = optional_string(params, "title", "Crafting")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child_with_undo(vbox, title, root, "MCP: title")
	var list := ItemList.new()
	list.name = "RecipeList"
	list.custom_minimum_size = Vector2(0, 180)
	add_child_with_undo(vbox, list, root, "MCP: recipes")
	var btn := Button.new()
	btn.name = "CraftButton"
	btn.text = "Craft"
	add_child_with_undo(vbox, btn, root, "MCP: craft btn")
	mark_current_scene_unsaved()
	return success({
		"layer_path": str(root.get_path_to(layer)),
		"panel_path": str(root.get_path_to(panel)),
		"list_path": str(root.get_path_to(list)),
		"hint": "create_crafting_system_script and populate RecipeList from list_recipes()",
	})


func _create_recipe_json(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://data/recipes.json")
	var recipes: Array = params.get("recipes", [])
	if recipes.is_empty():
		recipes = [
			{"id": "wood_plank", "display_name": "Wood Plank", "station": "hand",
				"ingredients": {"wood": 2}, "results": {"plank": 1}, "craft_time": 0.0},
			{"id": "iron_sword", "display_name": "Iron Sword", "station": "forge",
				"ingredients": {"iron_ingot": 3, "plank": 1}, "results": {"iron_sword": 1}, "craft_time": 2.0},
		]
	var data := {"recipes": recipes}
	var w := write_text_res(path, JSON.stringify(data, "\t"), optional_bool(params, "overwrite", false))
	if w.has("error"):
		return w
	return success({"path": path, "count": recipes.size()})
