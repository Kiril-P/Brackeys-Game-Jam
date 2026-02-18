extends Node

class_name PerformanceProfile

signal profile_changed(profile_name: String)
signal portal_runtime_quality_changed(scale: float, update_interval_frames: int)

enum Profile {
	HIGH,
	LOW_END_PC,
	WEB
}

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "performance"
const SETTINGS_KEY_PROFILE: String = "profile"
const ADAPTIVE_TARGET_FPS: float = 60.0
const ADAPTIVE_DEGRADE_FPS: float = 56.0
const ADAPTIVE_RECOVER_FPS: float = 60.0
const ADAPTIVE_EVAL_INTERVAL_SEC: float = 0.6
const ADAPTIVE_MIN_PORTAL_SCALE: float = 0.55
const ADAPTIVE_MAX_PORTAL_SCALE: float = 0.78
const ADAPTIVE_MIN_UPDATE_INTERVAL: int = 2
const ADAPTIVE_MAX_UPDATE_INTERVAL: int = 4

var _profile: Profile = Profile.HIGH
var _runtime_portal_fractional_scale: float = ADAPTIVE_MAX_PORTAL_SCALE
var _runtime_portal_update_interval_frames: int = ADAPTIVE_MIN_UPDATE_INTERVAL
var _fps_smooth: float = ADAPTIVE_TARGET_FPS
var _adaptive_timer: float = 0.0


func _ready() -> void:
	_profile = _load_profile()
	_reset_runtime_portal_quality(false)
	_apply_runtime_scaling()
	set_process(_profile == Profile.HIGH)
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
	_reset_runtime_portal_quality()
	_save_profile()
	_apply_runtime_scaling()
	set_process(_profile == Profile.HIGH)
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
			return ADAPTIVE_MAX_PORTAL_SCALE
		Profile.LOW_END_PC:
			return 0.5
		Profile.WEB:
			return 0.35
	return ADAPTIVE_MAX_PORTAL_SCALE


func portal_update_interval_frames() -> int:
	match _profile:
		Profile.HIGH:
			return ADAPTIVE_MIN_UPDATE_INTERVAL
		Profile.LOW_END_PC:
			return 2
		Profile.WEB:
			return 3
	return ADAPTIVE_MIN_UPDATE_INTERVAL


func portal_deactivate_distance() -> float:
	match _profile:
		Profile.HIGH:
			return 110.0
		Profile.LOW_END_PC:
			return 90.0
		Profile.WEB:
			return 65.0
	return 120.0


func get_portal_runtime_fractional_scale():
	return _runtime_portal_fractional_scale


func get_portal_runtime_update_interval_frames():
	return _runtime_portal_update_interval_frames


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


func _process(delta: float) -> void:
	if _profile != Profile.HIGH:
		return

	var fps_now: float = float(Engine.get_frames_per_second())
	if fps_now > 0.0:
		_fps_smooth = lerpf(_fps_smooth, fps_now, 0.2)

	_adaptive_timer += delta
	if _adaptive_timer < ADAPTIVE_EVAL_INTERVAL_SEC:
		return
	_adaptive_timer = 0.0

	var next_scale: float = _runtime_portal_fractional_scale
	var next_interval: int = _runtime_portal_update_interval_frames
	if _fps_smooth < ADAPTIVE_DEGRADE_FPS:
		next_scale = clampf(next_scale - 0.05, ADAPTIVE_MIN_PORTAL_SCALE, ADAPTIVE_MAX_PORTAL_SCALE)
		next_interval = mini(next_interval + 1, ADAPTIVE_MAX_UPDATE_INTERVAL)
	elif _fps_smooth >= ADAPTIVE_RECOVER_FPS:
		next_scale = clampf(next_scale + 0.03, ADAPTIVE_MIN_PORTAL_SCALE, ADAPTIVE_MAX_PORTAL_SCALE)
		next_interval = maxi(next_interval - 1, ADAPTIVE_MIN_UPDATE_INTERVAL)

	if not is_equal_approx(next_scale, _runtime_portal_fractional_scale) \
			or next_interval != _runtime_portal_update_interval_frames:
		_runtime_portal_fractional_scale = next_scale
		_runtime_portal_update_interval_frames = next_interval
		portal_runtime_quality_changed.emit(_runtime_portal_fractional_scale, _runtime_portal_update_interval_frames)


func _reset_runtime_portal_quality(emit_signal: bool = true) -> void:
	_runtime_portal_fractional_scale = portal_fractional_scale()
	_runtime_portal_update_interval_frames = portal_update_interval_frames()
	_fps_smooth = ADAPTIVE_TARGET_FPS
	_adaptive_timer = 0.0
	if emit_signal:
		portal_runtime_quality_changed.emit(_runtime_portal_fractional_scale, _runtime_portal_update_interval_frames)


func _is_probably_low_end_pc() -> bool:
	var model_name: String = OS.get_model_name().to_lower()
	if model_name.findn("air") != -1:
		return true
	var cpu_name: String = OS.get_processor_name().to_lower()
	return cpu_name.findn("u-") != -1
