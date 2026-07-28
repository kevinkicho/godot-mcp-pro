@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## C# / .NET Godot project helpers (Mono builds). Project-neutral.


func get_commands() -> Dictionary:
	return {
		"get_csharp_project_info": _get_csharp_project_info,
		"create_csharp_script": _create_csharp_script,
		"list_csharp_scripts": _list_csharp_scripts,
		"ensure_csharp_csproj": _ensure_csharp_csproj,
		"set_dotnet_project_settings": _set_dotnet_project_settings,
		"attach_csharp_script": _attach_csharp_script,
		"run_dotnet_build": _run_dotnet_build,
		"run_godot_csharp_build": _run_godot_csharp_build,
		"get_last_build_log": _get_last_build_log,
	}

const _BUILD_LOG_PATH := "user://mcp_last_build_log.txt"


func _project_root_abs() -> String:
	return ProjectSettings.globalize_path("res://").rstrip("/\\")


func _find_csproj_files() -> Array:
	var found: Array = []
	_scan_for_ext("res://", ".csproj", found, 50, true)
	return found


func _find_sln_files() -> Array:
	var found: Array = []
	_scan_for_ext("res://", ".sln", found, 20, true)
	return found


func _scan_for_ext(dir_path: String, ext: String, out: Array, max_n: int, skip_addons: bool) -> void:
	if out.size() >= max_n:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String
		if dir_path == "res://":
			full = "res://" + name
		else:
			full = dir_path.rstrip("/") + "/" + name
		if dir.current_is_dir():
			if name == ".godot":
				pass
			elif skip_addons and name == "addons":
				pass
			else:
				_scan_for_ext(full, ext, out, max_n, skip_addons)
		elif name.ends_with(ext):
			out.append(full)
			if out.size() >= max_n:
				break
		name = dir.get_next()
	dir.list_dir_end()


func _get_csharp_project_info(_params: Dictionary) -> Dictionary:
	var version_info: Dictionary = Engine.get_version_info()
	var features: PackedStringArray = []
	if ProjectSettings.has_setting("application/config/features"):
		var f = ProjectSettings.get_setting("application/config/features")
		if f is PackedStringArray:
			features = f
		elif f is Array:
			for x in f:
				features.append(str(x))
	var has_csharp_feature := false
	for feat in features:
		if str(feat).to_lower().contains("c#") or str(feat) == "C#":
			has_csharp_feature = true
	var csprojs := _find_csproj_files()
	var slns := _find_sln_files()
	var cs_count := 0
	var cs_files: Array = []
	_scan_for_ext("res://", ".cs", cs_files, 500, false)
	cs_count = cs_files.size()
	# Detect if this editor binary is mono
	var exe := OS.get_executable_path().to_lower()
	var looks_mono := exe.contains("mono") or exe.contains("dotnet")
	return success({
		"godot_version": version_info,
		"editor_executable": OS.get_executable_path(),
		"looks_like_mono_build": looks_mono,
		"project_features": Array(features),
		"has_csharp_feature_flag": has_csharp_feature,
		"csproj_files": csprojs,
		"solution_files": slns,
		"csharp_script_count": cs_count,
		"sample_scripts": cs_files.slice(0, mini(20, cs_files.size())),
		"dotnet_assembly_name": ProjectSettings.get_setting("dotnet/project/assembly_name", ""),
		"dotnet_solution_dir": ProjectSettings.get_setting("dotnet/project/solution_directory", ""),
		"hint": "Godot 4 C# needs a .NET-enabled editor. Use create_csharp_script / ensure_csharp_csproj for scaffolding.",
	})


func _create_csharp_script(params: Dictionary) -> Dictionary:
	var res := require_res_path(params, "path")
	if res[1] != null:
		return res[1]
	var path: String = res[0]
	if not path.ends_with(".cs"):
		path += ".cs"
	if FileAccess.file_exists(path) and not optional_bool(params, "overwrite", false):
		return error(-32000, "File exists: %s" % path, {"suggestion": "overwrite=true"})
	var class_name_str: String = optional_string(params, "class_name", path.get_file().get_basename())
	# Sanitize C# class name
	class_name_str = class_name_str.replace(" ", "").replace("-", "_")
	if class_name_str.is_empty() or not class_name_str.is_valid_identifier():
		class_name_str = "NewScript"
	var base: String = optional_string(params, "extends", optional_string(params, "base", "Node"))
	var ns: String = optional_string(params, "namespace", "")
	var content: String = optional_string(params, "content", "")
	if content.is_empty():
		var body := ""
		if not ns.is_empty():
			body += "namespace %s;\n\n" % ns
		body += """using Godot;

public partial class %s : %s
{
	public override void _Ready()
	{
		// Called when the node enters the scene tree.
	}

	public override void _Process(double delta)
	{
		// Called every frame.
	}
}
""" % [class_name_str, base]
		content = body
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
		"class_name": class_name_str,
		"base": base,
		"namespace": ns,
		"created": true,
		"hint": "Build the C# project (Godot Build button / dotnet build) before attaching if needed.",
	})


func _list_csharp_scripts(params: Dictionary) -> Dictionary:
	var max_n: int = optional_int(params, "max_results", 200)
	var files: Array = []
	_scan_for_ext("res://", ".cs", files, max_n, not optional_bool(params, "include_addons", false))
	return success({"scripts": files, "count": files.size()})


func _ensure_csharp_csproj(params: Dictionary) -> Dictionary:
	## Create a minimal Godot SDK-style .csproj if none exists.
	var existing := _find_csproj_files()
	if not existing.is_empty() and not optional_bool(params, "force", false):
		return success({
			"exists": true,
			"csproj_files": existing,
			"created": false,
			"message": "csproj already present",
		})
	var proj_name: String = optional_string(params, "name", "")
	if proj_name.is_empty():
		proj_name = str(ProjectSettings.get_setting("application/config/name", "GodotGame"))
		proj_name = proj_name.validate_filename().replace(" ", "")
		if proj_name.is_empty():
			proj_name = "GodotGame"
	var path: String = optional_string(params, "path", "res://%s.csproj" % proj_name)
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not path.ends_with(".csproj"):
		path += ".csproj"
	var target: String = optional_string(params, "target_framework", "net8.0")
	var godot_net_sdk: String = optional_string(params, "godot_sdk_version", "4.3.0")
	# Godot 4.x style SDK project
	var xml := """<Project Sdk="Godot.NET.Sdk/%s">
  <PropertyGroup>
    <TargetFramework>%s</TargetFramework>
    <EnableDynamicLoading>true</EnableDynamicLoading>
    <RootNamespace>%s</RootNamespace>
    <AssemblyName>%s</AssemblyName>
  </PropertyGroup>
</Project>
""" % [godot_net_sdk, target, proj_name, proj_name]
	var derr := ensure_parent_dir(path)
	if not derr.is_empty():
		return derr
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_internal("Cannot write %s" % path)
	f.store_string(xml)
	f.close()
	# Optional solution
	var sln_path := ""
	if optional_bool(params, "create_solution", true):
		sln_path = path.get_basename() + ".sln"
		# Minimal solution referencing the csproj (dotnet format simplified)
		var csproj_file := path.get_file()
		var sln := """
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 17
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "%s", "%s", "{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
EndGlobal
""" % [proj_name, csproj_file]
		var sf := FileAccess.open(sln_path, FileAccess.WRITE)
		if sf:
			sf.store_string(sln.strip_edges() + "\n")
			sf.close()
	# ProjectSettings features + assembly name
	var features = ProjectSettings.get_setting("application/config/features", PackedStringArray())
	var arr: Array = []
	if features is PackedStringArray:
		for x in features:
			arr.append(str(x))
	elif features is Array:
		arr = features.duplicate()
	if not "C#" in arr and not "c#" in arr:
		arr.append("C#")
	ProjectSettings.set_setting("application/config/features", PackedStringArray(arr))
	ProjectSettings.set_setting("dotnet/project/assembly_name", proj_name)
	ProjectSettings.save()
	EditorInterface.get_resource_filesystem().update_file(path)
	if not sln_path.is_empty():
		EditorInterface.get_resource_filesystem().update_file(sln_path)
	return success({
		"created": true,
		"csproj": path,
		"solution": sln_path,
		"assembly_name": proj_name,
		"target_framework": target,
		"hint": "Open project in a .NET Godot build; run Build to generate .godot/mono assemblies.",
	})


func _set_dotnet_project_settings(params: Dictionary) -> Dictionary:
	var applied := {}
	if params.has("assembly_name"):
		ProjectSettings.set_setting("dotnet/project/assembly_name", str(params["assembly_name"]))
		applied["dotnet/project/assembly_name"] = str(params["assembly_name"])
	if params.has("solution_directory"):
		ProjectSettings.set_setting("dotnet/project/solution_directory", str(params["solution_directory"]))
		applied["dotnet/project/solution_directory"] = str(params["solution_directory"])
	if params.has("assembly_reload_attempts"):
		ProjectSettings.set_setting("dotnet/project/assembly_reload_attempts", int(params["assembly_reload_attempts"]))
		applied["dotnet/project/assembly_reload_attempts"] = int(params["assembly_reload_attempts"])
	if optional_bool(params, "ensure_csharp_feature", false):
		var features = ProjectSettings.get_setting("application/config/features", PackedStringArray())
		var arr: Array = []
		if features is PackedStringArray:
			for x in features:
				arr.append(str(x))
		if not "C#" in arr:
			arr.append("C#")
			ProjectSettings.set_setting("application/config/features", PackedStringArray(arr))
			applied["application/config/features"] = arr
	if applied.is_empty():
		return error_invalid_params("Provide assembly_name, solution_directory, and/or ensure_csharp_feature")
	ProjectSettings.save()
	return success({"applied": applied})


func _attach_csharp_script(params: Dictionary) -> Dictionary:
	## Attach a .cs script resource to a node (same as attach_script but validates .cs).
	var node_r := require_string(params, "node_path")
	if node_r[1] != null:
		return node_r[1]
	var script_r := require_res_path(params, "script_path")
	if script_r[1] != null:
		return script_r[1]
	var path: String = script_r[0]
	if not path.ends_with(".cs"):
		return error_invalid_params("script_path must be a .cs file")
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return error_not_found(path)
	var root := get_edited_root()
	if root == null:
		return error_no_scene()
	var node := find_node_by_path(node_r[0])
	if node == null:
		return error_not_found("Node '%s'" % node_r[0])
	var scr: Script = load(path) as Script
	if scr == null:
		return error_internal("Failed to load C# script (build C# project first?): %s" % path)
	var undo := get_undo_redo()
	undo.create_action("MCP: Attach C# script")
	undo.add_do_method(node, "set_script", scr)
	undo.add_undo_method(node, "set_script", node.get_script())
	undo.commit_action()
	mark_current_scene_unsaved()
	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": path,
		"attached": true,
	})


func _run_dotnet_build(params: Dictionary) -> Dictionary:
	## Invoke `dotnet build` on the project csproj/sln (requires dotnet SDK on PATH).
	var csprojs := _find_csproj_files()
	var slns := _find_sln_files()
	var target: String = optional_string(params, "path", "")
	if target.is_empty():
		if not slns.is_empty():
			target = str(slns[0])
		elif not csprojs.is_empty():
			target = str(csprojs[0])
		else:
			return error_not_found("No .sln/.csproj — run ensure_csharp_csproj first")
	if not target.begins_with("res://"):
		if FileAccess.file_exists(target):
			pass
		else:
			target = "res://" + target.trim_prefix("/")
	var abs_target := ProjectSettings.globalize_path(target) if target.begins_with("res://") else target
	var configuration: String = optional_string(params, "configuration", "Debug")
	var args := PackedStringArray(["build", abs_target, "-c", configuration, "--nologo"])
	if optional_bool(params, "no_restore", false):
		args.append("--no-restore")
	var output: Array = []
	var exit_code: int = OS.execute("dotnet", args, output, true, false)
	var log_text := "\n".join(PackedStringArray(output))
	_save_build_log({
		"tool": "dotnet",
		"target": target,
		"exit_code": exit_code,
		"output": log_text,
	})
	return success({
		"target": target,
		"absolute": abs_target,
		"configuration": configuration,
		"exit_code": exit_code,
		"ok": exit_code == 0,
		"output": log_text,
		"errors": _extract_build_errors(log_text),
		"warnings": _extract_build_warnings(log_text),
		"hint": "If dotnet not found, install .NET SDK and ensure it is on PATH for the Godot process.",
	})


func _save_build_log(data: Dictionary) -> void:
	var payload := JSON.stringify(data, "\t")
	var f := FileAccess.open(_BUILD_LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(payload)
		f.close()


func _extract_build_errors(log_text: String) -> Array:
	var errs: Array = []
	for line in log_text.split("\n"):
		var s := line.strip_edges()
		var sl := s.to_lower()
		if sl.contains(" error ") or s.contains(": error ") or sl.begins_with("error"):
			errs.append(s)
			if errs.size() >= 40:
				break
	return errs


func _extract_build_warnings(log_text: String) -> Array:
	var warns: Array = []
	for line in log_text.split("\n"):
		var s := line.strip_edges()
		var sl := s.to_lower()
		if sl.contains(" warning ") or s.contains(": warning "):
			warns.append(s)
			if warns.size() >= 40:
				break
	return warns


func _run_godot_csharp_build(params: Dictionary) -> Dictionary:
	## Run Godot headless with --build-solutions (C# regenerate/build) when available.
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"--build-solutions",
		"--quit",
	])
	var output: Array = []
	var exit_code: int = OS.execute(godot_path, args, output, true, false)
	var log_text := "\n".join(PackedStringArray(output))
	_save_build_log({
		"tool": "godot --build-solutions",
		"godot": godot_path,
		"exit_code": exit_code,
		"output": log_text,
	})
	return success({
		"tool": "godot --build-solutions",
		"exit_code": exit_code,
		"ok": exit_code == 0,
		"output": log_text,
		"errors": _extract_build_errors(log_text),
		"warnings": _extract_build_warnings(log_text),
		"hint": "Requires .NET-enabled Godot. Prefer run_dotnet_build for explicit SDK control.",
	})


func _get_last_build_log(_params: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(_BUILD_LOG_PATH):
		return success({"exists": false, "message": "No build log yet — run_dotnet_build or run_godot_csharp_build"})
	var f := FileAccess.open(_BUILD_LOG_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		parsed["exists"] = true
		return success(parsed)
	return success({"exists": true, "raw": text})
