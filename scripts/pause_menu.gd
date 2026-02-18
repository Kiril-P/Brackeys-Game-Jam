extends CanvasLayer

@export_group("Animation")
@export_range(0.05, 2.0, 0.01) var open_duration: float = 0.62
@export_range(0.05, 2.0, 0.01) var close_duration: float = 0.56
@export_range(0.05, 4.0, 0.01) var transition_open_duration: float = 1.35
@export_range(0.05, 4.0, 0.01) var transition_close_duration: float = 1.2

@export_group("Settings")
@export var settings_path: String = "user://settings.cfg"

@onready var transition_mask_rect: TextureRect = %TransitionMaskRect
@onready var dimmer: ColorRect = %Dimmer
@onready var menu_root: Control = %MenuRoot
@onready var snapshot_viewport: SubViewport = %SnapshotViewport
@onready var snapshot_root: Control = %SnapshotRoot
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value_label: Label = %SensitivityValueLabel
@onready var fov_slider: HSlider = %FovSlider
@onready var fov_value_label: Label = %FovValueLabel
@onready var resume_button: Button = %ResumeButton
@onready var exit_button: Button = %ExitButton
@onready var pause_title: Label = %PauseTitle
@onready var accent_bar: ColorRect = %AccentBar
@onready var telemetry_label: Label = %TelemetryLabel

const TELEMETRY_UPDATE_INTERVAL: float = 0.1

var _player: PlayerController
var _transition_material: ShaderMaterial
var _is_open: bool = false
var _is_transitioning: bool = false
var _open_elapsed: float = 0.0
var _telemetry_update_timer: float = 0.0
var _last_telemetry_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui_cancel_binding()
	_transition_material = transition_mask_rect.material as ShaderMaterial
	transition_mask_rect.texture = snapshot_viewport.get_texture()
	_set_transition_progress(0.0)
	_set_transition_invert(false)
	_ensure_fullscreen_overlays()
	_ensure_draw_order()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_bind_signals()
	_refresh_player_reference()
	_load_settings()
	_sync_controls_with_player()
	_set_menu_visibility(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_transitioning:
		return

	get_viewport().set_input_as_handled()
	if _is_open:
		_close_pause_menu()
	else:
		_open_pause_menu()


func _process(delta: float) -> void:
	if not _is_open:
		return

	_open_elapsed += delta
	var pulse: float = 0.5 + 0.5 * sin(_open_elapsed * 1.7)
	pause_title.modulate = Color(0.9 + 0.1 * pulse, 0.97, 1.0, 1.0)
	accent_bar.modulate.a = lerpf(0.42, 0.95, pulse)
	telemetry_label.modulate.a = lerpf(0.65, 1.0, pulse)

	_telemetry_update_timer -= delta
	if _telemetry_update_timer > 0.0:
		return
	_telemetry_update_timer = TELEMETRY_UPDATE_INTERVAL
	_update_telemetry_label()


func _bind_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_value_changed)
	fov_slider.value_changed.connect(_on_fov_value_changed)


func _refresh_player_reference() -> void:
	if is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as PlayerController


func _open_pause_menu() -> void:
	_play_pause_transition(true)


func _close_pause_menu() -> void:
	_play_pause_transition(false)


func _play_pause_transition(opening: bool) -> void:
	_is_transitioning = true
	_ensure_fullscreen_overlays()
	_ensure_draw_order()
	var progress_bounds: Vector2 = _get_transition_progress_bounds()

	if opening:
		_refresh_player_reference()
		_sync_controls_with_player()
		_is_open = true
		_open_elapsed = 0.0
		_telemetry_update_timer = 0.0
		_last_telemetry_text = ""
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_set_menu_visibility(true)
		_set_menu_interactable(false)
		dimmer.modulate.a = 0.0
		menu_root.modulate.a = 1.0
		_prepare_menu_snapshot()
		menu_root.visible = false
		transition_mask_rect.visible = true
		_set_transition_progress(progress_bounds.x)
		_set_transition_invert(true)

		var open_tween := create_tween()
		open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		open_tween.set_trans(Tween.TRANS_SINE)
		open_tween.set_ease(Tween.EASE_IN_OUT)
		open_tween.parallel().tween_property(_transition_material, "shader_parameter/progress", progress_bounds.y, transition_open_duration)
		open_tween.parallel().tween_property(dimmer, "modulate:a", 1.0, open_duration)
		open_tween.finished.connect(func() -> void:
			transition_mask_rect.visible = false
			menu_root.visible = true
			_set_menu_interactable(true)
			_is_transitioning = false
		)
		return

	_set_menu_interactable(false)
	_prepare_menu_snapshot()
	menu_root.visible = false
	transition_mask_rect.visible = true
	_set_transition_progress(progress_bounds.y)
	# Closing should be the exact reverse of opening:
	# keep the same invert mode and animate progress backwards.
	_set_transition_invert(true)

	var close_tween := create_tween()
	close_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	close_tween.set_trans(Tween.TRANS_SINE)
	close_tween.set_ease(Tween.EASE_IN_OUT)
	close_tween.parallel().tween_property(_transition_material, "shader_parameter/progress", progress_bounds.x, transition_close_duration)
	close_tween.parallel().tween_property(dimmer, "modulate:a", 0.0, close_duration)
	close_tween.finished.connect(func() -> void:
		_set_menu_visibility(false)
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_is_open = false
		_is_transitioning = false
	)


func _set_menu_visibility(visible_state: bool) -> void:
	transition_mask_rect.visible = false
	dimmer.visible = visible_state
	menu_root.visible = visible_state
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	if not visible_state:
		_set_menu_interactable(false)
	if not visible_state:
		_open_elapsed = 0.0
		_telemetry_update_timer = 0.0
		_last_telemetry_text = ""


func _set_menu_interactable(interactable: bool) -> void:
	var mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if interactable else Control.MOUSE_FILTER_IGNORE
	resume_button.mouse_filter = mouse_filter
	exit_button.mouse_filter = mouse_filter
	sensitivity_slider.mouse_filter = mouse_filter
	fov_slider.mouse_filter = mouse_filter

	resume_button.disabled = not interactable
	exit_button.disabled = not interactable
	sensitivity_slider.editable = interactable
	fov_slider.editable = interactable
	menu_root.focus_mode = Control.FOCUS_ALL if interactable else Control.FOCUS_NONE


func _set_transition_progress(value: float) -> void:
	if _transition_material == null:
		return
	_transition_material.set_shader_parameter("progress", value)


func _set_transition_invert(value: bool) -> void:
	if _transition_material == null:
		return
	_transition_material.set_shader_parameter("invert", value)


func _on_viewport_size_changed() -> void:
	_ensure_fullscreen_overlays()
	_ensure_draw_order()


func _ensure_fullscreen_overlays() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for node: Control in [transition_mask_rect, dimmer, menu_root]:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.position = Vector2.ZERO
	snapshot_viewport.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
	snapshot_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	snapshot_root.position = Vector2.ZERO


func _ensure_draw_order() -> void:
	dimmer.z_index = 20
	menu_root.z_index = 100
	transition_mask_rect.z_index = 200


func _prepare_menu_snapshot() -> void:
	for child: Node in snapshot_root.get_children():
		child.queue_free()

	var snapshot := menu_root.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	if snapshot == null:
		return

	snapshot.name = "MenuRootSnapshot"
	snapshot.visible = true
	snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot_root.add_child(snapshot)


func _get_transition_progress_bounds() -> Vector2:
	if _transition_material == null:
		return Vector2(0.0, 1.0)

	var grid_size: Vector2 = _transition_material.get_shader_parameter("grid_size")
	var progress_bias: Vector2 = _transition_material.get_shader_parameter("progress_bias") / 10.0
	var max_cell: Vector2 = Vector2(maxf(grid_size.x - 1.0, 0.0), maxf(grid_size.y - 1.0, 0.0))

	var offset_00: float = 0.0
	var offset_10: float = max_cell.x * progress_bias.x
	var offset_01: float = max_cell.y * progress_bias.y
	var offset_11: float = offset_10 + offset_01

	var min_offset: float = minf(minf(offset_00, offset_10), minf(offset_01, offset_11))
	var max_offset: float = maxf(maxf(offset_00, offset_10), maxf(offset_01, offset_11))

	# Keep a full additional step so the final cells fully resolve.
	return Vector2(min_offset, max_offset + 1.0)


func _sync_controls_with_player() -> void:
	_refresh_player_reference()
	if _player == null:
		sensitivity_slider.value = 0.004
		fov_slider.value = 75.0
	else:
		sensitivity_slider.value = _player.get_mouse_sensitivity()
		fov_slider.value = _player.get_camera_fov()
	_update_setting_labels()


func _on_sensitivity_value_changed(value: float) -> void:
	_refresh_player_reference()
	if _player != null:
		_player.set_mouse_sensitivity(value)
	_update_setting_labels()
	_save_settings()


func _on_fov_value_changed(value: float) -> void:
	_refresh_player_reference()
	if _player != null:
		_player.set_camera_fov(value)
	_update_setting_labels()
	_save_settings()


func _update_setting_labels() -> void:
	sensitivity_value_label.text = "%.3f" % sensitivity_slider.value
	fov_value_label.text = "%d" % int(round(fov_slider.value))
	if _is_open:
		_telemetry_update_timer = 0.0
		_update_telemetry_label()


func _update_telemetry_label() -> void:
	var next_text: String = "MOUSE %.3f | FOV %d | PAUSED %.1fs" % [
		sensitivity_slider.value,
		int(round(fov_slider.value)),
		_open_elapsed
	]
	if next_text == _last_telemetry_text:
		return
	_last_telemetry_text = next_text
	telemetry_label.text = next_text


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var load_result: int = cfg.load(settings_path)
	if load_result != OK:
		return

	var sensitivity: float = float(cfg.get_value("player", "mouse_sensitivity", sensitivity_slider.value))
	var fov: float = float(cfg.get_value("player", "camera_fov", fov_slider.value))
	sensitivity_slider.value = clampf(sensitivity, sensitivity_slider.min_value, sensitivity_slider.max_value)
	fov_slider.value = clampf(fov, fov_slider.min_value, fov_slider.max_value)
	_on_sensitivity_value_changed(sensitivity_slider.value)
	_on_fov_value_changed(fov_slider.value)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "mouse_sensitivity", sensitivity_slider.value)
	cfg.set_value("player", "camera_fov", fov_slider.value)
	cfg.save(settings_path)


func _on_resume_pressed() -> void:
	if _is_transitioning:
		return
	_close_pause_menu()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _ensure_ui_cancel_binding() -> void:
	if not InputMap.has_action("ui_cancel"):
		InputMap.add_action("ui_cancel")

	for input_event: InputEvent in InputMap.action_get_events("ui_cancel"):
		if input_event is InputEventKey and (input_event as InputEventKey).keycode == KEY_ESCAPE:
			return

	var escape_input := InputEventKey.new()
	escape_input.keycode = KEY_ESCAPE
	InputMap.action_add_event("ui_cancel", escape_input)
