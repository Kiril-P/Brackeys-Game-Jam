extends CharacterBody3D

class_name PlayerController

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 7.0
@export_range(1.0, 80.0, 0.5) var acceleration: float = 40.0
@export_range(1.0, 80.0, 0.5) var deceleration: float = 55.0
@export_range(1.0, 40.0, 0.1) var gravity_strength: float = 24.0
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 5.2
@export_range(0.05, 1.0, 0.05) var air_control_multiplier: float = 0.35
@export_range(5.0, 80.0, 0.5) var max_fall_speed: float = 28.0
@export_range(1.0, 20.0, 0.1) var up_transition_speed: float = 8.0

@export_group("Look")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.001
@export_range(45.0, 89.0, 0.1) var max_pitch_degrees: float = 82.0

@export_group("Gravity")
@export_range(0.05, 1.0, 0.01) var gravity_rotate_duration: float = 0.3

@export_group("Stairs")
@export_range(0.05, 1.0, 0.01) var max_step_height: float = 0.28
@export_range(0.05, 1.5, 0.01) var max_step_down: float = 0.5
@export_range(0.001, 0.1, 0.001) var stair_test_margin: float = 0.001

@export_group("Safety")
@export_range(2.0, 120.0, 0.5) var oob_fall_distance: float = 30.0
@export_range(0.1, 5.0, 0.05) var oob_timeout: float = 0.8
@export_range(0.1, 5.0, 0.05) var safe_anchor_update_interval: float = 0.4

@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var gravity_raycast: RayCast3D = %GravityRayCast3D

var _target_up: Vector3 = Vector3.UP
var _max_pitch_radians: float
var _gravity_tween: Tween
var _is_rotating_gravity: bool = false
var _awaiting_pointer_lock_click: bool = false
var _last_safe_transform: Transform3D
var _last_safe_up: Vector3 = Vector3.UP
var _safe_anchor_timer: float = 0.0
var _oob_timer: float = 0.0
var _post_teleport_grace_timer: float = 0.0

const POST_TELEPORT_SAFE_GRACE: float = 0.35

func _ready() -> void:
	add_to_group("player")
	_ensure_input_map()
	var profile: PerformanceProfile = get_node_or_null("/root/GamePerformance") as PerformanceProfile
	if profile != null and profile.pointer_lock_requires_user_gesture():
		_awaiting_pointer_lock_click = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_max_pitch_radians = deg_to_rad(max_pitch_degrees)
	up_direction = Vector3.UP
	_target_up = up_direction
	_last_safe_transform = global_transform
	_last_safe_up = up_direction
	_safe_anchor_timer = safe_anchor_update_interval
	_oob_timer = 0.0
	_post_teleport_grace_timer = 0.0
	_apply_active_color_for_up(up_direction)


func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_pointer_lock_click and event is InputEventMouseButton:
		var click_event := event as InputEventMouseButton
		if click_event.button_index == MOUSE_BUTTON_LEFT and click_event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_awaiting_pointer_lock_click = false
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _is_rotating_gravity:
			return
		var motion_event := event as InputEventMouseMotion
		rotate(up_direction, -motion_event.relative.x * mouse_sensitivity)
		head.rotate_x(-motion_event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -_max_pitch_radians, _max_pitch_radians)


func _physics_process(delta: float) -> void:
	_handle_gravity_input()
	_update_up_direction(delta)
	_apply_movement(delta)
	var was_on_floor: bool = is_on_floor()
	var stepped_up: bool = _try_step_up(delta)
	if stepped_up:
		# Horizontal motion was already consumed by the step-up teleport.
		var vertical_speed: float = velocity.dot(up_direction)
		velocity = up_direction * vertical_speed
	move_and_slide()
	if not stepped_up:
		_try_step_down(was_on_floor)
	_update_safe_anchor_and_oob(delta)


func _handle_gravity_input() -> void:
	if Input.is_action_just_pressed("change_gravity"):
		gravity_raycast.force_raycast_update()
		if gravity_raycast.is_colliding():
			var hit_normal: Vector3 = gravity_raycast.get_collision_normal().normalized()
			var desired_up: Vector3 = _to_cardinal_axis(hit_normal)
			_set_target_up(desired_up)

	# Optional direct bindings for fast debugging.
	if Input.is_action_just_pressed("gravity_down"):
		_set_target_up(Vector3.UP)
	elif Input.is_action_just_pressed("gravity_up"):
		_set_target_up(Vector3.DOWN)
	elif Input.is_action_just_pressed("gravity_pos_x"):
		_set_target_up(Vector3.LEFT)
	elif Input.is_action_just_pressed("gravity_neg_x"):
		_set_target_up(Vector3.RIGHT)
	elif Input.is_action_just_pressed("gravity_pos_z"):
		_set_target_up(Vector3.BACK)
	elif Input.is_action_just_pressed("gravity_neg_z"):
		_set_target_up(Vector3.FORWARD)

	if _gravity_tween == null:
		return

	if _gravity_tween.is_running():
		return

	# Keep up_direction synced to the resolved target once tween is complete.
	up_direction = _target_up


func _update_up_direction(_delta: float) -> void:
	up_direction = _target_up


func _apply_movement(delta: float) -> void:
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")

	var camera_forward: Vector3 = -camera.global_basis.z
	camera_forward = (camera_forward - up_direction * camera_forward.dot(up_direction)).normalized()
	if camera_forward.length_squared() < 0.0001:
		camera_forward = (-global_basis.z - up_direction * (-global_basis.z).dot(up_direction)).normalized()

	var camera_right: Vector3 = camera_forward.cross(up_direction).normalized()
	var desired_direction: Vector3 = (camera_right * move_input.x + camera_forward * move_input.y).normalized()

	var vertical_velocity: float = velocity.dot(up_direction)
	var horizontal_velocity: Vector3 = velocity - up_direction * vertical_velocity
	var target_horizontal: Vector3 = desired_direction * move_speed

	var accel: float = acceleration if desired_direction.length_squared() > 0.0 else deceleration
	if not is_on_floor():
		accel *= air_control_multiplier
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, accel * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vertical_velocity = jump_velocity
		elif vertical_velocity < 0.0:
			vertical_velocity = 0.0
	else:
		vertical_velocity -= gravity_strength * delta
		vertical_velocity = max(vertical_velocity, -max_fall_speed)

	velocity = horizontal_velocity + up_direction * vertical_velocity


func _try_step_up(delta: float) -> bool:
	if not is_on_floor():
		return false
	if _is_rotating_gravity:
		return false
	if velocity.dot(up_direction) > 0.0:
		return false

	var frame_motion: Vector3 = velocity * delta
	var horizontal_motion: Vector3 = frame_motion - up_direction * frame_motion.dot(up_direction)
	if horizontal_motion.length_squared() < 0.000001:
		return false

	var step_height_motion: Vector3 = up_direction * (max_step_height * 2.0)
	var elevated_transform: Transform3D = global_transform.translated(step_height_motion)
	if _body_test_motion(elevated_transform, horizontal_motion):
		return false

	var forward_transform: Transform3D = elevated_transform.translated(horizontal_motion)
	var down_motion: Vector3 = -up_direction * (max_step_height * 2.0)
	var floor_result := PhysicsTestMotionResult3D.new()
	if not _body_test_motion(forward_transform, down_motion, floor_result):
		return false

	var floor_dot: float = floor_result.get_collision_normal().dot(up_direction)
	if floor_dot < cos(floor_max_angle):
		return false

	var stepped_transform: Transform3D = forward_transform.translated(floor_result.get_travel())
	var step_delta_along_up: float = (stepped_transform.origin - global_transform.origin).dot(up_direction)
	if step_delta_along_up <= 0.001:
		return false
	if step_delta_along_up > max_step_height + stair_test_margin:
		return false

	global_transform = stepped_transform
	apply_floor_snap()

	# Don't keep downward velocity after successful stair step-up.
	var vertical_speed: float = velocity.dot(up_direction)
	if vertical_speed < 0.0:
		velocity -= up_direction * vertical_speed
	return true


func _try_step_down(was_on_floor: bool) -> void:
	if not was_on_floor:
		return
	if is_on_floor():
		return
	if _is_rotating_gravity:
		return
	if velocity.dot(up_direction) > 0.0:
		return

	var down_motion: Vector3 = -up_direction * max_step_down
	var floor_result := PhysicsTestMotionResult3D.new()
	if not _body_test_motion(global_transform, down_motion, floor_result):
		return

	var floor_dot: float = floor_result.get_collision_normal().dot(up_direction)
	if floor_dot < cos(floor_max_angle):
		return

	global_transform = global_transform.translated(floor_result.get_travel())
	apply_floor_snap()

	var vertical_speed: float = velocity.dot(up_direction)
	if vertical_speed < 0.0:
		velocity -= up_direction * vertical_speed


func _update_safe_anchor_and_oob(delta: float) -> void:
	_post_teleport_grace_timer = maxf(_post_teleport_grace_timer - delta, 0.0)

	var can_capture_anchor: bool = is_on_floor() and not _is_rotating_gravity and _post_teleport_grace_timer <= 0.0
	if can_capture_anchor:
		_safe_anchor_timer -= delta
		if _safe_anchor_timer <= 0.0:
			_last_safe_transform = global_transform
			_last_safe_up = up_direction.normalized() if not up_direction.is_zero_approx() else Vector3.UP
			_safe_anchor_timer = safe_anchor_update_interval
	else:
		_safe_anchor_timer = minf(_safe_anchor_timer, safe_anchor_update_interval)

	var anchor_up: Vector3 = _last_safe_up if not _last_safe_up.is_zero_approx() else Vector3.UP
	var fall_distance: float = (_last_safe_transform.origin - global_transform.origin).dot(anchor_up)
	if fall_distance > oob_fall_distance:
		_oob_timer += delta
	else:
		_oob_timer = maxf(_oob_timer - delta * 2.0, 0.0)

	if _oob_timer >= oob_timeout:
		_recover_from_out_of_bounds()


func _recover_from_out_of_bounds() -> void:
	if _gravity_tween != null:
		_gravity_tween.kill()
		_gravity_tween = null
	_is_rotating_gravity = false
	_oob_timer = 0.0
	_post_teleport_grace_timer = POST_TELEPORT_SAFE_GRACE

	_target_up = _last_safe_up if not _last_safe_up.is_zero_approx() else Vector3.UP
	_target_up = _target_up.normalized()
	up_direction = _target_up
	global_transform = _last_safe_transform
	velocity = Vector3.ZERO
	_snap_basis_to_up(_target_up)
	head.rotation = Vector3(clampf(head.rotation.x, -_max_pitch_radians, _max_pitch_radians), 0.0, 0.0)
	apply_floor_snap()


func _body_test_motion(from_transform: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D = null) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from_transform
	params.motion = motion
	params.margin = stair_test_margin
	return PhysicsServer3D.body_test_motion(get_rid(), params, result)


func _set_target_up(new_up: Vector3) -> void:
	if new_up.is_zero_approx():
		return

	var normalized_up: Vector3 = new_up.normalized()
	if normalized_up.is_equal_approx(_target_up):
		return

	var old_up: Vector3 = up_direction
	_target_up = normalized_up
	up_direction = _target_up
	_align_basis_to_up(old_up, _target_up)
	_apply_active_color_for_up(_target_up)


func _align_basis_to_up(old_up: Vector3, new_up: Vector3) -> void:
	var from_basis: Basis = global_basis.orthonormalized()
	var projected_forward: Vector3 = (-global_basis.z - new_up * (-global_basis.z).dot(new_up)).normalized()
	if projected_forward.length_squared() < 0.0001:
		projected_forward = (-camera.global_basis.z - new_up * (-camera.global_basis.z).dot(new_up)).normalized()
	if projected_forward.length_squared() < 0.0001:
		var fallback_axis: Vector3 = Vector3.RIGHT if abs(new_up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		projected_forward = (fallback_axis - new_up * fallback_axis.dot(new_up)).normalized()

	var old_planar_forward: Vector3 = (-global_basis.z - old_up * (-global_basis.z).dot(old_up)).normalized()
	if old_planar_forward.length_squared() > 0.0001 and projected_forward.dot(old_planar_forward) < 0.0:
		projected_forward = -projected_forward

	var right: Vector3 = projected_forward.cross(new_up).normalized()
	var back: Vector3 = right.cross(new_up).normalized()
	var to_basis: Basis = Basis(right, new_up, back).orthonormalized()

	if _gravity_tween != null:
		_gravity_tween.kill()

	var from_q: Quaternion = from_basis.get_rotation_quaternion()
	var to_q: Quaternion = to_basis.get_rotation_quaternion()
	if from_q.dot(to_q) < 0.0:
		to_q = -to_q
	_is_rotating_gravity = true
	_gravity_tween = create_tween()
	_gravity_tween.set_trans(Tween.TRANS_SINE)
	_gravity_tween.set_ease(Tween.EASE_IN_OUT)
	_gravity_tween.tween_method(
		func(weight: float) -> void:
			var blended: Quaternion = from_q.slerp(to_q, weight).normalized()
			global_basis = Basis(blended).orthonormalized()
	,
		0.0,
		1.0,
		gravity_rotate_duration
	)
	_gravity_tween.finished.connect(func() -> void:
		_is_rotating_gravity = false
		head.rotation = Vector3(clampf(head.rotation.x, -_max_pitch_radians, _max_pitch_radians), 0.0, 0.0)
	)


func on_teleport(portal: Portal3D) -> void:
	if _gravity_tween != null:
		_gravity_tween.kill()
		_gravity_tween = null
	_is_rotating_gravity = false

	if portal != null:
		velocity = portal.to_exit_direction(velocity)
		velocity = _clamp_small_velocity_components(velocity)

	if _target_up.is_zero_approx():
		_target_up = up_direction if not up_direction.is_zero_approx() else Vector3.UP
	_target_up = _target_up.normalized()
	up_direction = _target_up
	_post_teleport_grace_timer = POST_TELEPORT_SAFE_GRACE

	if _needs_post_teleport_snap(_target_up):
		_snap_basis_to_up(_target_up)
	else:
		global_basis = global_basis.orthonormalized()
	head.rotation = Vector3(clampf(head.rotation.x, -_max_pitch_radians, _max_pitch_radians), 0.0, 0.0)


func _clamp_small_velocity_components(v: Vector3) -> Vector3:
	const EPSILON := 0.0005
	var clamped := v
	if absf(clamped.x) < EPSILON:
		clamped.x = 0.0
	if absf(clamped.y) < EPSILON:
		clamped.y = 0.0
	if absf(clamped.z) < EPSILON:
		clamped.z = 0.0
	return clamped


func _needs_post_teleport_snap(expected_up: Vector3) -> bool:
	var basis_up: Vector3 = global_basis.y.normalized()
	if basis_up.is_zero_approx():
		return true
	# Snap only if current body up is meaningfully off from gravity up.
	return basis_up.dot(expected_up) < 0.92


func _snap_basis_to_up(new_up: Vector3) -> void:
	var projected_forward: Vector3 = (-camera.global_basis.z - new_up * (-camera.global_basis.z).dot(new_up)).normalized()
	if projected_forward.length_squared() < 0.0001:
		projected_forward = (-global_basis.z - new_up * (-global_basis.z).dot(new_up)).normalized()
	if projected_forward.length_squared() < 0.0001:
		var fallback_axis: Vector3 = Vector3.RIGHT if abs(new_up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		projected_forward = (fallback_axis - new_up * fallback_axis.dot(new_up)).normalized()

	var old_planar_forward: Vector3 = (-global_basis.z - new_up * (-global_basis.z).dot(new_up)).normalized()
	if old_planar_forward.length_squared() > 0.0001 and projected_forward.dot(old_planar_forward) < 0.0:
		projected_forward = -projected_forward

	var right: Vector3 = projected_forward.cross(new_up).normalized()
	var back: Vector3 = right.cross(new_up).normalized()
	global_basis = Basis(right, new_up, back).orthonormalized()


func _to_cardinal_axis(direction: Vector3) -> Vector3:
	var x_abs: float = abs(direction.x)
	var y_abs: float = abs(direction.y)
	var z_abs: float = abs(direction.z)

	if x_abs >= y_abs and x_abs >= z_abs:
		return Vector3.RIGHT if direction.x >= 0.0 else Vector3.LEFT
	if y_abs >= x_abs and y_abs >= z_abs:
		return Vector3.UP if direction.y >= 0.0 else Vector3.DOWN
	return Vector3.BACK if direction.z >= 0.0 else Vector3.FORWARD


func _apply_active_color_for_up(current_up: Vector3) -> void:
	var axis_color: Color = Color(0.2, 1.0, 0.2, 1.0) # +Y
	if current_up == Vector3.DOWN:
		axis_color = Color(0.1, 0.7, 0.1, 1.0)
	elif current_up == Vector3.RIGHT:
		axis_color = Color(1.0, 0.25, 0.25, 1.0)
	elif current_up == Vector3.LEFT:
		axis_color = Color(0.75, 0.15, 0.15, 1.0)
	elif current_up == Vector3.BACK:
		axis_color = Color(0.2, 0.5, 1.0, 1.0)
	elif current_up == Vector3.FORWARD:
		axis_color = Color(0.15, 0.3, 0.8, 1.0)

	# Avoid startup errors when the global shader uniform is not registered.
	if ProjectSettings.has_setting("shader_globals/active_color") or ProjectSettings.has_setting("rendering/shader_globals/active_color"):
		RenderingServer.global_shader_parameter_set("active_color", axis_color)


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.02)


func get_mouse_sensitivity() -> float:
	return mouse_sensitivity


func set_camera_fov(value: float) -> void:
	camera.fov = clampf(value, 60.0, 100.0)


func get_camera_fov() -> float:
	return camera.fov


func _ensure_input_map() -> void:
	var register := func(action_name: StringName, key: Key) -> void:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for existing_event: InputEvent in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey and (existing_event as InputEventKey).keycode == key:
				return
		var key_event := InputEventKey.new()
		key_event.keycode = key
		InputMap.action_add_event(action_name, key_event)

	register.call("move_forward", KEY_W)
	register.call("move_back", KEY_S)
	register.call("move_left", KEY_A)
	register.call("move_right", KEY_D)
	register.call("jump", KEY_SPACE)
	register.call("change_gravity", KEY_E)

	register.call("gravity_down", KEY_1)
	register.call("gravity_up", KEY_2)
	register.call("gravity_pos_x", KEY_3)
	register.call("gravity_neg_x", KEY_4)
	register.call("gravity_pos_z", KEY_5)
	register.call("gravity_neg_z", KEY_6)
