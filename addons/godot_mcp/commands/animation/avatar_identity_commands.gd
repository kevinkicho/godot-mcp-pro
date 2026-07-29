@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Avatar identity - modular slots, equip, body scale, loadout config for humanoids.


func get_commands() -> Dictionary:
	return {
		"create_avatar_config_resource": _create_config,
		"create_avatar_config_script": _create_config_script,
		"setup_avatar_slot_rig": _setup_slot_rig,
		"list_avatar_slots": _list_slots,
		"equip_avatar_item": _equip,
		"unequip_avatar_slot": _unequip,
		"set_avatar_body_scale": _body_scale,
		"apply_avatar_loadout": _apply_loadout,
		"export_avatar_loadout": _export_loadout,
		"hide_avatar_mesh_surfaces": _hide_surfaces,
		"list_avatar_identity_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return list_tools_payload([
		"setup_humanoid_actor", "add_bone_attachment", "list_mesh_surfaces",
		"set_blend_shape_value", "apply_avatar_material_pack", "validate_humanoid_rig",
	], {
		"default_slots": ["root", "head", "hair", "face", "torso", "legs", "feet", "hands", "weapon_r", "weapon_l", "back", "accessory"],
		"flow": [
			"setup_humanoid_actor / pipeline_character_from_gltf",
			"setup_avatar_slot_rig on model root",
			"equip_avatar_item slot=hair scene_path=...",
			"set_avatar_body_scale / apply_avatar_material_pack",
			"export_avatar_loadout for save/network",
		],
	})


func _create_config_script(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://scripts/avatar_config.gd")
	var content := """extends Resource
class_name AvatarConfig
## MCP avatar loadout - identity data agents can save/load/sync.

@export var avatar_id: String = \"default\"
@export var display_name: String = \"Hero\"
@export var body_scale: Vector3 = Vector3.ONE
@export var skin_tone: Color = Color(0.86, 0.72, 0.62)
@export var slots: Dictionary = {
	# slot_name -> { \"scene\": \"res://...\", \"bone\": \"Head\", \"visible\": true }
}
@export var blend_shapes: Dictionary = {}  # name -> float 0..1
@export var material_overrides: Dictionary = {}  # surface_or_slot -> res://mat.tres
@export var meta: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		\"avatar_id\": avatar_id,
		\"display_name\": display_name,
		\"body_scale\": {\"x\": body_scale.x, \"y\": body_scale.y, \"z\": body_scale.z},
		\"skin_tone\": skin_tone.to_html(true),
		\"slots\": slots.duplicate(true),
		\"blend_shapes\": blend_shapes.duplicate(true),
		\"material_overrides\": material_overrides.duplicate(true),
		\"meta\": meta.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	avatar_id = str(d.get(\"avatar_id\", avatar_id))
	display_name = str(d.get(\"display_name\", display_name))
	if d.has(\"body_scale\") and d[\"body_scale\"] is Dictionary:
		var b: Dictionary = d[\"body_scale\"]
		body_scale = Vector3(float(b.get(\"x\", 1)), float(b.get(\"y\", 1)), float(b.get(\"z\", 1)))
	if d.has(\"skin_tone\"):
		skin_tone = Color.html(str(d[\"skin_tone\"])) if str(d[\"skin_tone\"]).begins_with(\"#\") else Color(str(d[\"skin_tone\"]))
	if d.has(\"slots\") and d[\"slots\"] is Dictionary:
		slots = (d[\"slots\"] as Dictionary).duplicate(true)
	if d.has(\"blend_shapes\") and d[\"blend_shapes\"] is Dictionary:
		blend_shapes = (d[\"blend_shapes\"] as Dictionary).duplicate(true)
	if d.has(\"material_overrides\") and d[\"material_overrides\"] is Dictionary:
		material_overrides = (d[\"material_overrides\"] as Dictionary).duplicate(true)
	if d.has(\"meta\") and d[\"meta\"] is Dictionary:
		meta = (d[\"meta\"] as Dictionary).duplicate(true)
"""
	var res := write_script_file(path, content, optional_bool(params, "overwrite", false))
	if res.has("error"):
		return res
	return success({"path": path, "class_name": "AvatarConfig"})


func _create_config(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://avatars/default_avatar.tres")
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	var script_path: String = optional_string(params, "script_path", "res://scripts/avatar_config.gd")
	if not FileAccess.file_exists(script_path):
		var scr := _create_config_script({"path": script_path, "overwrite": false})
		if scr.has("error") and int(scr["error"].get("code", 0)) != -32000:
			return scr
	var script: Script = load(script_path) as Script
	if script == null:
		return error_internal("Cannot load AvatarConfig script")
	var res: Resource = script.new()
	if params.has("avatar_id") and "avatar_id" in res:
		res.set("avatar_id", str(params["avatar_id"]))
	if params.has("display_name") and "display_name" in res:
		res.set("display_name", str(params["display_name"]))
	if params.has("slots") and params["slots"] is Dictionary and "slots" in res:
		res.set("slots", params["slots"])
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "Exists: %s" % path, {"suggestion": "overwrite=true"})
	return save_resource_to_res(res, path, true)


func _find_or_make_slots_root(actor: Node, root: Node, name_s: String = "AvatarSlots") -> Node:
	var existing := actor.get_node_or_null(name_s)
	if existing:
		return existing
	var n := Node3D.new()
	n.name = name_s
	add_child_with_undo(actor, n, root, "MCP: AvatarSlots")
	return n


func _setup_slot_rig(params: Dictionary) -> Dictionary:
	## Creates AvatarSlots container + optional BoneAttachments for named slots.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Actor/model root")
	var slots_root := _find_or_make_slots_root(actor, root)
	var sk: Skeleton3D = _find_skeleton_under(actor)
	var slot_defs: Array = params.get("slots", [])
	if slot_defs.is_empty():
		slot_defs = [
			{"name": "head", "bone": "Head"},
			{"name": "hair", "bone": "Head"},
			{"name": "weapon_r", "bone": "RightHand"},
			{"name": "weapon_l", "bone": "LeftHand"},
			{"name": "back", "bone": "Spine2"},
			{"name": "torso", "bone": ""},
			{"name": "legs", "bone": ""},
			{"name": "feet", "bone": ""},
		]
	var created: Array = []
	for s in slot_defs:
		if not s is Dictionary:
			continue
		var sname := str(s.get("name", "slot"))
		var bone := str(s.get("bone", ""))
		var slot_node: Node = slots_root.get_node_or_null(sname)
		if slot_node == null:
			if not bone.is_empty() and sk != null and sk.find_bone(bone) >= 0:
				var ba := BoneAttachment3D.new()
				ba.name = sname
				ba.bone_name = bone
				add_child_with_undo(sk, ba, root, "MCP: avatar slot %s" % sname)
				# Move under slots inventory as path marker? Keep on skeleton for correct skinning
				slot_node = ba
			else:
				var holder := Node3D.new()
				holder.name = sname
				add_child_with_undo(slots_root, holder, root, "MCP: avatar slot %s" % sname)
				slot_node = holder
		created.append({
			"slot": sname,
			"path": str(root.get_path_to(slot_node)),
			"bone": bone,
			"class": slot_node.get_class(),
		})
	# Tag actor meta
	actor.set_meta("mcp_avatar_slots", true)
	mark_current_scene_unsaved()
	return success({
		"actor_path": str(root.get_path_to(actor)),
		"slots_root": str(root.get_path_to(slots_root)),
		"skeleton": str(root.get_path_to(sk)) if sk else null,
		"slots": created,
		"count": created.size(),
	})


func _find_skeleton_under(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var f := _find_skeleton_under(c)
		if f:
			return f
	return null


func _list_slots(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Node")
	var out: Array = []
	_collect_slot_nodes(actor, root, out)
	return success({"node_path": r0[0], "slots": out, "count": out.size()})


func _collect_slot_nodes(n: Node, root: Node, out: Array) -> void:
	var is_slot := n is BoneAttachment3D or str(n.name).begins_with("Slot_")
	var parent_is_slots := n.get_parent() != null and str(n.get_parent().name) == "AvatarSlots"
	if is_slot or parent_is_slots:
		var children_items: Array = []
		for c in n.get_children():
			children_items.append({
				"name": c.name,
				"path": str(root.get_path_to(c)),
				"class": c.get_class(),
				"scene_file": c.scene_file_path if c.scene_file_path else "",
			})
		out.append({
			"slot": str(n.name),
			"path": str(root.get_path_to(n)),
			"class": n.get_class(),
			"bone": n.bone_name if n is BoneAttachment3D else "",
			"equipped": children_items,
		})
	for c in n.get_children():
		_collect_slot_nodes(c, root, out)


func _find_slot_node(actor: Node, slot: String) -> Node:
	# Prefer exact name under skeleton / AvatarSlots
	var candidates: Array = []
	_walk_named(actor, slot, candidates)
	if candidates.size() > 0:
		return candidates[0]
	var alt := "Slot_" + slot
	_walk_named(actor, alt, candidates)
	return candidates[0] if candidates.size() > 0 else null


func _walk_named(n: Node, name_s: String, out: Array) -> void:
	if str(n.name) == name_s:
		out.append(n)
	for c in n.get_children():
		_walk_named(c, name_s, out)


func _equip(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var slot_r := require_string(params, "slot")
	if slot_r[1] != null:
		return slot_r[1]
	var scene_r := require_string(params, "scene_path")
	if scene_r[1] != null:
		return scene_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Actor")
	var slot_node := _find_slot_node(actor, slot_r[0])
	if slot_node == null:
		# Auto-create free slot under AvatarSlots
		var slots_root := _find_or_make_slots_root(actor, root)
		slot_node = Node3D.new()
		slot_node.name = slot_r[0]
		add_child_with_undo(slots_root, slot_node, root, "MCP: auto slot")
	var scene_path: String = scene_r[0]
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path.trim_prefix("/")
	if not ResourceLoader.exists(scene_path):
		return error_not_found(scene_path)
	if optional_bool(params, "clear_slot", true):
		for c in slot_node.get_children():
			slot_node.remove_child(c)
			c.queue_free()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return error_internal("Not a PackedScene: %s" % scene_path)
	var inst := packed.instantiate()
	inst.name = optional_string(params, "item_name", scene_path.get_file().get_basename())
	add_child_with_undo(slot_node, inst, root, "MCP: equip %s" % slot_r[0])
	if params.has("position"):
		var p = params["position"]
		if p is Dictionary and inst is Node3D:
			(inst as Node3D).position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
	if params.has("scale") and inst is Node3D:
		var sc = params["scale"]
		if sc is Dictionary:
			(inst as Node3D).scale = Vector3(float(sc.get("x", 1)), float(sc.get("y", 1)), float(sc.get("z", 1)))
		elif sc is float or sc is int:
			(inst as Node3D).scale = Vector3.ONE * float(sc)
	mark_current_scene_unsaved()
	return success({
		"actor_path": str(root.get_path_to(actor)),
		"slot": slot_r[0],
		"slot_path": str(root.get_path_to(slot_node)),
		"item_path": str(root.get_path_to(inst)),
		"scene_path": scene_path,
	})


func _unequip(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var slot_r := require_string(params, "slot")
	if slot_r[1] != null:
		return slot_r[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Actor")
	var slot_node := _find_slot_node(actor, slot_r[0])
	if slot_node == null:
		return error_not_found("Slot '%s'" % slot_r[0])
	var removed: Array = []
	for c in slot_node.get_children():
		removed.append(str(c.name))
		slot_node.remove_child(c)
		c.queue_free()
	mark_current_scene_unsaved()
	return success({"slot": slot_r[0], "removed": removed, "count": removed.size()})


func _body_scale(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null or not (node is Node3D):
		return error_not_found("Node3D")
	var n3 := node as Node3D
	var scale_v := Vector3.ONE
	if params.has("scale"):
		var s = params["scale"]
		if s is Dictionary:
			scale_v = Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1)))
		elif s is float or s is int:
			scale_v = Vector3.ONE * float(s)
	elif params.has("height_scale") or params.has("width_scale"):
		var h := float(params.get("height_scale", 1.0))
		var w := float(params.get("width_scale", 1.0))
		scale_v = Vector3(w, h, w)
	else:
		return error_invalid_params("scale{} or height_scale/width_scale required")
	var old := n3.scale
	n3.scale = scale_v
	# Optional motion_scale on skeleton
	if optional_bool(params, "adjust_skeleton_motion_scale", false):
		var sk := _find_skeleton_under(n3)
		if sk and "motion_scale" in sk:
			sk.motion_scale = float(params.get("motion_scale", scale_v.y))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(n3)),
		"scale": {"x": n3.scale.x, "y": n3.scale.y, "z": n3.scale.z},
		"old": {"x": old.x, "y": old.y, "z": old.z},
	})


func _apply_loadout(params: Dictionary) -> Dictionary:
	## loadout: {slots:{}, body_scale?, blend_shapes?, materials?} or path to .tres/.json
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Actor")
	var loadout: Dictionary = {}
	if params.has("loadout") and params["loadout"] is Dictionary:
		loadout = params["loadout"]
	elif params.has("path"):
		var p := str(params["path"])
		if not p.begins_with("res://"):
			p = "res://" + p.trim_prefix("/")
		if p.ends_with(".json") and FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				loadout = data
		elif ResourceLoader.exists(p):
			var res = load(p)
			if res and res.has_method("to_dict"):
				loadout = res.to_dict()
			elif res is Resource and "slots" in res:
				loadout = {
					"slots": res.get("slots"),
					"body_scale": res.get("body_scale") if "body_scale" in res else null,
					"blend_shapes": res.get("blend_shapes") if "blend_shapes" in res else {},
				}
	if loadout.is_empty():
		return error_invalid_params("loadout{} or path to AvatarConfig/json required")
	var steps: Array = []
	if loadout.has("body_scale"):
		var bs = loadout["body_scale"]
		var sc_params := {"node_path": r0[0], "scale": bs if bs is Dictionary else {"x": 1, "y": 1, "z": 1}}
		if bs is Vector3:
			sc_params["scale"] = {"x": bs.x, "y": bs.y, "z": bs.z}
		steps.append({"body_scale": _body_scale(sc_params)})
	if loadout.has("slots") and loadout["slots"] is Dictionary:
		for slot_name in loadout["slots"]:
			var entry = loadout["slots"][slot_name]
			var scene_path := ""
			if entry is String:
				scene_path = entry
			elif entry is Dictionary:
				scene_path = str(entry.get("scene", entry.get("scene_path", "")))
			if scene_path.is_empty():
				continue
			steps.append({"equip": _equip({
				"node_path": r0[0],
				"slot": str(slot_name),
				"scene_path": scene_path,
				"clear_slot": true,
			})})
	if loadout.has("blend_shapes") and loadout["blend_shapes"] is Dictionary:
		# Deferred to blend shape tool via meta stash if mesh path unknown
		actor.set_meta("mcp_pending_blend_shapes", loadout["blend_shapes"])
		steps.append({"blend_shapes_stashed": true, "count": (loadout["blend_shapes"] as Dictionary).size()})
	mark_current_scene_unsaved()
	return success({"actor_path": r0[0], "steps": steps, "applied_keys": loadout.keys()})


func _export_loadout(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var actor := find_node_by_path(r0[0])
	if actor == null:
		return error_not_found("Actor")
	var slots_list: Array = []
	_collect_slot_nodes(actor, root, slots_list)
	var slots_dict := {}
	for s in slots_list:
		if not s is Dictionary:
			continue
		var equipped: Array = s.get("equipped", [])
		if equipped.is_empty():
			continue
		var first: Dictionary = equipped[0]
		slots_dict[str(s.get("slot"))] = {
			"scene": str(first.get("scene_file", "")),
			"item": str(first.get("name", "")),
			"path": str(first.get("path", "")),
			"bone": str(s.get("bone", "")),
		}
	var scale_d := {}
	if actor is Node3D:
		var sc := (actor as Node3D).scale
		scale_d = {"x": sc.x, "y": sc.y, "z": sc.z}
	var loadout := {
		"avatar_id": optional_string(params, "avatar_id", str(actor.name)),
		"body_scale": scale_d,
		"slots": slots_dict,
	}
	var out_path: String = optional_string(params, "path", "")
	if not out_path.is_empty():
		if not out_path.begins_with("res://"):
			out_path = "res://" + out_path.trim_prefix("/")
		var w := write_text_res(out_path, JSON.stringify(loadout, "\t"), optional_bool(params, "overwrite", true))
		if w.has("error"):
			return w
		return success({"path": out_path, "loadout": loadout})
	return success({"loadout": loadout})


func _hide_surfaces(params: Dictionary) -> Dictionary:
	## Hide mesh surfaces by index or name-substring (e.g. body under armor).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(r0[0])
	if node == null or not (node is MeshInstance3D):
		return error_not_found("MeshInstance3D")
	var mi := node as MeshInstance3D
	if mi.mesh == null:
		return error_invalid_params("MeshInstance3D has no mesh")
	var visible: bool = optional_bool(params, "visible", false)
	var changed: Array = []
	if params.has("surfaces") and params["surfaces"] is Array:
		for idx in params["surfaces"]:
			var i := int(idx)
			if i >= 0 and i < mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, _make_invisible_mat() if not visible else null)
				changed.append(i)
	elif params.has("name_contains"):
		var sub := str(params["name_contains"]).to_lower()
		for i in mi.mesh.get_surface_count():
			var sname := mi.mesh.surface_get_name(i).to_lower()
			if sub in sname:
				mi.set_surface_override_material(i, _make_invisible_mat() if not visible else null)
				changed.append(i)
	else:
		return error_invalid_params("surfaces[] or name_contains required")
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "surfaces": changed, "visible": visible})


func _make_invisible_mat() -> Material:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
