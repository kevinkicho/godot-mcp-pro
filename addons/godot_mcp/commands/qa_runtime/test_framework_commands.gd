@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Thin adapters over GUT / GdUnit4 — do not reinvent test frameworks.


func get_commands() -> Dictionary:
	return {
		"detect_test_frameworks": _detect_test_frameworks,
		"run_gut_tests": _run_gut_tests,
		"run_gdunit_tests": _run_gdunit_tests,
		"list_test_recipes": _list_test_recipes,
	}


func _list_test_recipes(_params: Dictionary) -> Dictionary:
	return success({
		"frameworks": {
			"GUT": "https://github.com/bitwes/Gut — GDScript unit/integration tests",
			"GdUnit4": "https://github.com/godot-gdunit-labs/gdUnit4 — editor-integrated tests",
		},
		"mcp_role": "Detect + invoke CLI; agents author tests in project. Prefer live run_session_* for interactive probe.",
		"flow": [
			"detect_test_frameworks",
			"run_gut_tests or run_gdunit_tests",
			"On failure: run_session_start + run_probe_report for live debug",
		],
	})


func _detect_test_frameworks(_params: Dictionary) -> Dictionary:
	var gut := FileAccess.file_exists("res://addons/gut/gut.gd") or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gut"))
	var gdunit := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gdUnit4")) \
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gdunit4"))
	var gut_tests: Array = []
	if gut:
		gut_tests = _list_scripts_under("res://test") + _list_scripts_under("res://tests")
	return success({
		"gut": gut,
		"gdunit4": gdunit,
		"sample_test_scripts": gut_tests.slice(0, 20),
		"godot_executable": OS.get_executable_path(),
		"project_path": ProjectSettings.globalize_path("res://"),
	})


func _list_scripts_under(res_dir: String) -> Array:
	var out: Array = []
	var abs := ProjectSettings.globalize_path(res_dir)
	if not DirAccess.dir_exists_absolute(abs):
		return out
	_walk_gd(abs, res_dir, out, 40)
	return out


func _walk_gd(abs_dir: String, res_dir: String, out: Array, max_n: int) -> void:
	if out.size() >= max_n:
		return
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while not n.is_empty() and out.size() < max_n:
		if d.current_is_dir() and not n.begins_with("."):
			_walk_gd(abs_dir.path_join(n), res_dir.path_join(n), out, max_n)
		elif n.ends_with(".gd"):
			out.append(res_dir.path_join(n))
		n = d.get_next()
	d.list_dir_end()


func _run_gut_tests(params: Dictionary) -> Dictionary:
	## Invoke Godot headless with GUT command-line interface.
	if not (FileAccess.file_exists("res://addons/gut/gut.gd") or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gut"))):
		return error(-32000, "GUT not installed in this project", {
			"suggestion": "Install GUT from Asset Library / https://github.com/bitwes/Gut",
		})
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://").rstrip("/\\")
	# Common GUT 4 CLI: -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
	var script: String = optional_string(params, "gut_script", "res://addons/gut/gut_cmdln.gd")
	if not FileAccess.file_exists(script):
		# try alternate
		if FileAccess.file_exists("res://addons/gut/gut_cmdln.gd"):
			script = "res://addons/gut/gut_cmdln.gd"
		elif FileAccess.file_exists("res://addons/gut/cli/gut_cli.gd"):
			script = "res://addons/gut/cli/gut_cli.gd"
		else:
			return error_not_found(script, "GUT cmdln script missing — check GUT version")

	var gdir: String = optional_string(params, "test_dir", "res://test")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(gdir)):
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://tests")):
			gdir = "res://tests"

	var args := PackedStringArray([
		"--headless",
		"--path", project,
		"-s", script,
		"-gdir=%s" % gdir,
		"-gexit",
	])
	if params.has("prefix"):
		args.append("-gprefix=%s" % str(params["prefix"]))
	if params.has("suffix"):
		args.append("-gsuffix=%s" % str(params["suffix"]))
	if optional_bool(params, "inner_class", false):
		pass
	# Extra passthrough
	if params.has("extra_args") and params["extra_args"] is Array:
		for a in params["extra_args"]:
			args.append(str(a))

	var output: Array = []
	var code := OS.execute(godot, args, output, true, false)
	var log_text := "\n".join(PackedStringArray(output))
	var passed := code == 0 and not log_text.contains("FAILED") and not log_text.contains("[Failed]")
	# GUT often exits 0 even with fails — scan summary
	if log_text.contains("Failures:") or log_text.contains("tests failed"):
		# try crude parse
		if log_text.contains("Failures: 0") or log_text.contains("0 failed"):
			passed = code == 0
		else:
			passed = false

	return success({
		"framework": "GUT",
		"ok": passed,
		"exit_code": code,
		"test_dir": gdir,
		"command": "%s %s" % [godot, " ".join(args)],
		"output": log_text.right(8000),
		"hint": "Author tests under res://test; use run_session_* for interactive runtime probe",
	})


func _run_gdunit_tests(params: Dictionary) -> Dictionary:
	var has := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gdUnit4")) \
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/gdunit4"))
	if not has:
		return error(-32000, "GdUnit4 not installed in this project", {
			"suggestion": "https://github.com/godot-gdunit-labs/gdUnit4",
		})
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://").rstrip("/\\")
	# GdUnit4 CLI varies by version — common pattern:
	# godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
	var candidates: Array = [
		"res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
		"res://addons/gdunit4/bin/GdUnitCmdTool.gd",
		"res://addons/gdUnit4/src/core/runners/GdUnitCommandLineTool.gd",
	]
	var script := ""
	for c in candidates:
		if FileAccess.file_exists(c):
			script = c
			break
	if script.is_empty():
		return error(-32000, "GdUnit4 CLI script not found", {
			"tried": candidates,
			"suggestion": "Open GdUnit4 docs for your version CLI, or pass script= via params",
		})
	if params.has("script"):
		script = str(params["script"])

	var args := PackedStringArray([
		"--headless",
		"--path", project,
		"-s", script,
	])
	if params.has("extra_args") and params["extra_args"] is Array:
		for a in params["extra_args"]:
			args.append(str(a))

	var output: Array = []
	var code := OS.execute(godot, args, output, true, false)
	var log_text := "\n".join(PackedStringArray(output))
	return success({
		"framework": "GdUnit4",
		"ok": code == 0,
		"exit_code": code,
		"script": script,
		"command": "%s %s" % [godot, " ".join(args)],
		"output": log_text.right(8000),
	})
