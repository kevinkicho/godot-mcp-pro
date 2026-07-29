@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## DisplayServer / window project settings - platform window surface for agents.


func get_commands() -> Dictionary:
	return {
		"get_display_info": _get_display_info,
		"set_window_project_settings": _set_window_project_settings,
		"set_window_mode_live": _set_window_mode_live,
		"list_screens": _list_screens,
		"list_display_window_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["scaffold_project_defaults", "set_project_setting", "create_settings_manager_script"],
	})


func _get_display_info(_params: Dictionary) -> Dictionary:
	return success({
		"screen_count": DisplayServer.get_screen_count(),
		"primary_screen": DisplayServer.get_primary_screen() if DisplayServer.has_method("get_primary_screen") else 0,
		"window_mode": DisplayServer.window_get_mode(),
		"window_size": {
			"x": DisplayServer.window_get_size().x,
			"y": DisplayServer.window_get_size().y,
		},
		"window_position": {
			"x": DisplayServer.window_get_position().x,
			"y": DisplayServer.window_get_position().y,
		},
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"project": {
			"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
			"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
			"mode": ProjectSettings.get_setting("display/window/size/mode", 0),
			"resizable": ProjectSettings.get_setting("display/window/size/resizable", true),
			"borderless": ProjectSettings.get_setting("display/window/size/borderless", false),
			"always_on_top": ProjectSettings.get_setting("display/window/size/always_on_top", false),
			"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode", ""),
			"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect", ""),
		},
	})


func _set_window_project_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	var map := {
		"viewport_width": "display/window/size/viewport_width",
		"viewport_height": "display/window/size/viewport_height",
		"mode": "display/window/size/mode",
		"resizable": "display/window/size/resizable",
		"borderless": "display/window/size/borderless",
		"always_on_top": "display/window/size/always_on_top",
		"transparent": "display/window/size/transparent",
		"stretch_mode": "display/window/stretch/mode",
		"stretch_aspect": "display/window/stretch/aspect",
		"stretch_scale": "display/window/stretch/scale",
	}
	for k in map:
		if params.has(k):
			ProjectSettings.set_setting(map[k], params[k])
			applied[map[k]] = params[k]
	# mode by name
	if params.has("mode_name"):
		var mn := str(params["mode_name"]).to_lower()
		var mode_i := 0
		match mn:
			"windowed":
				mode_i = 0
			"minimized":
				mode_i = 1
			"maximized":
				mode_i = 2
			"fullscreen":
				mode_i = 3
			"exclusive_fullscreen":
				mode_i = 4
		ProjectSettings.set_setting("display/window/size/mode", mode_i)
		applied["display/window/size/mode"] = mode_i
	if applied.is_empty():
		return error_invalid_params("Provide viewport_width/height, mode_name, stretch_mode, etc.")
	ProjectSettings.save()
	return success({"applied": applied})


func _set_window_mode_live(params: Dictionary) -> Dictionary:
	## Live DisplayServer (editor or when running in-process).
	var mode_name: String = optional_string(params, "mode", "windowed").to_lower()
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match mode_name:
		"fullscreen":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		"exclusive_fullscreen":
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		"maximized":
			mode = DisplayServer.WINDOW_MODE_MAXIMIZED
		"minimized":
			mode = DisplayServer.WINDOW_MODE_MINIMIZED
		_:
			mode = DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if params.has("vsync"):
		var vs: bool = bool(params["vsync"])
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vs else DisplayServer.VSYNC_DISABLED
		)
	if params.has("size") and params["size"] is Dictionary:
		var s: Dictionary = params["size"]
		DisplayServer.window_set_size(Vector2i(int(s.get("x", 1280)), int(s.get("y", 720))))
	if params.has("title"):
		DisplayServer.window_set_title(str(params["title"]))
	return success({
		"mode": mode_name,
		"window_mode_enum": DisplayServer.window_get_mode(),
		"size": {
			"x": DisplayServer.window_get_size().x,
			"y": DisplayServer.window_get_size().y,
		},
	})


func _list_screens(_params: Dictionary) -> Dictionary:
	var screens: Array = []
	var n := DisplayServer.get_screen_count()
	for i in range(n):
		var entry := {"index": i}
		if DisplayServer.has_method("screen_get_size"):
			var sz: Vector2i = DisplayServer.screen_get_size(i)
			entry["size"] = {"x": sz.x, "y": sz.y}
		if DisplayServer.has_method("screen_get_dpi"):
			entry["dpi"] = DisplayServer.screen_get_dpi(i)
		if DisplayServer.has_method("screen_get_refresh_rate"):
			entry["refresh_rate"] = DisplayServer.screen_get_refresh_rate(i)
		screens.append(entry)
	return success({"screens": screens, "count": n})
