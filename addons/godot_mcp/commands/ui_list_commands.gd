@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## UI list widgets — ItemList, Tree, OptionButton, PopupMenu (human populate surface).


func get_commands() -> Dictionary:
	return {
		"item_list_clear": _item_list_clear,
		"item_list_add_item": _item_list_add_item,
		"item_list_set_items": _item_list_set_items,
		"option_button_set_items": _option_button_set_items,
		"tree_clear": _tree_clear,
		"tree_add_item": _tree_add_item,
		"popup_menu_set_items": _popup_menu_set_items,
		"richtext_set_bbcode": _richtext_set_bbcode,
		"setup_window": _setup_window,
		"setup_accept_dialog": _setup_accept_dialog,
		"setup_file_dialog": _setup_file_dialog,
		"setup_subviewport": _setup_subviewport,
		"setup_video_stream_player": _setup_video_stream_player,
		"setup_progress_bar": _setup_progress_bar,
		"setup_texture_progress_bar": _setup_texture_progress_bar,
	}


func _item_list_clear(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is ItemList:
		return error_not_found("ItemList at '%s'" % r0[0])
	(node as ItemList).clear()
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "cleared": true})


func _item_list_add_item(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is ItemList:
		return error_not_found("ItemList")
	var il: ItemList = node
	var idx := il.add_item(text_r[0])
	if params.has("icon") and ResourceLoader.exists(str(params["icon"])):
		il.set_item_icon(idx, load(str(params["icon"])))
	if params.has("metadata"):
		il.set_item_metadata(idx, params["metadata"])
	if params.has("disabled"):
		il.set_item_disabled(idx, bool(params["disabled"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "index": idx, "text": text_r[0]})


func _item_list_set_items(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("'items' array of strings or {text,icon,metadata} required")
	var node := find_node_by_path(r0[0])
	if node == null or not node is ItemList:
		return error_not_found("ItemList")
	var il: ItemList = node
	il.clear()
	var count := 0
	for it in params["items"]:
		var text := ""
		if it is String:
			text = it
		elif it is Dictionary:
			text = str(it.get("text", ""))
		else:
			continue
		var idx := il.add_item(text)
		if it is Dictionary:
			if it.has("icon") and ResourceLoader.exists(str(it["icon"])):
				il.set_item_icon(idx, load(str(it["icon"])))
			if it.has("metadata"):
				il.set_item_metadata(idx, it["metadata"])
		count += 1
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "count": count})


func _option_button_set_items(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("'items' array required")
	var node := find_node_by_path(r0[0])
	if node == null or not node is OptionButton:
		return error_not_found("OptionButton")
	var ob: OptionButton = node
	ob.clear()
	for it in params["items"]:
		if it is String:
			ob.add_item(it)
		elif it is Dictionary:
			ob.add_item(str(it.get("text", "")), int(it.get("id", -1)))
	if params.has("selected"):
		ob.select(int(params["selected"]))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "count": ob.item_count})


func _tree_clear(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is Tree:
		return error_not_found("Tree")
	(node as Tree).clear()
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "cleared": true})


func _tree_add_item(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var text_r := require_string(params, "text")
	if text_r[1] != null:
		return text_r[1]
	var node := find_node_by_path(r0[0])
	if node == null or not node is Tree:
		return error_not_found("Tree")
	var tree: Tree = node
	var root_item := tree.get_root()
	if root_item == null:
		root_item = tree.create_item()
		root_item.set_text(0, optional_string(params, "root_text", "Root"))
	var parent_item := root_item
	# Optional path like "Root/Folder" to find parent by text
	var parent_path: String = optional_string(params, "parent_text_path", "")
	if not parent_path.is_empty():
		parent_item = _find_tree_item_by_path(tree, parent_path)
		if parent_item == null:
			parent_item = root_item
	var item := tree.create_item(parent_item)
	item.set_text(0, text_r[0])
	if params.has("column1"):
		item.set_text(1, str(params["column1"]))
	if params.has("metadata"):
		item.set_metadata(0, params["metadata"])
	if params.has("collapsed"):
		item.collapsed = bool(params["collapsed"])
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "text": text_r[0]})


func _find_tree_item_by_path(tree: Tree, path: String) -> TreeItem:
	var parts := path.split("/")
	var cur := tree.get_root()
	if cur == null:
		return null
	# If first part matches root text, skip it
	var start := 0
	if parts.size() > 0 and cur.get_text(0) == parts[0]:
		start = 1
	for i in range(start, parts.size()):
		var want: String = parts[i]
		var child := cur.get_first_child()
		var found: TreeItem = null
		while child:
			if child.get_text(0) == want:
				found = child
				break
			child = child.get_next()
		if found == null:
			return null
		cur = found
	return cur


func _popup_menu_set_items(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	if not params.has("items") or not params["items"] is Array:
		return error_invalid_params("'items' array required")
	var node := find_node_by_path(r0[0])
	if node == null or not node is PopupMenu:
		return error_not_found("PopupMenu")
	var pm: PopupMenu = node
	pm.clear()
	for it in params["items"]:
		if it is String:
			if it == "-":
				pm.add_separator()
			else:
				pm.add_item(it)
		elif it is Dictionary:
			if bool(it.get("separator", false)):
				pm.add_separator(str(it.get("text", "")))
			else:
				pm.add_item(str(it.get("text", "")), int(it.get("id", -1)))
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "item_count": pm.item_count})


func _richtext_set_bbcode(params: Dictionary) -> Dictionary:
	var r0 := require_string(params, "node_path")
	if r0[1] != null:
		return r0[1]
	var text_r := require_string(params, "bbcode")
	if text_r[1] != null:
		# also accept "text"
		var alt := optional_string(params, "text", "")
		if alt.is_empty():
			return text_r[1]
		text_r = [alt, null]
	var node := find_node_by_path(r0[0])
	if node == null or not node is RichTextLabel:
		return error_not_found("RichTextLabel")
	var rtl: RichTextLabel = node
	rtl.bbcode_enabled = optional_bool(params, "bbcode_enabled", true)
	rtl.text = text_r[0]
	mark_current_scene_unsaved()
	return success({"node_path": r0[0], "length": str(text_r[0]).length()})


func _setup_window(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var win := Window.new()
	win.name = optional_string(params, "name", "Window")
	win.title = optional_string(params, "title", "Window")
	win.size = Vector2i(
		int(params.get("width", 400)),
		int(params.get("height", 300))
	)
	win.visible = optional_bool(params, "visible", false)
	if params.has("transient"):
		win.transient = bool(params["transient"])
	if params.has("exclusive"):
		win.exclusive = bool(params["exclusive"])
	if params.has("unresizable"):
		win.unresizable = bool(params["unresizable"])
	add_child_with_undo(parent, win, root, "MCP: Add Window")
	return success({"node_path": str(root.get_path_to(win)), "title": win.title, "size": {"x": win.size.x, "y": win.size.y}})


func _setup_accept_dialog(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var dlg := AcceptDialog.new()
	dlg.name = optional_string(params, "name", "AcceptDialog")
	dlg.title = optional_string(params, "title", "Alert")
	dlg.dialog_text = optional_string(params, "text", optional_string(params, "dialog_text", "Message"))
	dlg.ok_button_text = optional_string(params, "ok_text", "OK")
	add_child_with_undo(parent, dlg, root, "MCP: Add AcceptDialog")
	return success({"node_path": str(root.get_path_to(dlg)), "title": dlg.title})


func _setup_file_dialog(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var dlg := FileDialog.new()
	dlg.name = optional_string(params, "name", "FileDialog")
	dlg.title = optional_string(params, "title", "Open")
	var mode_str: String = optional_string(params, "file_mode", "open_file")
	match mode_str:
		"open_files":
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		"open_dir", "open_folder":
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		"open_any":
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_ANY
		"save_file", "save":
			dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_:
			dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	if params.has("filters") and params["filters"] is Array:
		dlg.filters = PackedStringArray(params["filters"])
	elif params.has("filter"):
		dlg.filters = PackedStringArray([str(params["filter"])])
	add_child_with_undo(parent, dlg, root, "MCP: Add FileDialog")
	return success({"node_path": str(root.get_path_to(dlg)), "file_mode": mode_str})


func _setup_subviewport(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var use_container: bool = optional_bool(params, "with_container", true)
	var container: SubViewportContainer = null
	var host: Node = parent
	if use_container:
		container = SubViewportContainer.new()
		container.name = optional_string(params, "container_name", "SubViewportContainer")
		container.stretch = optional_bool(params, "stretch", true)
		add_child_with_undo(parent, container, root, "MCP: Add SubViewportContainer")
		host = container
	var sv := SubViewport.new()
	sv.name = optional_string(params, "name", "SubViewport")
	sv.size = Vector2i(int(params.get("width", 256)), int(params.get("height", 256)))
	sv.transparent_bg = optional_bool(params, "transparent_bg", false)
	sv.handle_input_locally = optional_bool(params, "handle_input_locally", true)
	if params.has("msaa_2d"):
		sv.msaa_2d = int(params["msaa_2d"])
	if host == container:
		host.add_child(sv)
		sv.owner = root
	else:
		add_child_with_undo(host, sv, root, "MCP: Add SubViewport")
	return success({
		"node_path": str(root.get_path_to(sv)),
		"container_path": str(root.get_path_to(container)) if container else "",
		"size": {"x": sv.size.x, "y": sv.size.y},
	})


func _setup_video_stream_player(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var vp := VideoStreamPlayer.new()
	vp.name = optional_string(params, "name", "VideoStreamPlayer")
	vp.autoplay = optional_bool(params, "autoplay", false)
	vp.expand = optional_bool(params, "expand", true)
	var stream_path: String = optional_string(params, "stream_path", "")
	if not stream_path.is_empty():
		if not stream_path.begins_with("res://"):
			stream_path = "res://" + stream_path.trim_prefix("/")
		if ResourceLoader.exists(stream_path):
			vp.stream = load(stream_path)
	add_child_with_undo(parent, vp, root, "MCP: Add VideoStreamPlayer")
	return success({"node_path": str(root.get_path_to(vp)), "stream_path": stream_path})


func _setup_progress_bar(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var bar := ProgressBar.new()
	bar.name = optional_string(params, "name", "ProgressBar")
	bar.min_value = float(params.get("min_value", 0))
	bar.max_value = float(params.get("max_value", 100))
	bar.value = float(params.get("value", 0))
	bar.show_percentage = optional_bool(params, "show_percentage", true)
	add_child_with_undo(parent, bar, root, "MCP: Add ProgressBar")
	return success({"node_path": str(root.get_path_to(bar)), "value": bar.value, "max_value": bar.max_value})


func _setup_texture_progress_bar(params: Dictionary) -> Dictionary:
	var parent_path: String = optional_string(params, "parent_path", ".")
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent")
	var bar := TextureProgressBar.new()
	bar.name = optional_string(params, "name", "TextureProgressBar")
	bar.min_value = float(params.get("min_value", 0))
	bar.max_value = float(params.get("max_value", 100))
	bar.value = float(params.get("value", 50))
	bar.fill_mode = int(params.get("fill_mode", TextureProgressBar.FILL_LEFT_TO_RIGHT))
	for key in ["texture_under", "texture_over", "texture_progress"]:
		var pkey := key + "_path"
		if params.has(pkey):
			var tp: String = str(params[pkey])
			if not tp.begins_with("res://"):
				tp = "res://" + tp.trim_prefix("/")
			if ResourceLoader.exists(tp):
				bar.set(key, load(tp))
	add_child_with_undo(parent, bar, root, "MCP: Add TextureProgressBar")
	return success({"node_path": str(root.get_path_to(bar)), "value": bar.value})
