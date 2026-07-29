@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Combat core - damage, health events, status effects (buff/debuff) for agents.


func get_commands() -> Dictionary:
	return {
		"create_damage_info_resource_script": _create_damage_info,
		"create_health_component_v2_script": _create_health_v2,
		"create_status_effect_resource_script": _create_status_res,
		"create_status_effect_controller_script": _create_status_ctrl,
		"setup_damage_pipeline_scripts": _pipeline,
		"list_combat_status_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"create_health_component_script", "setup_hitbox", "setup_hurtbox",
		"create_floating_text_script", "create_hit_flash_script",
	], {
		"flow": [
			"setup_damage_pipeline_scripts",
			"attach Health + StatusEffectController to actors",
			"hitbox applies DamageInfo -> hurtbox -> health.take_damage",
		],
	})


func _create_damage_info(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/damage_info.gd")
	var content := """extends Resource
class_name DamageInfo
## One hit packet - damage type, amount, knockback, crit, source.

@export var amount: float = 10.0
@export var damage_type: StringName = &\"physical\"  # physical, fire, ice, poison, true
@export var can_crit: bool = true
@export var crit_multiplier: float = 1.5
@export var knockback: float = 0.0
@export var knockback_dir: Vector3 = Vector3.ZERO
@export var source_path: NodePath
@export var hitstun: float = 0.0
@export var status_to_apply: StringName = &\"\"
@export var status_duration: float = 0.0
@export var status_stacks: int = 1
@export var meta: Dictionary = {}

func with_amount(a: float) -> DamageInfo:
	var d := duplicate() as DamageInfo
	d.amount = a
	return d
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "DamageInfo"})


func _create_health_v2(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/health_component.gd")
	var content := """extends Node
class_name HealthComponent
## Health + armor + i-frames; accepts DamageInfo resources.

signal damaged(info: Resource, final_amount: float)
signal healed(amount: float)
signal died
signal revived

@export var max_hp: float = 100.0
@export var hp: float = 100.0
@export var armor: float = 0.0
@export var invuln_time: float = 0.0
@export var is_dead: bool = false

var _iframes: float = 0.0

func _process(delta: float) -> void:
	if _iframes > 0.0:
		_iframes = maxf(0.0, _iframes - delta)

func take_damage(info: Resource) -> float:
	if is_dead or _iframes > 0.0:
		return 0.0
	var amount := float(info.get(\"amount\")) if info else 0.0
	var dtype := str(info.get(\"damage_type\")) if info else \"physical\"
	if dtype != \"true\":
		amount = maxf(0.0, amount - armor)
	if info and bool(info.get(\"can_crit\")) and randf() < 0.1:
		amount *= float(info.get(\"crit_multiplier\"))
	hp = maxf(0.0, hp - amount)
	if invuln_time > 0.0:
		_iframes = invuln_time
	damaged.emit(info, amount)
	if hp <= 0.0:
		is_dead = true
		died.emit()
	return amount

func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	healed.emit(amount)

func revive(full: bool = true) -> void:
	is_dead = false
	hp = max_hp if full else maxf(1.0, hp)
	revived.emit()

func ratio() -> float:
	return 0.0 if max_hp <= 0.0 else hp / max_hp
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "HealthComponent"})


func _create_status_res(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/status_effect_data.gd")
	var content := """extends Resource
class_name StatusEffectData
## Buff/debuff definition.

@export var id: StringName = &\"\"
@export var display_name: String = \"Effect\"
@export var duration: float = 5.0
@export var max_stacks: int = 1
@export var tick_interval: float = 1.0
@export var damage_per_tick: float = 0.0
@export var heal_per_tick: float = 0.0
@export var speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var icon: Texture2D
@export var tags: PackedStringArray = PackedStringArray()
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "StatusEffectData"})


func _create_status_ctrl(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/status_effect_controller.gd")
	var content := """extends Node
class_name StatusEffectController
## Tracks active status effects on an actor.

signal effect_added(id: StringName, stacks: int)
signal effect_removed(id: StringName)
signal effect_ticked(id: StringName, stacks: int)

@export var health_path: NodePath
var _effects: Dictionary = {}  # id -> {data, stacks, time_left, tick_acc}

func apply(data: Resource, stacks: int = 1) -> void:
	if data == null:
		return
	var id: StringName = data.get(\"id\")
	if _effects.has(id):
		var e: Dictionary = _effects[id]
		e[\"stacks\"] = mini(int(data.get(\"max_stacks\")), int(e[\"stacks\"]) + stacks)
		e[\"time_left\"] = float(data.get(\"duration\"))
		_effects[id] = e
	else:
		_effects[id] = {
			\"data\": data,
			\"stacks\": mini(int(data.get(\"max_stacks\")), stacks),
			\"time_left\": float(data.get(\"duration\")),
			\"tick_acc\": 0.0,
		}
	effect_added.emit(id, int(_effects[id][\"stacks\"]))

func remove(id: StringName) -> void:
	if _effects.erase(id):
		effect_removed.emit(id)

func has_effect(id: StringName) -> bool:
	return _effects.has(id)

func get_speed_mult() -> float:
	var m := 1.0
	for k in _effects:
		var d: Resource = _effects[k][\"data\"]
		m *= float(d.get(\"speed_mult\"))
	return m

func _process(delta: float) -> void:
	var to_remove: Array = []
	for id in _effects.keys():
		var e: Dictionary = _effects[id]
		var data: Resource = e[\"data\"]
		e[\"time_left\"] = float(e[\"time_left\"]) - delta
		e[\"tick_acc\"] = float(e[\"tick_acc\"]) + delta
		var interval := float(data.get(\"tick_interval\"))
		if interval > 0.0 and float(e[\"tick_acc\"]) >= interval:
			e[\"tick_acc\"] = 0.0
			_tick(id, e, data)
			effect_ticked.emit(id, int(e[\"stacks\"]))
		if float(e[\"time_left\"]) <= 0.0:
			to_remove.append(id)
		else:
			_effects[id] = e
	for id2 in to_remove:
		remove(id2)

func _tick(id: StringName, e: Dictionary, data: Resource) -> void:
	var health := get_node_or_null(health_path)
	if health == null:
		return
	var stacks := int(e[\"stacks\"])
	var dmg := float(data.get(\"damage_per_tick\")) * stacks
	var heal := float(data.get(\"heal_per_tick\")) * stacks
	if dmg > 0.0 and health.has_method(\"take_damage\"):
		var info := Resource.new()
		# Prefer DamageInfo if available
		if ResourceLoader.exists(\"res://scripts/damage_info.gd\"):
			var DI = load(\"res://scripts/damage_info.gd\")
			if DI:
				info = DI.new()
				info.set(\"amount\", dmg)
				info.set(\"damage_type\", &\"poison\")
				info.set(\"can_crit\", false)
		health.call(\"take_damage\", info)
	if heal > 0.0 and health.has_method(\"heal\"):
		health.call(\"heal\", heal)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "StatusEffectController"})


func _pipeline(params: Dictionary) -> Dictionary:
	var steps: Array = []
	steps.append(_create_damage_info({"path": optional_string(params, "damage_path", "res://scripts/damage_info.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_create_health_v2({"path": optional_string(params, "health_path", "res://scripts/health_component.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_create_status_res({"path": optional_string(params, "status_data_path", "res://scripts/status_effect_data.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	steps.append(_create_status_ctrl({"path": optional_string(params, "status_ctrl_path", "res://scripts/status_effect_controller.gd"), "overwrite": optional_bool(params, "overwrite", false)}))
	return success({
		"steps": steps,
		"wire": [
			"Add HealthComponent + StatusEffectController under actor",
			"Hurtbox -> health.take_damage(DamageInfo)",
			"Optional: info.status_to_apply -> status.apply(StatusEffectData)",
		],
	})
