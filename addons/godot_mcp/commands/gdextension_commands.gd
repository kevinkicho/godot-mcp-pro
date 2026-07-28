@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## GDExtension scaffold — project-neutral C++/extension starter files.


func get_commands() -> Dictionary:
	return {
		"create_gdextension_project": _create_gdextension_project,
		"list_gdextension_files": _list_gdextension_files,
		"get_gdextension_info": _get_gdextension_info,
		"run_gdextension_scons_build": _run_gdextension_scons_build,
	}


func _list_gdextension_files(_params: Dictionary) -> Dictionary:
	var files: Array = []
	_scan("res://", ".gdextension", files, 50)
	return success({"files": files, "count": files.size()})


func _scan(dir_path: String, ext: String, out: Array, max_n: int) -> void:
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
		var full := ("res://" + name) if dir_path == "res://" else dir_path.rstrip("/") + "/" + name
		if dir.current_is_dir():
			if name != ".godot":
				_scan(full, ext, out, max_n)
		elif name.ends_with(ext):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _get_gdextension_info(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		var files: Array = []
		_scan("res://", ".gdextension", files, 20)
		return success({"gdextension_files": files, "count": files.size()})
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if not FileAccess.file_exists(path):
		return error_not_found(path)
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return error_internal("Failed to parse %s" % path)
	var libs := {}
	if cfg.has_section("libraries"):
		for k in cfg.get_section_keys("libraries"):
			libs[k] = cfg.get_value("libraries", k)
	var entry := ""
	if cfg.has_section_key("configuration", "entry_symbol"):
		entry = str(cfg.get_value("configuration", "entry_symbol"))
	return success({
		"path": path,
		"entry_symbol": entry,
		"libraries": libs,
		"compatibility_minimum": cfg.get_value("configuration", "compatibility_minimum", ""),
	})


func _create_gdextension_project(params: Dictionary) -> Dictionary:
	## Scaffold extension/ folder with .gdextension, register_types, example class, SConstruct stub.
	var name_r := require_string(params, "name")
	if name_r[1] != null:
		return name_r[1]
	var ext_name: String = str(name_r[0]).to_lower().replace(" ", "_").validate_filename()
	if ext_name.is_empty():
		ext_name = "myextension"
	var class_name_str: String = optional_string(params, "class_name", ext_name.capitalize().replace("_", ""))
	if not class_name_str.is_valid_identifier():
		class_name_str = "ExampleClass"
	var folder: String = optional_string(params, "folder", "res://extension")
	if not folder.begins_with("res://"):
		folder = "res://" + folder.trim_prefix("/")
	folder = folder.rstrip("/")
	var src_dir := folder + "/src"
	var bin_dir := folder + "/bin"
	var abs_folder := ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(src_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bin_dir))

	var entry_symbol: String = optional_string(params, "entry_symbol", ext_name + "_library_init")
	var compat: String = optional_string(params, "compatibility_minimum", "4.2")

	# .gdextension
	var gde_path := folder + "/%s.gdextension" % ext_name
	var gde := """[configuration]

entry_symbol = "%s"
compatibility_minimum = "%s"
reloadable = true

[libraries]

macos.debug = "res://extension/bin/lib%s.macos.template_debug.framework"
macos.release = "res://extension/bin/lib%s.macos.template_release.framework"
windows.debug.x86_64 = "res://extension/bin/lib%s.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://extension/bin/lib%s.windows.template_release.x86_64.dll"
linux.debug.x86_64 = "res://extension/bin/lib%s.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://extension/bin/lib%s.linux.template_release.x86_64.so"
android.debug.arm64 = "res://extension/bin/lib%s.android.template_debug.arm64.so"
android.release.arm64 = "res://extension/bin/lib%s.android.template_release.arm64.so"
""" % [entry_symbol, compat, ext_name, ext_name, ext_name, ext_name, ext_name, ext_name, ext_name, ext_name]
	# Fix paths if folder != res://extension
	if folder != "res://extension":
		gde = gde.replace("res://extension/", folder + "/")
	_write(gde_path, gde)

	# register_types.hpp / cpp
	_write(src_dir + "/register_types.h", """#pragma once
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_%s_module(ModuleInitializationLevel p_level);
void uninitialize_%s_module(ModuleInitializationLevel p_level);
""" % [ext_name, ext_name])

	_write(src_dir + "/register_types.cpp", """#include "register_types.h"
#include "%s.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_%s_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<%s>();
}

void uninitialize_%s_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT %s(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_%s_module);
	init_obj.register_terminator(uninitialize_%s_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
""" % [class_name_str.to_lower(), ext_name, class_name_str, ext_name, entry_symbol, ext_name, ext_name])

	# Example class
	var hdr := class_name_str.to_lower() + ".h"
	var src := class_name_str.to_lower() + ".cpp"
	_write(src_dir + "/" + hdr, """#pragma once
#include <godot_cpp/classes/node.hpp>

using namespace godot;

class %s : public Node {
	GDCLASS(%s, Node)

protected:
	static void _bind_methods();

public:
	%s();
	~%s();

	void _ready() override;
};
""" % [class_name_str, class_name_str, class_name_str, class_name_str])

	_write(src_dir + "/" + src, """#include "%s"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void %s::_bind_methods() {
}

%s::%s() {}
%s::~%s() {}

void %s::_ready() {
	UtilityFunctions::print("%s ready (GDExtension)");
}
""" % [hdr, class_name_str, class_name_str, class_name_str, class_name_str, class_name_str, class_name_str, class_name_str])

	# SConstruct stub (godot-cpp style)
	var scons := """#!/usr/bin/env python
# Minimal SConstruct stub — clone godot-cpp next to this file.
# https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html

env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")
library = env.SharedLibrary(
    "bin/lib%s{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
    source=sources,
)
Default(library)
""" % ext_name
	_write(folder + "/SConstruct", scons)

	# README
	_write(folder + "/README_GDEXTENSION.md", """# %s GDExtension (MCP scaffold)

## Next steps (human / agent)

1. Clone **godot-cpp** into `%s/godot-cpp` matching your Godot version.
2. Install SCons + a C++ toolchain (MSVC / clang / gcc).
3. Build: `scons platform=windows target=template_debug` (adjust platform).
4. Open this Godot project — the `%s.gdextension` file loads binaries from `bin/`.
5. Use the registered class `%s` from the Create Node dialog after reload.

This is a **starter skeleton**, not a full build system.
""" % [ext_name, folder, ext_name, class_name_str])

	EditorInterface.get_resource_filesystem().scan()
	return success({
		"folder": folder,
		"gdextension": gde_path,
		"entry_symbol": entry_symbol,
		"class_name": class_name_str,
		"files": [
			gde_path,
			src_dir + "/register_types.h",
			src_dir + "/register_types.cpp",
			src_dir + "/" + hdr,
			src_dir + "/" + src,
			folder + "/SConstruct",
			folder + "/README_GDEXTENSION.md",
		],
		"hint": "Build shared libraries into bin/ then reload project. Requires godot-cpp + SCons.",
	})


func _write(path: String, content: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()


func _run_gdextension_scons_build(params: Dictionary) -> Dictionary:
	## Run `scons` in an extension folder (requires SCons + toolchain + godot-cpp present).
	var folder: String = optional_string(params, "folder", "res://extension")
	if not folder.begins_with("res://"):
		folder = "res://" + folder.trim_prefix("/")
	var abs_dir := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return error_not_found(folder, "create_gdextension_project first")
	var scons_file := abs_dir.path_join("SConstruct")
	if not FileAccess.file_exists(scons_file) and not FileAccess.file_exists(folder.path_join("SConstruct")):
		return error_not_found("SConstruct in %s" % folder)
	var platform: String = optional_string(params, "platform", "")
	if platform.is_empty():
		match OS.get_name():
			"Windows":
				platform = "windows"
			"macOS":
				platform = "macos"
			_:
				platform = "linux"
	var target: String = optional_string(params, "target", "template_debug")
	var args := PackedStringArray(["platform=%s" % platform, "target=%s" % target])
	if optional_bool(params, "compiledb", false):
		args.append("compiledb=yes")
	# Prefer scons on PATH; allow custom
	var scons_cmd: String = optional_string(params, "scons", "scons")
	var output: Array = []
	# OS.execute doesn't set cwd on all platforms equally — use shell
	var shell_cmd: String
	var shell_args: PackedStringArray
	if OS.get_name() == "Windows":
		shell_cmd = "cmd"
		shell_args = PackedStringArray(["/C", "cd /d \"%s\" && %s %s" % [abs_dir, scons_cmd, " ".join(args)]])
	else:
		shell_cmd = "bash"
		shell_args = PackedStringArray(["-lc", "cd '%s' && %s %s" % [abs_dir, scons_cmd, " ".join(args)]])
	var exit_code: int = OS.execute(shell_cmd, shell_args, output, true, false)
	var log_text := "\n".join(PackedStringArray(output))
	return success({
		"folder": folder,
		"absolute": abs_dir,
		"platform": platform,
		"target": target,
		"exit_code": exit_code,
		"ok": exit_code == 0,
		"output": log_text,
		"hint": "godot-cpp must exist under the extension folder. Clone matching Godot version before building.",
	})
