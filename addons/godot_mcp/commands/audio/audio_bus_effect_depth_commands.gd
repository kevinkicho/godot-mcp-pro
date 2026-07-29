@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Audio bus effects depth - reverb, compressor, EQ, limiter (Audio dock parity).


func get_commands() -> Dictionary:
	return {
		"list_audio_bus_effect_types": _list_types,
		"add_audio_bus_effect_typed": _add_typed,
		"set_audio_bus_effect_params": _set_effect_params,
		"list_audio_bus_effects": _list_effects,
		"remove_audio_bus_effect_at": _remove_at,
		"list_audio_bus_effect_depth_tools": _list_tools,
	}


func _list_tools(_params: Dictionary) -> Dictionary:
	return success({
		"tools": get_commands().keys(),
		"related": ["add_audio_bus", "add_audio_bus_effect", "set_audio_bus", "create_audio_manager_script"],
	})


func _list_types(_params: Dictionary) -> Dictionary:
	return success({
		"types": [
			"amplify", "reverb", "chorus", "compressor", "limiter", "distortion",
			"eq", "eq6", "eq10", "eq21", "filter", "high_pass_filter", "low_pass_filter",
			"band_pass_filter", "notch_filter", "high_shelf_filter", "low_shelf_filter",
			"panner", "phaser", "pitch_shift", "record", "spectrum_analyzer", "stereo_enhance",
			"delay",
		],
		"usage": "add_audio_bus_effect_typed bus=Master type=reverb room_size=0.8",
	})


func _bus_index(name: String) -> int:
	return AudioServer.get_bus_index(name)


func _effect_class(type_name: String) -> String:
	match type_name.to_lower():
		"amplify", "audioeffectamplify":
			return "AudioEffectAmplify"
		"reverb", "audioeffectreverb":
			return "AudioEffectReverb"
		"chorus":
			return "AudioEffectChorus"
		"compressor":
			return "AudioEffectCompressor"
		"limiter":
			return "AudioEffectLimiter"
		"distortion":
			return "AudioEffectDistortion"
		"eq", "eq6":
			return "AudioEffectEQ6"
		"eq10":
			return "AudioEffectEQ10"
		"eq21":
			return "AudioEffectEQ21"
		"filter", "high_pass_filter", "highpass":
			return "AudioEffectHighPassFilter"
		"low_pass_filter", "lowpass":
			return "AudioEffectLowPassFilter"
		"band_pass_filter", "bandpass":
			return "AudioEffectBandPassFilter"
		"notch_filter", "notch":
			return "AudioEffectNotchFilter"
		"high_shelf_filter", "highshelf":
			return "AudioEffectHighShelfFilter"
		"low_shelf_filter", "lowshelf":
			return "AudioEffectLowShelfFilter"
		"panner":
			return "AudioEffectPanner"
		"phaser":
			return "AudioEffectPhaser"
		"pitch_shift", "pitch":
			return "AudioEffectPitchShift"
		"record":
			return "AudioEffectRecord"
		"spectrum_analyzer", "spectrum":
			return "AudioEffectSpectrumAnalyzer"
		"stereo_enhance", "stereo":
			return "AudioEffectStereoEnhance"
		"delay":
			return "AudioEffectDelay"
		_:
			return ""


func _add_typed(params: Dictionary) -> Dictionary:
	var bus_name: String = optional_string(params, "bus", optional_string(params, "bus_name", "Master"))
	var idx := _bus_index(bus_name)
	if idx < 0:
		return error_not_found("Audio bus '%s'" % bus_name)
	var type_name: String = optional_string(params, "type", optional_string(params, "effect_type", ""))
	if type_name.is_empty():
		return error_invalid_params("type required - list_audio_bus_effect_types")
	var cls := _effect_class(type_name)
	if cls.is_empty() or not ClassDB.class_exists(cls):
		return error_invalid_params("Unknown or unavailable effect type '%s'" % type_name)
	var fx: AudioEffect = ClassDB.instantiate(cls)
	_apply_fx_params(fx, params)
	var at: int = optional_int(params, "at_position", -1)
	if at < 0:
		AudioServer.add_bus_effect(idx, fx)
		at = AudioServer.get_bus_effect_count(idx) - 1
	else:
		AudioServer.add_bus_effect(idx, fx, at)
	return success({
		"bus": bus_name,
		"bus_index": idx,
		"effect_index": at,
		"class": cls,
		"hint": "ProjectSettings audio bus layout may need save_audio_bus_layout to persist",
	})


func _apply_fx_params(fx: AudioEffect, params: Dictionary) -> void:
	# Common / reverb / compressor / amplify property map
	var map := {
		"volume_db": "volume_db",
		"room_size": "room_size",
		"damping": "damping",
		"spread": "spread",
		"hipass": "hipass",
		"dry": "dry",
		"wet": "wet",
		"predelay_msec": "predelay_msec",
		"predelay_feedback": "predelay_feedback",
		"threshold_db": "threshold",
		"threshold": "threshold",
		"ratio": "ratio",
		"gain": "gain",
		"attack_us": "attack_us",
		"release_ms": "release_ms",
		"mix": "mix",
		"cutoff_hz": "cutoff_hz",
		"resonance": "resonance",
		"drive": "drive",
		"ceiling_db": "ceiling_db",
		"threshold_db_limiter": "threshold_db",
		"soft_clip_db": "soft_clip_db",
		"pan": "pan",
		"pitch_scale": "pitch_scale",
		"feedback": "feedback",
		"depth": "depth",
	}
	for k in map:
		if params.has(k) and map[k] in fx:
			fx.set(map[k], params[k])
	# Direct property passthrough for advanced
	if params.has("properties") and params["properties"] is Dictionary:
		for pk in params["properties"]:
			if str(pk) in fx:
				fx.set(str(pk), params["properties"][pk])


func _set_effect_params(params: Dictionary) -> Dictionary:
	var bus_name: String = optional_string(params, "bus", "Master")
	var idx := _bus_index(bus_name)
	if idx < 0:
		return error_not_found("bus")
	var eidx: int = optional_int(params, "effect_index", 0)
	if eidx < 0 or eidx >= AudioServer.get_bus_effect_count(idx):
		return error_invalid_params("effect_index out of range")
	var fx := AudioServer.get_bus_effect(idx, eidx)
	if fx == null:
		return error_not_found("effect")
	_apply_fx_params(fx, params)
	if params.has("enabled"):
		AudioServer.set_bus_effect_enabled(idx, eidx, bool(params["enabled"]))
	return success({
		"bus": bus_name,
		"effect_index": eidx,
		"class": fx.get_class(),
		"enabled": AudioServer.is_bus_effect_enabled(idx, eidx),
	})


func _list_effects(params: Dictionary) -> Dictionary:
	var bus_name: String = optional_string(params, "bus", "Master")
	var idx := _bus_index(bus_name)
	if idx < 0:
		return error_not_found("bus")
	var effects: Array = []
	for i in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, i)
		effects.append({
			"index": i,
			"class": fx.get_class() if fx else null,
			"enabled": AudioServer.is_bus_effect_enabled(idx, i),
		})
	return success({"bus": bus_name, "effects": effects, "count": effects.size()})


func _remove_at(params: Dictionary) -> Dictionary:
	var bus_name: String = optional_string(params, "bus", "Master")
	var idx := _bus_index(bus_name)
	if idx < 0:
		return error_not_found("bus")
	var eidx: int = optional_int(params, "effect_index", -1)
	if eidx < 0:
		return error_invalid_params("effect_index required")
	AudioServer.remove_bus_effect(idx, eidx)
	return success({"bus": bus_name, "removed_index": eidx})
