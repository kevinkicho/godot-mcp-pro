@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Engine / OS / Time / Display / Project snapshot for agent diagnostics.


func get_commands() -> Dictionary:
	return {
		"get_engine_info": _get_engine_info,
		"get_os_info": _get_os_info,
		"get_time_info": _get_time_info,
		"get_project_feature_tags": _get_features,
		"get_agent_environment_report": _get_agent_report,
		"list_engine_runtime_info_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["health_check", "get_project_info", "get_display_info", "get_performance_monitors"],
	})


func _get_engine_info(_params: Dictionary) -> Dictionary:
	return success({
		"version": Engine.get_version_info(),
		"author_info": Engine.get_author_info() if Engine.has_method("get_author_info") else {},
		"license_info": Engine.get_license_info() if Engine.has_method("get_license_info") else {},
		"is_editor_hint": Engine.is_editor_hint(),
		"max_fps": Engine.max_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"time_scale": Engine.time_scale,
		"frames_per_second": Engine.get_frames_per_second(),
		"process_frames": Engine.get_process_frames(),
		"physics_frames": Engine.get_physics_frames(),
		"main_loop_type": Engine.get_main_loop().get_class() if Engine.get_main_loop() else "",
		"singleton_list_sample": Engine.get_singleton_list().slice(0, mini(30, Engine.get_singleton_list().size())) if Engine.has_method("get_singleton_list") else [],
	})


func _get_os_info(_params: Dictionary) -> Dictionary:
	return success({
		"name": OS.get_name(),
		"distribution_name": OS.get_distribution_name() if OS.has_method("get_distribution_name") else "",
		"version": OS.get_version() if OS.has_method("get_version") else "",
		"cmdline_args": OS.get_cmdline_args(),
		"executable_path": OS.get_executable_path(),
		"user_data_dir": OS.get_user_data_dir(),
		"data_dir": OS.get_data_dir(),
		"config_dir": OS.get_config_dir(),
		"cache_dir": OS.get_cache_dir(),
		"model_name": OS.get_model_name() if OS.has_method("get_model_name") else "",
		"processor_count": OS.get_processor_count(),
		"processor_name": OS.get_processor_name() if OS.has_method("get_processor_name") else "",
		"static_memory_usage": OS.get_static_memory_usage(),
		"static_memory_peak": OS.get_static_memory_peak_usage(),
		"locale": OS.get_locale(),
		"locale_language": OS.get_locale_language() if OS.has_method("get_locale_language") else "",
		"is_debug_build": OS.is_debug_build(),
		"is_userfs_persistent": OS.is_userfs_persistent() if OS.has_method("is_userfs_persistent") else true,
		"granted_permissions": OS.get_granted_permissions() if OS.has_method("get_granted_permissions") else [],
	})


func _get_time_info(_params: Dictionary) -> Dictionary:
	var unix := Time.get_unix_time_from_system()
	return success({
		"unix_time": unix,
		"datetime_string": Time.get_datetime_string_from_system(false, true),
		"date_dict": Time.get_date_dict_from_system(),
		"time_dict": Time.get_time_dict_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"ticks_usec": Time.get_ticks_usec(),
	})


func _get_features(_params: Dictionary) -> Dictionary:
	var tags: Array = []
	# Common feature tags agents care about
	var candidates := [
		"editor", "template", "debug", "release", "pc", "mobile", "web",
		"windows", "linux", "macos", "android", "ios",
		"double", "single", "64", "32",
		"movie", "dedicated_server",
	]
	for t in candidates:
		if OS.has_feature(t):
			tags.append(t)
	return success({
		"active_features": tags,
		"has_feature_editor": OS.has_feature("editor"),
		"has_feature_web": OS.has_feature("web"),
		"has_feature_mobile": OS.has_feature("mobile"),
	})


func _get_agent_report(_params: Dictionary) -> Dictionary:
	## One-shot environment dump for agent session start.
	var engine := _get_engine_info({})
	var os := _get_os_info({})
	var time := _get_time_info({})
	var features := _get_features({})
	var project := {
		"name": ProjectSettings.get_setting("application/config/name", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
		"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode", ""),
		"physics_ticks": ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60),
	}
	var root := get_edited_root()
	var scene := {}
	if root:
		scene = {
			"root_name": root.name,
			"root_class": root.get_class(),
			"scene_file_path": root.scene_file_path,
			"child_count": root.get_child_count(),
		}
	return success({
		"engine": engine.get("result", engine),
		"os": os.get("result", os),
		"time": time.get("result", time),
		"features": features.get("result", features),
		"project": project,
		"edited_scene": scene,
		"plugin_hint": "health_check + agent_ensure_ready for production readiness",
	})
