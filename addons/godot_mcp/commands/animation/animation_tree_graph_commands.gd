@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Deeper AnimationTree graph editing — positions, recipes, blend connections dump.


func get_commands() -> Dictionary:
	return {
		"set_state_machine_node_position": _set_state_machine_node_position,
		"set_state_animation": _set_state_animation,
		"list_state_machine_transitions": _list_state_machine_transitions,
		"get_blend_tree_connections": _get_blend_tree_connections,
		"disconnect_blend_tree_nodes": _disconnect_blend_tree_nodes,
		"create_simple_locomotion_tree": _create_simple_locomotion_tree,
		"create_blend_space_1d_locomotion": _create_blend_space_1d_locomotion,
		"export_animation_tree_graph": _export_animation_tree_graph,
		"list_animation_tree_graph_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": [
			"create_animation_tree", "add_state_machine_state", "add_state_machine_transition",
			"set_blend_tree_node", "connect_blend_tree_nodes", "travel_animation_state",
			"get_animation_tree_structure",
		],
		"flow": [
			"create_simple_locomotion_tree (Idle/Walk/Run recipe)",
			"OR create_blend_space_1d_locomotion",
			"export_animation_tree_graph for agent inspection",
			"travel_animation_state / set_tree_parameter",
		],
	})


func _find_tree(path: String) -> AnimationTree:
	var n := find_node_by_path(path)
	if n is AnimationTree:
		return n as AnimationTree
	return null


func _resolve_sm(tree: AnimationTree, sm_path: String) -> Array:
	var root := tree.tree_root
	if not root is AnimationNodeStateMachine:
		return [null, error_invalid_params("tree root is not AnimationNodeStateMachine")]
	if sm_path.is_empty() or sm_path == ".":
		return [root as AnimationNodeStateMachine, null]
	var current: AnimationNodeStateMachine = root as AnimationNodeStateMachine
	for part in sm_path.split("/"):
		if not current.has_node(StringName(part)):
			return [null, error_not_found("SM node %s" % part)]
		var child := current.get_node(StringName(part))
		if not child is AnimationNodeStateMachine:
			return [null, error_invalid_params("%s not StateMachine" % part)]
		current = child as AnimationNodeStateMachine
	return [current, null]


func _set_state_machine_node_position(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var state_r := require_string(params, "state_name")
	if state_r[1] != null:
		return state_r[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var sm_r := _resolve_sm(tree, optional_string(params, "state_machine_path", ""))
	if sm_r[1] != null:
		return sm_r[1]
	var sm: AnimationNodeStateMachine = sm_r[0]
	if not sm.has_node(StringName(state_r[0])):
		return error_not_found("State %s" % state_r[0])
	var x: float = float(params.get("x", params.get("position_x", 0)))
	var y: float = float(params.get("y", params.get("position_y", 0)))
	sm.set_node_position(StringName(state_r[0]), Vector2(x, y))
	mark_current_scene_unsaved()
	return success({"state_name": state_r[0], "position": {"x": x, "y": y}})


func _set_state_animation(params: Dictionary) -> Dictionary:
	## Set animation name on an AnimationNodeAnimation state.
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var state_r := require_string(params, "state_name")
	if state_r[1] != null:
		return state_r[1]
	var anim_r := require_string(params, "animation")
	if anim_r[1] != null:
		return anim_r[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var sm_r := _resolve_sm(tree, optional_string(params, "state_machine_path", ""))
	if sm_r[1] != null:
		return sm_r[1]
	var sm: AnimationNodeStateMachine = sm_r[0]
	if not sm.has_node(StringName(state_r[0])):
		return error_not_found("State")
	var node := sm.get_node(StringName(state_r[0]))
	if not node is AnimationNodeAnimation:
		return error_invalid_params("State is %s, not AnimationNodeAnimation" % node.get_class())
	var an := node as AnimationNodeAnimation
	var old := str(an.animation)
	an.animation = StringName(anim_r[0])
	mark_current_scene_unsaved()
	return success({"state_name": state_r[0], "animation": anim_r[0], "old": old})


func _list_state_machine_transitions(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var sm_r := _resolve_sm(tree, optional_string(params, "state_machine_path", ""))
	if sm_r[1] != null:
		return sm_r[1]
	var sm: AnimationNodeStateMachine = sm_r[0]
	var out: Array = []
	for i in sm.get_transition_count():
		var trans := sm.get_transition(i)
		out.append({
			"index": i,
			"from": str(sm.get_transition_from(i)),
			"to": str(sm.get_transition_to(i)),
			"switch_mode": trans.switch_mode,
			"advance_mode": trans.advance_mode,
			"xfade_time": trans.xfade_time,
			"advance_expression": trans.advance_expression,
			"priority": trans.priority if "priority" in trans else 0,
		})
	return success({"transitions": out, "count": out.size()})


func _get_blend_tree_connections(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bt_state: String = optional_string(params, "blend_tree_state", "")
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var bt: AnimationNodeBlendTree = null
	if bt_state.is_empty():
		if tree.tree_root is AnimationNodeBlendTree:
			bt = tree.tree_root as AnimationNodeBlendTree
		else:
			return error_invalid_params("blend_tree_state required when root is not BlendTree")
	else:
		var sm_r := _resolve_sm(tree, optional_string(params, "state_machine_path", ""))
		if sm_r[1] != null:
			return sm_r[1]
		var sm: AnimationNodeStateMachine = sm_r[0]
		if not sm.has_node(StringName(bt_state)):
			return error_not_found("BlendTree state")
		var n := sm.get_node(StringName(bt_state))
		if not n is AnimationNodeBlendTree:
			return error_invalid_params("Not a BlendTree")
		bt = n as AnimationNodeBlendTree

	# Connections stored in properties as node_connections
	var connections: Array = []
	var nodes: Array = []
	for prop in bt.get_property_list():
		var pname: String = prop["name"]
		if pname.begins_with("nodes/") and pname.ends_with("/node"):
			var nm := pname.get_slice("/", 1)
			nodes.append(nm)
	# Godot BlendTree: get_node_list not always available — use connect_node graph
	# Read "node_connections" array property if present
	if bt.get("node_connections") != null:
		var nc = bt.get("node_connections")
		if nc is Array:
			for c in nc:
				connections.append(c)
	# Also try iterative: for each input port of each node
	for nm in nodes:
		if not bt.has_node(StringName(nm)):
			continue
		var child: AnimationNode = bt.get_node(StringName(nm))
		var input_count := 0
		if child.has_method("get_input_count"):
			input_count = child.get_input_count()
		elif child is AnimationNodeBlend2 or child is AnimationNodeAdd2:
			input_count = 2
		elif child is AnimationNodeBlend3 or child is AnimationNodeAdd3:
			input_count = 3
		elif child is AnimationNodeOneShot:
			input_count = 2
		elif child is AnimationNodeTimeScale or child is AnimationNodeTimeSeek:
			input_count = 1
		# output is special sink
		for port in range(maxi(input_count, 4)):
			# No public get_connection API in all versions — property scan
			pass
	# Property-based connection dump
	for prop in bt.get_property_list():
		var pn: String = prop["name"]
		if "connection" in pn.to_lower():
			connections.append({"property": pn, "value": str(bt.get(pn))})

	return success({
		"nodes": nodes,
		"connections_raw": connections,
		"hint": "Use connect_blend_tree_nodes to wire; connections_raw is best-effort property dump",
	})


func _disconnect_blend_tree_nodes(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var bt_state_r := require_string(params, "blend_tree_state")
	if bt_state_r[1] != null:
		# allow empty if root blend tree
		if optional_string(params, "blend_tree_state", "") != "":
			return bt_state_r[1]
	var input_node: String = optional_string(params, "input_node", optional_string(params, "to_node", ""))
	var input_port: int = optional_int(params, "input_port", optional_int(params, "to_port", 0))
	if input_node.is_empty():
		return error_invalid_params("input_node (to_node) required")
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var bt: AnimationNodeBlendTree
	var bt_state: String = optional_string(params, "blend_tree_state", "")
	if bt_state.is_empty() and tree.tree_root is AnimationNodeBlendTree:
		bt = tree.tree_root as AnimationNodeBlendTree
	else:
		var sm_r := _resolve_sm(tree, optional_string(params, "state_machine_path", ""))
		if sm_r[1] != null:
			return sm_r[1]
		var sm: AnimationNodeStateMachine = sm_r[0]
		if not sm.has_node(StringName(bt_state)):
			return error_not_found("BlendTree state")
		bt = sm.get_node(StringName(bt_state)) as AnimationNodeBlendTree
	if bt == null:
		return error_not_found("BlendTree")
	if bt.has_method("disconnect_node"):
		bt.disconnect_node(StringName(input_node), input_port)
		mark_current_scene_unsaved()
		return success({"disconnected": true, "input_node": input_node, "input_port": input_port})
	return error_internal("disconnect_node not available")


func _create_simple_locomotion_tree(params: Dictionary) -> Dictionary:
	## Recipe: AnimationTree + StateMachine with Idle/Walk/Run (+ optional Jump) and Start transitions.
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var anim_player: String = optional_string(params, "anim_player", "")
	var idle_anim: String = optional_string(params, "idle", "Idle")
	var walk_anim: String = optional_string(params, "walk", "Walk")
	var run_anim: String = optional_string(params, "run", "Run")
	var jump_anim: String = optional_string(params, "jump", "")
	var xfade: float = float(params.get("xfade_time", 0.15))

	var tree := AnimationTree.new()
	tree.name = optional_string(params, "name", "AnimationTree")
	var sm := AnimationNodeStateMachine.new()
	tree.tree_root = sm
	if not anim_player.is_empty():
		tree.anim_player = NodePath(anim_player)

	var states := [
		{"name": "Idle", "anim": idle_anim, "pos": Vector2(200, 100)},
		{"name": "Walk", "anim": walk_anim, "pos": Vector2(400, 100)},
		{"name": "Run", "anim": run_anim, "pos": Vector2(600, 100)},
	]
	if not jump_anim.is_empty():
		states.append({"name": "Jump", "anim": jump_anim, "pos": Vector2(400, 250)})

	for s in states:
		var an := AnimationNodeAnimation.new()
		an.animation = StringName(str(s["anim"]))
		sm.add_node(StringName(str(s["name"])), an, s["pos"])

	# Start → Idle
	var t0 := AnimationNodeStateMachineTransition.new()
	t0.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	t0.xfade_time = xfade
	sm.add_transition(&"Start", &"Idle", t0)

	# Bidirectional Idle↔Walk↔Run
	for pair in [["Idle", "Walk"], ["Walk", "Idle"], ["Walk", "Run"], ["Run", "Walk"], ["Idle", "Run"], ["Run", "Idle"]]:
		var tr := AnimationNodeStateMachineTransition.new()
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		tr.xfade_time = xfade
		sm.add_transition(StringName(pair[0]), StringName(pair[1]), tr)

	if not jump_anim.is_empty():
		for from_s in ["Idle", "Walk", "Run"]:
			var tj := AnimationNodeStateMachineTransition.new()
			tj.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			tj.xfade_time = xfade
			sm.add_transition(StringName(from_s), &"Jump", tj)
			var tb := AnimationNodeStateMachineTransition.new()
			tb.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			tb.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
			tb.xfade_time = xfade
			sm.add_transition(&"Jump", StringName(from_s), tb)

	if sm.has_method("set_start_node"):
		sm.set_start_node(&"Idle")

	add_child_with_undo(parent, tree, root, "MCP: Locomotion AnimationTree")
	if optional_bool(params, "active", true):
		tree.active = true

	var state_names: Array = []
	for s in states:
		state_names.append(str(s["name"]))
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(tree)),
		"states": state_names,
		"anim_player": anim_player,
		"hint": "travel_animation_state to_state=Walk; set_tree_parameter for custom blends",
	})


func _create_blend_space_1d_locomotion(params: Dictionary) -> Dictionary:
	## Recipe: single BlendSpace1D (speed axis) with Idle/Walk/Run points under StateMachine or as root.
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var anim_player: String = optional_string(params, "anim_player", "")
	var idle_anim: String = optional_string(params, "idle", "Idle")
	var walk_anim: String = optional_string(params, "walk", "Walk")
	var run_anim: String = optional_string(params, "run", "Run")

	var tree := AnimationTree.new()
	tree.name = optional_string(params, "name", "AnimationTree")
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = float(params.get("min_space", 0.0))
	bs.max_space = float(params.get("max_space", 1.0))
	# Points: position on blend axis
	var idle_n := AnimationNodeAnimation.new()
	idle_n.animation = StringName(idle_anim)
	var walk_n := AnimationNodeAnimation.new()
	walk_n.animation = StringName(walk_anim)
	var run_n := AnimationNodeAnimation.new()
	run_n.animation = StringName(run_anim)
	bs.add_blend_point(idle_n, float(params.get("idle_pos", 0.0)))
	bs.add_blend_point(walk_n, float(params.get("walk_pos", 0.5)))
	bs.add_blend_point(run_n, float(params.get("run_pos", 1.0)))

	if optional_bool(params, "wrap_state_machine", true):
		var sm := AnimationNodeStateMachine.new()
		sm.add_node(&"Locomotion", bs, Vector2(300, 100))
		var t0 := AnimationNodeStateMachineTransition.new()
		t0.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		sm.add_transition(&"Start", &"Locomotion", t0)
		tree.tree_root = sm
	else:
		tree.tree_root = bs

	if not anim_player.is_empty():
		tree.anim_player = NodePath(anim_player)
	add_child_with_undo(parent, tree, root, "MCP: BlendSpace1D locomotion tree")
	if optional_bool(params, "active", true):
		tree.active = true
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(tree)),
		"blend_parameter": "parameters/Locomotion/blend_position" if optional_bool(params, "wrap_state_machine", true) else "parameters/blend_position",
		"hint": "set_tree_parameter parameter=Locomotion/blend_position value=0.7",
	})


func _export_animation_tree_graph(params: Dictionary) -> Dictionary:
	## Full serializable graph dump for agents (states, positions, transitions, blend points).
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var tree := _find_tree(r0[0])
	if tree == null:
		return error_not_found("AnimationTree")
	var graph := {
		"node_path": r0[0],
		"active": tree.active,
		"anim_player": str(tree.anim_player),
		"root": _export_node(tree.tree_root),
	}
	# Mermaid optional
	if optional_bool(params, "mermaid", true) and tree.tree_root is AnimationNodeStateMachine:
		graph["mermaid"] = _sm_to_mermaid(tree.tree_root as AnimationNodeStateMachine)
	return success(graph)


func _export_node(node: AnimationNode) -> Dictionary:
	if node == null:
		return {"type": null}
	if node is AnimationNodeStateMachine:
		var sm := node as AnimationNodeStateMachine
		var states: Array = []
		for prop in sm.get_property_list():
			var pname: String = prop["name"]
			if pname.begins_with("states/") and pname.ends_with("/node"):
				var sn := pname.get_slice("/", 1)
				if sn in ["Start", "End"]:
					continue
				var child := sm.get_node(StringName(sn))
				var pos := sm.get_node_position(StringName(sn))
				var info := {"name": sn, "position": {"x": pos.x, "y": pos.y}}
				info.merge(_export_node(child))
				states.append(info)
		var transitions: Array = []
		for i in sm.get_transition_count():
			var tr := sm.get_transition(i)
			transitions.append({
				"from": str(sm.get_transition_from(i)),
				"to": str(sm.get_transition_to(i)),
				"switch_mode": tr.switch_mode,
				"advance_mode": tr.advance_mode,
				"xfade_time": tr.xfade_time,
				"advance_expression": tr.advance_expression,
			})
		return {"type": "AnimationNodeStateMachine", "states": states, "transitions": transitions}
	if node is AnimationNodeAnimation:
		return {"type": "AnimationNodeAnimation", "animation": str((node as AnimationNodeAnimation).animation)}
	if node is AnimationNodeBlendSpace1D:
		var bs := node as AnimationNodeBlendSpace1D
		var pts: Array = []
		for i in bs.get_blend_point_count():
			var bn := bs.get_blend_point_node(i)
			var pos := bs.get_blend_point_position(i)
			pts.append({"position": pos, "node": _export_node(bn)})
		return {
			"type": "AnimationNodeBlendSpace1D",
			"min_space": bs.min_space,
			"max_space": bs.max_space,
			"points": pts,
		}
	if node is AnimationNodeBlendSpace2D:
		var bs2 := node as AnimationNodeBlendSpace2D
		var pts2: Array = []
		for i in bs2.get_blend_point_count():
			var bn2 := bs2.get_blend_point_node(i)
			var pos2 := bs2.get_blend_point_position(i)
			pts2.append({"position": {"x": pos2.x, "y": pos2.y}, "node": _export_node(bn2)})
		return {"type": "AnimationNodeBlendSpace2D", "points": pts2}
	if node is AnimationNodeBlendTree:
		var bt := node as AnimationNodeBlendTree
		var nodes: Array = []
		for prop in bt.get_property_list():
			var pn: String = prop["name"]
			if pn.begins_with("nodes/") and pn.ends_with("/node"):
				var nn := pn.get_slice("/", 1)
				if nn == "output":
					continue
				var ch := bt.get_node(StringName(nn))
				var p := bt.get_node_position(StringName(nn))
				var ni := {"name": nn, "position": {"x": p.x, "y": p.y}}
				ni.merge(_export_node(ch))
				nodes.append(ni)
		return {"type": "AnimationNodeBlendTree", "nodes": nodes}
	return {"type": node.get_class()}


func _sm_to_mermaid(sm: AnimationNodeStateMachine) -> String:
	var lines: PackedStringArray = ["stateDiagram-v2"]
	for i in sm.get_transition_count():
		var f := str(sm.get_transition_from(i))
		var t := str(sm.get_transition_to(i))
		var tr := sm.get_transition(i)
		var label := ""
		if not tr.advance_expression.is_empty():
			label = " : %s" % tr.advance_expression
		lines.append("    %s --> %s%s" % [f, t, label])
	return "\n".join(lines)
