extends Node

class_name PerformanceProfile

signal profile_changed(profile_name: String)

enum Profile {
	HIGH,
	LOW_END_PC,
	WEB
}

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "performance"
const SETTINGS_KEY_PROFILE: String = "profile"

var _profile: Profile = Profile.HIGH


func _ready() -> void:
	_profile = _load_profile()
	_apply_runtime_scaling()
	profile_changed.emit(get_profile_name())


func get_profile() -> Profile:
	return _profile


func get_profile_name() -> String:
	match _profile:
		Profile.HIGH:
			return "high"
		Profile.LOW_END_PC:
			return "low_end_pc"
		Profile.WEB:
			return "web"
	return "high"


func set_profile_by_name(profile_name: String) -> void:
	var normalized: String = profile_name.strip_edges().to_lower()
	var next: Profile = _profile
	match normalized:
		"high":
			next = Profile.HIGH
		"low", "low_end", "low_end_pc":
			next = Profile.LOW_END_PC
		"web":
			next = Profile.WEB
		_:
			return

	if next == _profile:
		return
	_profile = next
	_save_profile()
	_apply_runtime_scaling()
	profile_changed.emit(get_profile_name())


func is_web_profile() -> bool:
	return _profile == Profile.WEB


func is_low_end_profile() -> bool:
	return _profile == Profile.LOW_END_PC


func pointer_lock_requires_user_gesture() -> bool:
	return _profile == Profile.WEB


func sobel_enabled() -> bool:
	return _profile != Profile.WEB


func sky_fallback_gradient_only() -> bool:
	return _profile == Profile.WEB


func portal_fractional_scale() -> float:
	match _profile:
		Profile.HIGH:
			return 0.5
		Profile.LOW_END_PC:
			return 0.35
		Profile.WEB:
			return 0.25
	return 0.5


func portal_update_interval_frames() -> int:
	match _profile:
		Profile.HIGH:
			return 1
		Profile.LOW_END_PC:
			return 2
		Profile.WEB:
			return 3
	return 1


func portal_deactivate_distance() -> float:
	match _profile:
		Profile.HIGH:
			return 150.0
		Profile.LOW_END_PC:
			return 90.0
		Profile.WEB:
			return 65.0
	return 120.0


func should_bake_csg_runtime() -> bool:
	return _profile != Profile.HIGH


func render_scale() -> float:
	match _profile:
		Profile.HIGH:
			return 1.0
		Profile.LOW_END_PC:
			return 0.85
		Profile.WEB:
			return 0.7
	return 1.0


func _load_profile() -> Profile:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var configured: String = str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_PROFILE, ""))
		if configured != "":
			match configured.to_lower():
				"high":
					return Profile.HIGH
				"low_end_pc":
					return Profile.LOW_END_PC
				"web":
					return Profile.WEB

	if OS.has_feature("web"):
		return Profile.WEB
	if _is_probably_low_end_pc():
		return Profile.LOW_END_PC
	return Profile.HIGH


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_PROFILE, get_profile_name())
	cfg.save(SETTINGS_PATH)


func _apply_runtime_scaling() -> void:
	var root_viewport: Viewport = get_tree().root
	if root_viewport != null:
		root_viewport.set("scaling_3d_scale", render_scale())


func _is_probably_low_end_pc() -> bool:
	var model_name: String = OS.get_model_name().to_lower()
	if model_name.findn("air") != -1:
		return true
	var cpu_name: String = OS.get_processor_name().to_lower()
	return cpu_name.findn("u-") != -1
