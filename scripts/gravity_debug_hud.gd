extends CanvasLayer

@onready var gravity_label: Label = %GravityDebugLabel
@onready var subtitle_label: Label = %CompanionSubtitleLabel

const UPDATE_INTERVAL: float = 0.2
const SUBTITLE_FADE_SPEED: float = 6.0
const TOGGLE_DEBUG_HUD_ACTION: StringName = &"toggle_debug_hud"

var _player: CharacterBody3D
var _update_timer: float = 0.0
var _last_text: String = ""
var _debug_visible: bool = false
var _subtitle_timer: float = 0.0


func _ready() -> void:
	_ensure_debug_toggle_binding()
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	set_debug_visible(false)
	if subtitle_label != null:
		subtitle_label.visible = true
		subtitle_label.modulate.a = 0.0
	_update_label_text()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(TOGGLE_DEBUG_HUD_ACTION):
		return
	set_debug_visible(not _debug_visible)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_subtitle(delta)

	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	_update_label_text()


func _update_label_text() -> void:
	var text: String
	if _player == null:
		text = "Gravity Up: N/A\nGravity Down: N/A"
	else:
		var up_axis_name: String = _axis_name(_player.up_direction)
		var down_axis_name: String = _axis_name(-_player.up_direction)
		text = "Gravity Up: %s\nGravity Down: %s" % [up_axis_name, down_axis_name]

	if text != _last_text:
		_last_text = text
		gravity_label.text = text


func show_companion_subtitle(text: String, duration: float) -> void:
	if subtitle_label == null:
		return
	subtitle_label.text = text
	_subtitle_timer = maxf(duration, 0.2)
	subtitle_label.modulate.a = 1.0


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	if gravity_label != null:
		gravity_label.visible = value


func _update_subtitle(delta: float) -> void:
	if subtitle_label == null:
		return

	if _subtitle_timer > 0.0:
		_subtitle_timer = maxf(_subtitle_timer - delta, 0.0)
		subtitle_label.modulate.a = 1.0
		return

	subtitle_label.modulate.a = maxf(subtitle_label.modulate.a - delta * SUBTITLE_FADE_SPEED, 0.0)
	if subtitle_label.modulate.a <= 0.0:
		subtitle_label.text = ""


func _axis_name(direction: Vector3) -> String:
	var d: Vector3 = direction.normalized()
	var x_abs: float = abs(d.x)
	var y_abs: float = abs(d.y)
	var z_abs: float = abs(d.z)

	if x_abs >= y_abs and x_abs >= z_abs:
		return "+X" if d.x >= 0.0 else "-X"
	if y_abs >= x_abs and y_abs >= z_abs:
		return "+Y" if d.y >= 0.0 else "-Y"
	return "+Z" if d.z >= 0.0 else "-Z"


func _ensure_debug_toggle_binding() -> void:
	if not InputMap.has_action(TOGGLE_DEBUG_HUD_ACTION):
		InputMap.add_action(TOGGLE_DEBUG_HUD_ACTION)

	for event: InputEvent in InputMap.action_get_events(TOGGLE_DEBUG_HUD_ACTION):
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_F3:
			return

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_F3
	InputMap.action_add_event(TOGGLE_DEBUG_HUD_ACTION, key_event)
