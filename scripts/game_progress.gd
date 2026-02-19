extends Node

signal progression_changed()

const SAVE_PATH: String = "user://progress.cfg"
const SAVE_SECTION: String = "progress"
const LEVEL_ORDER := ["level_1", "level_2", "level_3", "level_4"]

var _unlocked: Dictionary = {}
var _completed: Dictionary = {}
var _tutorial_seen: Dictionary = {}


func _ready() -> void:
	_load_or_default()
	progression_changed.emit()


func is_unlocked(level_id: StringName) -> bool:
	return bool(_unlocked.get(String(level_id), false))


func is_completed(level_id: StringName) -> bool:
	return bool(_completed.get(String(level_id), false))


func mark_completed(level_id: StringName) -> bool:
	var key: String = String(level_id)
	if key == "":
		return false

	var changed: bool = false
	if not bool(_completed.get(key, false)):
		_completed[key] = true
		changed = true

	var next_unlock: StringName = _next_level_for(level_id)
	if next_unlock != StringName() and not is_unlocked(next_unlock):
		_unlocked[String(next_unlock)] = true
		changed = true

	if changed:
		_save()
		progression_changed.emit()
	return changed


func get_next_unlock() -> StringName:
	for i: int in LEVEL_ORDER.size():
		var level_key: StringName = StringName(LEVEL_ORDER[i])
		if is_completed(level_key):
			var next_index: int = i + 1
			if next_index < LEVEL_ORDER.size():
				var next_key: StringName = StringName(LEVEL_ORDER[next_index])
				if not is_unlocked(next_key):
					return next_key
	return StringName()


func reset_progress_for_debug() -> void:
	_set_defaults()
	_save()
	progression_changed.emit()


func has_tutorial_seen(tutorial_id: StringName) -> bool:
	return bool(_tutorial_seen.get(String(tutorial_id), false))


func mark_tutorial_seen(tutorial_id: StringName) -> bool:
	var key: String = String(tutorial_id)
	if key == "":
		return false
	if bool(_tutorial_seen.get(key, false)):
		return false
	_tutorial_seen[key] = true
	_save()
	return true


func _next_level_for(level_id: StringName) -> StringName:
	var key: String = String(level_id)
	for i: int in LEVEL_ORDER.size():
		if LEVEL_ORDER[i] != key:
			continue
		var next_index: int = i + 1
		if next_index >= LEVEL_ORDER.size():
			return StringName()
		return StringName(LEVEL_ORDER[next_index])
	return StringName()


func _load_or_default() -> void:
	var cfg := ConfigFile.new()
	var load_result: int = cfg.load(SAVE_PATH)
	if load_result != OK:
		_set_defaults()
		_save()
		return

	_set_defaults()
	_load_levels(cfg)
	_load_tutorial_seen(cfg)
	_sanitize_level_state()
	_save()


func _set_defaults() -> void:
	_unlocked.clear()
	_completed.clear()
	_tutorial_seen.clear()
	_unlocked["level_1"] = true


func _load_levels(cfg: ConfigFile) -> void:
	var unlocked_raw: Variant = cfg.get_value(SAVE_SECTION, "unlocked", PackedStringArray(["level_1"]))
	for item: String in _to_string_array(unlocked_raw):
		if LEVEL_ORDER.has(item):
			_unlocked[item] = true

	var completed_raw: Variant = cfg.get_value(SAVE_SECTION, "completed", PackedStringArray())
	for item: String in _to_string_array(completed_raw):
		if LEVEL_ORDER.has(item):
			_completed[item] = true


func _load_tutorial_seen(cfg: ConfigFile) -> void:
	var tutorial_raw: Variant = cfg.get_value(SAVE_SECTION, "tutorial_seen", PackedStringArray())
	for item: String in _to_string_array(tutorial_raw):
		if item != "":
			_tutorial_seen[item] = true


func _sanitize_level_state() -> void:
	_unlocked["level_1"] = true
	for i: int in LEVEL_ORDER.size():
		var key: String = LEVEL_ORDER[i]
		if not bool(_completed.get(key, false)):
			continue
		_unlocked[key] = true
		var next_index: int = i + 1
		if next_index < LEVEL_ORDER.size():
			_unlocked[LEVEL_ORDER[next_index]] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, "unlocked", _dict_true_keys_to_array(_unlocked, LEVEL_ORDER))
	cfg.set_value(SAVE_SECTION, "completed", _dict_true_keys_to_array(_completed, LEVEL_ORDER))
	cfg.set_value(SAVE_SECTION, "tutorial_seen", _dict_true_keys_to_array(_tutorial_seen))
	cfg.save(SAVE_PATH)


func _to_string_array(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if raw is PackedStringArray:
		for item: String in raw:
			out.append(item)
	elif raw is Array:
		for item: Variant in raw:
			if item is String:
				out.append(item)
	return out


func _dict_true_keys_to_array(dict: Dictionary, order: Array = []) -> PackedStringArray:
	var out := PackedStringArray()
	if order.size() > 0:
		for key_var: Variant in order:
			if key_var is String and bool(dict.get(key_var, false)):
				out.append(key_var)
		return out

	var keys: Array[String] = []
	for key: Variant in dict.keys():
		if not bool(dict.get(key, false)):
			continue
		if key is String:
			keys.append(key)
	keys.sort()
	for key: String in keys:
		out.append(key)
	return out
