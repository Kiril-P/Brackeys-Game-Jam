extends Node3D

signal tutorial_line_started(line_id: StringName, subtitle: String, duration: float)
signal tutorial_line_finished(line_id: StringName)

@export_group("Follow")
@export_range(0.5, 10.0, 0.1) var follow_distance: float = 4.1
@export_range(-4.0, 4.0, 0.1) var side_offset: float = 1.5
@export_range(0.2, 6.0, 0.1) var hover_height: float = 2.1
@export_range(0.1, 3.0, 0.05) var settle_distance_tolerance: float = 0.45
@export_range(0.6, 8.0, 0.1) var min_follow_distance: float = 3.2
@export_range(0.8, 12.0, 0.1) var orbit_radius_min: float = 3.6
@export_range(1.0, 12.0, 0.1) var orbit_radius_max: float = 4.6
@export_range(0.2, 12.0, 0.1) var orbit_change_interval_min: float = 6.0
@export_range(0.2, 12.0, 0.1) var orbit_change_interval_max: float = 10.0
@export_range(0.1, 30.0, 0.1) var follow_acceleration: float = 6.8
@export_range(0.1, 30.0, 0.1) var follow_damping: float = 6.3
@export_range(0.5, 20.0, 0.1) var max_speed: float = 6.2
@export_range(0.2, 3.0, 0.05) var obstacle_probe_radius: float = 0.45
@export_flags_3d_physics var obstacle_collision_mask: int = 1
@export_range(0.5, 8.0, 0.1) var lane_probe_distance: float = 1.8
@export_range(0.0, 2.0, 0.05) var lane_steer_strength: float = 0.9
@export_range(0.2, 8.0, 0.1) var detour_commit_duration: float = 1.8
@export_range(0.2, 8.0, 0.1) var detour_progress_timeout: float = 1.7
@export_range(0.5, 6.0, 0.1) var detour_base_radius: float = 1.4
@export_range(0.1, 4.0, 0.1) var detour_expand_step: float = 0.6
@export_range(1, 10, 1) var detour_max_fail_count: int = 5

@export_group("Stuck Recovery")
@export_range(1.0, 30.0, 0.5) var stuck_timeout: float = 10.0
@export_range(1.0, 30.0, 0.5) var teleport_retry_interval: float = 10.0
@export_range(0.5, 10.0, 0.1) var stuck_distance_threshold: float = 2.6
@export_range(0.01, 2.0, 0.01) var min_progress_distance: float = 0.12
@export_range(1.0, 8.0, 0.1) var teleport_search_radius: float = 3.8
@export_range(0.2, 4.0, 0.1) var teleport_min_player_distance: float = 1.25
@export var teleport_height_offsets: PackedFloat32Array = PackedFloat32Array([0.0, 0.8, -0.6, 1.3])

@export_group("Style")
@export_range(0.0, 1.0, 0.01) var bob_amplitude: float = 0.14
@export_range(0.1, 10.0, 0.1) var bob_speed: float = 2.3
@export_range(0.0, 25.0, 0.1) var wobble_degrees: float = 5.5
@export_range(0.1, 10.0, 0.1) var wobble_speed: float = 3.2
@export_range(0.0, 80.0, 0.1) var propeller_spin_speed: float = 24.0
@export_range(0.0, 80.0, 0.1) var side_propeller_spin_speed: float = 18.0
@export_range(0.1, 20.0, 0.1) var look_lerp_speed: float = 7.0
@export_range(1.0, 12.0, 0.1) var dialogue_look_distance: float = 5.0
@export_range(0.0, 1.0, 0.01) var look_at_player_weight: float = 0.75

@export_group("Interaction")
@export_range(0.5, 20.0, 0.1) var click_push_strength: float = 7.0
@export_range(0.0, 6.0, 0.1) var click_upward_boost: float = 1.2
@export_range(0.2, 8.0, 0.1) var angry_duration: float = 2.2
@export_range(0.1, 3.0, 0.05) var knockback_hold_duration: float = 0.9
@export_range(0.1, 12.0, 0.1) var knockback_drag: float = 2.2
@export_range(0.5, 30.0, 0.1) var interaction_max_reach: float = 6.0
@export_flags_3d_physics var click_raycast_mask: int = 2

@export_group("Optimization")
@export_range(1, 128, 1) var route_score_budget_per_tick: int = 18
@export_range(1, 60, 1) var query_cache_ttl_frames: int = 4
@export_range(0.05, 2.0, 0.05) var query_cache_quantization: float = 0.2

@onready var visual_root: Node3D = %VisualRoot
@onready var propeller_pivot: Node3D = %PropellerPivot
@onready var side_propeller_pivot_l: Node3D = %SidePropellerPivotL
@onready var side_propeller_pivot_r: Node3D = %SidePropellerPivotR
@onready var eye_l: MeshInstance3D = %EyeL
@onready var eye_r: MeshInstance3D = %EyeR
@onready var mouth: MeshInstance3D = %Mouth
@onready var screen: MeshInstance3D = %Screen
@onready var hit_area: Area3D = %HitArea
@onready var voice_player: AudioStreamPlayer3D = %VoicePlayer

const PLAYER_REFIND_INTERVAL: float = 0.4

var _player: Node3D
var _velocity: Vector3 = Vector3.ZERO
var _probe_shape: SphereShape3D
var _time: float = 0.0
var _last_progress_position: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _recovery_mode: bool = false
var _retry_timer: float = 0.0
var _blink_timer: float = 0.0
var _blink_interval: float = 0.0
var _angry_timer: float = 0.0
var _normal_screen_emission: Color = Color(0.25, 0.95, 0.65, 1.0)
var _angry_screen_emission: Color = Color(1.0, 0.25, 0.2, 1.0)
var _orbit_angle: float = 0.0
var _orbit_radius: float = 4.0
var _orbit_timer: float = 0.0
var _knockback_timer: float = 0.0
var _has_detour: bool = false
var _detour_target: Vector3 = Vector3.ZERO
var _detour_timer: float = 0.0
var _detour_fail_count: int = 0
var _detour_progress_timer: float = 0.0
var _detour_last_distance: float = INF
var _detour_side_bias: float = 0.0
var _objective_stuck_timer: float = 0.0
var _objective_last_distance: float = INF
var _objective_progress_timer: float = 0.0
var _player_refind_timer: float = 0.0
var _frame_player_up: Vector3 = Vector3.UP
var _ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _detour_candidate_buffer: Array[Vector3] = []
var _teleport_candidate_buffer: Array[Vector3] = []
var _point_blocked_cache: Dictionary = {}
var _segment_hits_cache: Dictionary = {}
var _lane_clear_cache: Dictionary = {}
var _physics_frame_counter: int = 0
var _resolve_candidate_cursor: int = 0
var _detour_candidate_cursor: int = 0
var _last_click_reaction_frame: int = -1
var _tutorial_queue: Array[Dictionary] = []
var _tutorial_active_id: StringName = StringName()
var _tutorial_fallback_timer: float = 0.0
var _tutorial_using_audio: bool = false


func _ready() -> void:
	add_to_group("companion")
	_probe_shape = SphereShape3D.new()
	_probe_shape.radius = obstacle_probe_radius
	_shape_query.shape = _probe_shape
	_shape_query.collision_mask = obstacle_collision_mask
	_shape_query.collide_with_areas = false
	_shape_query.collide_with_bodies = true
	_ray_query.collision_mask = obstacle_collision_mask
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	_player = _find_player()
	_refresh_query_excludes()
	_detour_side_bias = 1.0 if randf() > 0.5 else -1.0
	_blink_interval = randf_range(1.7, 3.5)
	if hit_area != null:
		hit_area.input_event.connect(_on_hit_area_input_event)
	if voice_player != null and not voice_player.finished.is_connected(_on_voice_player_finished):
		voice_player.finished.connect(_on_voice_player_finished)
	if screen != null and screen.material_override is StandardMaterial3D:
		var base_material := (screen.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		base_material.resource_local_to_scene = true
		screen.material_override = base_material
		_normal_screen_emission = base_material.emission
	_pick_new_orbit_anchor(true)
	if _player != null:
		global_position = _compute_follow_target(_player)
		_objective_last_distance = global_position.distance_to(_compute_follow_target(_player))
		_frame_player_up = _get_player_up(_player)
	_last_progress_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return
	_try_click_reaction(button_event.position)


func _physics_process(delta: float) -> void:
	_physics_frame_counter += 1
	_time += delta
	_update_tutorial_playback(delta)
	if _player == null or not is_instance_valid(_player):
		_player_refind_timer -= delta
		if _player_refind_timer <= 0.0:
			var found_player: Node3D = _find_player()
			if found_player != _player:
				_player = found_player
				_refresh_query_excludes()
			_player_refind_timer = PLAYER_REFIND_INTERVAL
		if _player == null:
			_update_style(delta, Vector3.ZERO)
			return
	else:
		_player_refind_timer = 0.0

	_frame_player_up = _get_player_up(_player)

	var desired_target: Vector3 = _compute_follow_target(_player)
	var nav_target: Vector3 = _update_detour_state(desired_target, delta)
	var resolved_target: Vector3 = _resolve_target_with_avoidance(nav_target, desired_target)
	if _segment_hits_obstacle(global_position, desired_target):
		_pick_new_orbit_anchor()

	if _knockback_timer > 0.0:
		_knockback_timer = maxf(_knockback_timer - delta, 0.0)
		_velocity *= exp(-knockback_drag * delta)
		var knockback_next: Vector3 = global_position + _velocity * delta
		if not _is_point_blocked(knockback_next):
			global_position = knockback_next
		else:
			_velocity *= 0.2
		_update_style(delta, resolved_target)
		return

	_move_towards(resolved_target, delta)
	_update_stuck_recovery(desired_target, resolved_target, delta)
	_update_style(delta, resolved_target)


func queue_tutorial_line(line_id: StringName, subtitle: String, audio_path: String, fallback_duration: float = 3.0) -> void:
	if line_id == StringName():
		return
	if line_id == _tutorial_active_id:
		return
	for pending: Dictionary in _tutorial_queue:
		var pending_id: StringName = pending.get("line_id", StringName())
		if pending_id == line_id:
			return

	_tutorial_queue.append({
		"line_id": line_id,
		"subtitle": subtitle,
		"audio_path": audio_path,
		"fallback_duration": maxf(fallback_duration, 0.1),
	})
	_try_begin_next_tutorial_line()


func _try_begin_next_tutorial_line() -> void:
	if _tutorial_active_id != StringName():
		return
	if _tutorial_queue.is_empty():
		return

	var next_line: Dictionary = _tutorial_queue.pop_front()
	var line_id: StringName = next_line.get("line_id", StringName())
	var subtitle: String = str(next_line.get("subtitle", ""))
	var audio_path: String = str(next_line.get("audio_path", ""))
	var fallback_duration: float = float(next_line.get("fallback_duration", 3.0))
	if line_id == StringName():
		_try_begin_next_tutorial_line()
		return

	_tutorial_active_id = line_id
	_tutorial_using_audio = false
	_tutorial_fallback_timer = maxf(fallback_duration, 0.1)

	if audio_path != "" and ResourceLoader.exists(audio_path):
		var stream := load(audio_path) as AudioStream
		if stream != null and voice_player != null:
			voice_player.stream = stream
			voice_player.play()
			_tutorial_using_audio = true
			_tutorial_fallback_timer = maxf(stream.get_length() + 0.25, fallback_duration + 0.25)

	tutorial_line_started.emit(line_id, subtitle, maxf(_tutorial_fallback_timer, fallback_duration))


func _update_tutorial_playback(delta: float) -> void:
	if _tutorial_active_id == StringName():
		_try_begin_next_tutorial_line()
		return

	if _tutorial_using_audio:
		if voice_player == null or not voice_player.playing:
			_finish_current_tutorial_line()
		return

	_tutorial_fallback_timer = maxf(_tutorial_fallback_timer - delta, 0.0)
	if _tutorial_fallback_timer <= 0.0:
		_finish_current_tutorial_line()


func _on_voice_player_finished() -> void:
	if _tutorial_active_id == StringName():
		return
	_finish_current_tutorial_line()


func _finish_current_tutorial_line() -> void:
	if _tutorial_active_id == StringName():
		return
	var finished_id: StringName = _tutorial_active_id
	_tutorial_active_id = StringName()
	_tutorial_using_audio = false
	_tutorial_fallback_timer = 0.0
	tutorial_line_finished.emit(finished_id)
	_try_begin_next_tutorial_line()


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _compute_follow_target(player_node: Node3D) -> Vector3:
	var up: Vector3 = _get_player_up(player_node)
	var from_player: Vector3 = global_position - player_node.global_position
	var planar: Vector3 = from_player - up * from_player.dot(up)
	var planar_len: float = planar.length()

	if planar_len < 0.001:
		# Pick a neutral fallback direction only when overlapping.
		planar = _planar_forward(-player_node.global_basis.z, up)
		planar_len = 1.0

	var desired_distance: float = clampf(follow_distance, min_follow_distance, maxf(min_follow_distance + 0.2, orbit_radius_max))

	# If already inside a comfortable ring, don't orbit - just chill.
	if absf(planar_len - desired_distance) <= settle_distance_tolerance:
		return global_position

	planar = planar.normalized() * desired_distance
	var target: Vector3 = player_node.global_position + up * hover_height + planar
	return target


func _move_towards(target: Vector3, delta: float) -> void:
	var to_target: Vector3 = target - global_position
	var acceleration: Vector3 = to_target * follow_acceleration

	var up: Vector3 = _get_player_up(_player)
	acceleration += _compute_lane_steer(target, up) * follow_acceleration * lane_steer_strength

	if _player != null:
		var player_to_companion: Vector3 = global_position - _player.global_position
		var player_distance: float = player_to_companion.length()
		if player_distance < min_follow_distance and player_distance > 0.001:
			# Strong personal space push keeps the companion readable on screen.
			var push_strength: float = (min_follow_distance - player_distance) * follow_acceleration * 3.0
			acceleration += player_to_companion.normalized() * push_strength
			var hard_step: float = minf(min_follow_distance - player_distance, max_speed * delta * 0.8)
			global_position += player_to_companion.normalized() * hard_step

	_velocity += acceleration * delta
	_velocity *= exp(-follow_damping * delta)
	if _velocity.length() > max_speed:
		_velocity = _velocity.normalized() * max_speed

	var desired_next: Vector3 = global_position + _velocity * delta
	if not _is_point_blocked(desired_next):
		global_position = desired_next
	else:
		_velocity *= 0.25


func _resolve_target_with_avoidance(raw_target: Vector3, desired_target: Vector3) -> Vector3:
	if _is_lane_clear(global_position, raw_target) and not _is_point_blocked(raw_target):
		return raw_target

	var fallback: Vector3 = raw_target
	var candidates: Array[Vector3] = _build_detour_candidates(desired_target, _detour_fail_count)
	var best_target: Vector3 = raw_target
	var best_score: float = INF
	var eval_result: Array = _score_candidates_with_budget(candidates, desired_target, _resolve_candidate_cursor)
	if eval_result.size() == 3:
		best_score = eval_result[0]
		best_target = eval_result[1]
		_resolve_candidate_cursor = eval_result[2]

	if best_score >= INF * 0.5:
		return fallback
	return best_target


func _update_stuck_recovery(desired_target: Vector3, _resolved_target: Vector3, delta: float) -> void:
	var objective_distance: float = global_position.distance_to(desired_target)
	if _objective_last_distance >= INF * 0.5:
		_objective_last_distance = objective_distance

	var objective_progressed: bool = objective_distance < (_objective_last_distance - min_progress_distance * 0.35)
	if objective_progressed:
		_objective_last_distance = objective_distance
		_objective_progress_timer = 0.0
	else:
		_objective_progress_timer += delta

	var objective_far: bool = objective_distance > stuck_distance_threshold
	var objective_path_blocked: bool = not _is_lane_clear(global_position, desired_target)
	var objective_no_progress: bool = _objective_progress_timer >= detour_progress_timeout
	var objective_unreachable: bool = objective_far and (objective_path_blocked or objective_no_progress)

	if objective_unreachable:
		_objective_stuck_timer += delta
	else:
		_objective_stuck_timer = maxf(_objective_stuck_timer - delta * 1.6, 0.0)
		if objective_progressed or not objective_far:
			_objective_last_distance = objective_distance
		if _objective_stuck_timer <= 0.0:
			_objective_progress_timer = 0.0
			_recovery_mode = false
			_retry_timer = 0.0

	# Keep legacy variable in sync for any debug tooling using _stuck_timer.
	_stuck_timer = _objective_stuck_timer

	if _has_detour and _detour_fail_count >= detour_max_fail_count:
		# Detour routing has repeatedly failed; escalate toward fallback recovery.
		_objective_stuck_timer = maxf(_objective_stuck_timer, stuck_timeout - 0.8)
		_stuck_timer = _objective_stuck_timer

	if _objective_stuck_timer < stuck_timeout:
		return

	if not _recovery_mode:
		_recovery_mode = true
		_retry_timer = 0.0 # Immediate attempt once we enter recovery mode.

	_retry_timer -= delta
	if _retry_timer > 0.0:
		return

	if _try_recovery_teleport():
		_clear_detour_state()
		_detour_fail_count = 0
		_stuck_timer = 0.0
		_objective_stuck_timer = 0.0
		_objective_progress_timer = 0.0
		_objective_last_distance = global_position.distance_to(desired_target)
		_recovery_mode = false
		_retry_timer = 0.0
		_last_progress_position = global_position
	else:
		_retry_timer = teleport_retry_interval


func _try_recovery_teleport() -> bool:
	var up: Vector3 = _frame_player_up
	var player_pos: Vector3 = _player.global_position
	var forward: Vector3 = _planar_forward(-_player.global_basis.z, up)
	var right: Vector3 = forward.cross(up).normalized()

	var preferred_target: Vector3 = _compute_follow_target(_player)
	var min_player_distance_sq: float = teleport_min_player_distance * teleport_min_player_distance
	var candidates: Array[Vector3] = _teleport_candidate_buffer
	candidates.clear()
	candidates.append(preferred_target)
	for radius: float in [teleport_search_radius * 0.6, teleport_search_radius]:
		for height_offset: float in teleport_height_offsets:
			for step: int in 12:
				var angle: float = (TAU * float(step)) / 12.0
				var planar_offset: Vector3 = right * cos(angle) * radius + forward * sin(angle) * radius
				var candidate: Vector3 = player_pos + up * (hover_height + height_offset) + planar_offset
				candidates.append(candidate)

	for candidate: Vector3 in candidates:
		if candidate.distance_squared_to(player_pos) < min_player_distance_sq:
			continue
		if _is_point_blocked(candidate):
			continue
		if _segment_hits_obstacle(player_pos + up * 0.8, candidate):
			continue

		global_position = candidate
		_velocity = Vector3.ZERO
		_clear_query_caches()
		return true

	return false


func _segment_hits_obstacle(from: Vector3, to: Vector3) -> bool:
	var cache_key: String = _segment_cache_key(from, to)
	var cached: Variant = _cache_get(_segment_hits_cache, cache_key)
	if cached != null:
		return bool(cached)
	_ray_query.from = from
	_ray_query.to = to
	var hits_obstacle: bool = not get_world_3d().direct_space_state.intersect_ray(_ray_query).is_empty()
	_cache_set(_segment_hits_cache, cache_key, hits_obstacle)
	return hits_obstacle


func _is_lane_clear(from: Vector3, to: Vector3) -> bool:
	var cache_key: String = _lane_cache_key(from, to, _frame_player_up)
	var cached: Variant = _cache_get(_lane_clear_cache, cache_key)
	if cached != null:
		return bool(cached)

	var up: Vector3 = _frame_player_up
	var direction: Vector3 = (to - from).normalized()
	if direction.length_squared() < 0.0001:
		_cache_set(_lane_clear_cache, cache_key, true)
		return true
	var right: Vector3 = direction.cross(up).normalized()
	var lane_side_offset: Vector3 = right * obstacle_probe_radius * 0.8
	if _segment_hits_obstacle(from, to):
		_cache_set(_lane_clear_cache, cache_key, false)
		return false
	if _segment_hits_obstacle(from + lane_side_offset, to + lane_side_offset):
		_cache_set(_lane_clear_cache, cache_key, false)
		return false
	if _segment_hits_obstacle(from - lane_side_offset, to - lane_side_offset):
		_cache_set(_lane_clear_cache, cache_key, false)
		return false
	_cache_set(_lane_clear_cache, cache_key, true)
	return true


func _is_point_blocked(point: Vector3) -> bool:
	if _probe_shape == null:
		return false

	var cache_key: String = _point_cache_key(point)
	var cached: Variant = _cache_get(_point_blocked_cache, cache_key)
	if cached != null:
		return bool(cached)

	_shape_query.transform = Transform3D(Basis.IDENTITY, point)
	var blocked: bool = not get_world_3d().direct_space_state.intersect_shape(_shape_query, 4).is_empty()
	_cache_set(_point_blocked_cache, cache_key, blocked)
	return blocked


func _compute_lane_steer(target: Vector3, up: Vector3) -> Vector3:
	var forward: Vector3 = _planar_forward(target - global_position, up)
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	var right: Vector3 = forward.cross(up).normalized()
	var origin: Vector3 = global_position + up * 0.15
	var center_blocked: bool = _segment_hits_obstacle(origin, origin + forward * lane_probe_distance)
	if not center_blocked:
		return Vector3.ZERO

	var left_dir: Vector3 = (forward - right * 0.55).normalized()
	var right_dir: Vector3 = (forward + right * 0.55).normalized()
	var left_blocked: bool = _segment_hits_obstacle(origin, origin + left_dir * lane_probe_distance)
	var right_blocked: bool = _segment_hits_obstacle(origin, origin + right_dir * lane_probe_distance)

	if left_blocked and right_blocked:
		return -forward * 0.6
	if left_blocked and not right_blocked:
		_detour_side_bias = 1.0
		return right
	if right_blocked and not left_blocked:
		_detour_side_bias = -1.0
		return -right
	if is_zero_approx(_detour_side_bias):
		_detour_side_bias = 1.0 if randf() > 0.5 else -1.0
	return right * _detour_side_bias


func _update_style(delta: float, facing_target: Vector3) -> void:
	if visual_root == null:
		return

	var wobble_radians: float = deg_to_rad(wobble_degrees)
	var bob: float = sin(_time * bob_speed) * bob_amplitude
	var wobble_x: float = sin(_time * wobble_speed) * wobble_radians
	var wobble_z: float = cos(_time * wobble_speed * 1.13) * wobble_radians * 0.75

	visual_root.position = Vector3(0.0, bob, 0.0)
	visual_root.rotation = Vector3(wobble_x, 0.0, wobble_z)

	var speed_ratio: float = clampf(_velocity.length() / maxf(max_speed, 0.001), 0.0, 1.0)
	var angry_weight: float = clampf(_angry_timer / maxf(angry_duration, 0.001), 0.0, 1.0)
	var excitement: float = speed_ratio + (0.4 if _recovery_mode else 0.0) + angry_weight * 0.8

	if propeller_pivot != null:
		propeller_pivot.rotate_y((propeller_spin_speed + excitement * 22.0) * delta)
	if side_propeller_pivot_l != null:
		side_propeller_pivot_l.rotate_z((side_propeller_spin_speed + excitement * 16.0) * delta)
	if side_propeller_pivot_r != null:
		side_propeller_pivot_r.rotate_z(-(side_propeller_spin_speed + excitement * 16.0) * delta)

	if _angry_timer > 0.0:
		_angry_timer = maxf(_angry_timer - delta, 0.0)

	_update_face_expression(delta, excitement)

	var up: Vector3 = _frame_player_up
	var look_target: Vector3 = facing_target
	if _player != null:
		var focus_point: Vector3 = _player.global_position + up * 1.2
		var distance_to_player: float = global_position.distance_to(_player.global_position)
		var desired_distance: float = clampf(follow_distance, min_follow_distance, maxf(min_follow_distance + 0.2, orbit_radius_max))
		var focus_blend: float = 0.0
		if dialogue_look_distance > min_follow_distance:
			focus_blend = 1.0 - clampf((distance_to_player - min_follow_distance) / (dialogue_look_distance - min_follow_distance), 0.0, 1.0)
		# When the companion has settled next to the player, always face them.
		if absf(distance_to_player - desired_distance) <= settle_distance_tolerance:
			look_target = focus_point
		else:
			look_target = facing_target.lerp(focus_point, focus_blend * look_at_player_weight)

	var desired_forward: Vector3 = _planar_forward(look_target - global_position, up)
	if desired_forward.length_squared() < 0.0001:
		return

	var right: Vector3 = desired_forward.cross(up).normalized()
	var back: Vector3 = right.cross(up).normalized()
	var target_basis: Basis = Basis(right, up, back).orthonormalized()
	var current_q: Quaternion = global_basis.get_rotation_quaternion().normalized()
	var target_q: Quaternion = target_basis.get_rotation_quaternion().normalized()
	if current_q.dot(target_q) < 0.0:
		target_q = -target_q
	global_basis = Basis(current_q.slerp(target_q, clampf(delta * look_lerp_speed, 0.0, 1.0))).orthonormalized()


func _get_player_up(player_node: Node3D) -> Vector3:
	if player_node == null:
		return Vector3.UP

	var candidate: Variant = player_node.get("up_direction")
	if typeof(candidate) == TYPE_VECTOR3:
		var up: Vector3 = candidate
		if not up.is_zero_approx():
			return up.normalized()
	return Vector3.UP


func _planar_forward(forward_like: Vector3, up: Vector3) -> Vector3:
	var projected: Vector3 = (forward_like - up * forward_like.dot(up)).normalized()
	if projected.length_squared() > 0.0001:
		return projected
	var fallback: Vector3 = Vector3.FORWARD
	if absf(up.dot(fallback)) > 0.9:
		fallback = Vector3.RIGHT
	return (fallback - up * fallback.dot(up)).normalized()


func _update_face_expression(delta: float, excitement: float) -> void:
	if eye_l == null or eye_r == null or mouth == null:
		return

	var angry_weight: float = clampf(_angry_timer / maxf(angry_duration, 0.001), 0.0, 1.0)
	_blink_timer += delta
	var blink_progress: float = 0.0
	if angry_weight < 0.1 and _blink_timer >= _blink_interval:
		blink_progress = clampf((_blink_timer - _blink_interval) * 14.0, 0.0, 1.0)
		var blink_curve: float = 1.0 - absf(blink_progress * 2.0 - 1.0)
		var eye_height: float = lerpf(0.08, 0.012, blink_curve)
		eye_l.scale.y = eye_height / 0.08
		eye_r.scale.y = eye_height / 0.08
		if blink_progress >= 1.0:
			_blink_timer = 0.0
			_blink_interval = randf_range(1.4, 3.2)
			eye_l.scale.y = 1.0
			eye_r.scale.y = 1.0
	else:
		eye_l.scale.y = 1.0
		eye_r.scale.y = 1.0

	var grin_wobble: float = sin(_time * (3.0 + excitement * 2.0)) * 0.24
	var sad_curve: float = -0.45 + sin(_time * 9.0) * 0.06
	mouth.rotation.z = lerpf(grin_wobble, sad_curve, angry_weight)
	mouth.position.y = lerpf(-0.08 + sin(_time * (5.4 + excitement * 3.0)) * 0.01, -0.13, angry_weight)
	eye_l.rotation.z = lerpf(0.0, -0.42, angry_weight)
	eye_r.rotation.z = lerpf(0.0, 0.42, angry_weight)
	eye_l.position.y = lerpf(0.08, 0.03, angry_weight)
	eye_r.position.y = lerpf(0.08, 0.03, angry_weight)

	if screen != null and screen.material_override is StandardMaterial3D:
		var mat := screen.material_override as StandardMaterial3D
		mat.emission = _normal_screen_emission.lerp(_angry_screen_emission, angry_weight)


func _on_hit_area_input_event(_camera: Camera3D, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return

	_trigger_click_reaction(event_position)


func _update_orbit_anchor(delta: float) -> void:
	_orbit_timer -= delta
	if _orbit_timer <= 0.0:
		_pick_new_orbit_anchor()


func _pick_new_orbit_anchor(force_random: bool = false) -> void:
	if force_random:
		_orbit_angle = randf() * TAU
	else:
		_orbit_angle += randf_range(0.2, 0.55) * (1.0 if randf() > 0.5 else -1.0)
	_orbit_radius = randf_range(maxf(min_follow_distance + 0.35, orbit_radius_min), maxf(orbit_radius_max, orbit_radius_min + 0.5))
	_orbit_timer = randf_range(orbit_change_interval_min, maxf(orbit_change_interval_max, orbit_change_interval_min + 0.2))


func _update_detour_state(desired_target: Vector3, delta: float) -> Vector3:
	if _has_detour:
		_detour_timer -= delta
		var detour_distance: float = global_position.distance_to(_detour_target)
		if detour_distance < _detour_last_distance - min_progress_distance * 0.35:
			_detour_last_distance = detour_distance
			_detour_progress_timer = 0.0
		else:
			_detour_progress_timer += delta

		var reached_detour: bool = global_position.distance_squared_to(_detour_target) < 0.85 * 0.85
		var timed_out: bool = _detour_timer <= 0.0
		var no_progress: bool = _detour_progress_timer >= detour_progress_timeout
		if reached_detour or timed_out:
			_clear_detour_state()
		elif no_progress:
			_detour_fail_count += 1
			if not _pick_detour_target(desired_target, true):
				_clear_detour_state()
				_detour_fail_count += 1

	if not _has_detour and (_segment_hits_obstacle(global_position, desired_target) or not _is_lane_clear(global_position, desired_target)):
		_pick_detour_target(desired_target, false)

	return _detour_target if _has_detour else desired_target


func _pick_detour_target(desired_target: Vector3, escalate: bool) -> bool:
	var expansion: int = _detour_fail_count + (1 if escalate else 0)
	var candidates: Array[Vector3] = _build_detour_candidates(desired_target, expansion)
	var best_target: Vector3 = Vector3.ZERO
	var best_score: float = INF
	var eval_result: Array = _score_candidates_with_budget(candidates, desired_target, _detour_candidate_cursor)
	if eval_result.size() == 3:
		best_score = eval_result[0]
		best_target = eval_result[1]
		_detour_candidate_cursor = eval_result[2]

	if best_score >= INF * 0.5:
		return false

	_has_detour = true
	_detour_target = best_target
	_detour_timer = detour_commit_duration + float(expansion) * 0.25
	_detour_progress_timer = 0.0
	_detour_last_distance = global_position.distance_to(_detour_target)
	return true


func _build_detour_candidates(desired_target: Vector3, expansion_level: int) -> Array[Vector3]:
	var up: Vector3 = _frame_player_up
	var forward: Vector3 = _planar_forward(desired_target - global_position, up)
	var right: Vector3 = forward.cross(up).normalized()
	var expanded_radius: float = detour_base_radius + detour_expand_step * float(expansion_level)
	var candidates: Array[Vector3] = _detour_candidate_buffer
	candidates.clear()

	candidates.append(global_position + right * expanded_radius)
	candidates.append(global_position - right * expanded_radius)
	candidates.append(global_position + forward * (expanded_radius * 0.75) + right * expanded_radius * 0.85)
	candidates.append(global_position + forward * (expanded_radius * 0.75) - right * expanded_radius * 0.85)

	for ring_scale: float in [1.0, 1.5, 2.1]:
		var radius: float = expanded_radius * ring_scale
		for step: int in 12:
			var angle: float = TAU * float(step) / 12.0
			var planar_offset: Vector3 = forward * cos(angle) * radius + right * sin(angle) * radius
			for lift: float in [0.0, 0.45]:
				candidates.append(global_position + planar_offset + up * lift)

	var desired_mid: Vector3 = global_position.lerp(desired_target, 0.5)
	candidates.append(desired_mid + right * expanded_radius)
	candidates.append(desired_mid - right * expanded_radius)

	return candidates


func _score_route_candidate(candidate: Vector3, desired_target: Vector3) -> float:
	if _is_point_blocked(candidate):
		return INF
	if not _is_lane_clear(global_position, candidate):
		return INF

	var score: float = 0.0
	score += candidate.distance_to(desired_target) * 0.9
	score += candidate.distance_to(global_position) * 0.35
	if not _is_lane_clear(candidate, desired_target):
		score += 1.8

	if _player != null:
		var player_distance: float = candidate.distance_to(_player.global_position)
		if player_distance < min_follow_distance:
			score += (min_follow_distance - player_distance) * 4.0

	var up: Vector3 = _frame_player_up
	var forward: Vector3 = _planar_forward(desired_target - global_position, up)
	var right: Vector3 = forward.cross(up).normalized()
	var side_sign: float = signf((candidate - global_position).dot(right))
	if side_sign != 0.0 and side_sign == signf(_detour_side_bias):
		score -= 0.15
	else:
		score += 0.15

	return score


func _score_candidates_with_budget(candidates: Array[Vector3], desired_target: Vector3, start_cursor: int) -> Array:
	var count: int = candidates.size()
	if count == 0:
		return [INF, Vector3.ZERO, 0]

	var budget: int = mini(maxi(route_score_budget_per_tick, 1), count)
	var cursor: int = posmod(start_cursor, count)
	var best_score: float = INF
	var best_target: Vector3 = Vector3.ZERO
	for i: int in budget:
		var index: int = (cursor + i) % count
		var candidate: Vector3 = candidates[index]
		var score: float = _score_route_candidate(candidate, desired_target)
		if score < best_score:
			best_score = score
			best_target = candidate
	var next_cursor: int = (cursor + budget) % count
	return [best_score, best_target, next_cursor]


func _clear_query_caches() -> void:
	_point_blocked_cache.clear()
	_segment_hits_cache.clear()
	_lane_clear_cache.clear()
	_resolve_candidate_cursor = 0
	_detour_candidate_cursor = 0


func _cache_get(cache: Dictionary, key: String) -> Variant:
	var entry: Dictionary = cache.get(key, {})
	if entry.is_empty():
		return null
	var frame: int = int(entry.get("frame", -999999))
	if _physics_frame_counter - frame > query_cache_ttl_frames:
		cache.erase(key)
		return null
	return entry.get("value")


func _cache_set(cache: Dictionary, key: String, value: bool) -> void:
	cache.set(key, {"frame": _physics_frame_counter, "value": value})


func _point_cache_key(point: Vector3) -> String:
	return _vector_cache_key(point)


func _segment_cache_key(from: Vector3, to: Vector3) -> String:
	return "%s|%s" % [_vector_cache_key(from), _vector_cache_key(to)]


func _lane_cache_key(from: Vector3, to: Vector3, up: Vector3) -> String:
	return "%s|%s|%s" % [_vector_cache_key(from), _vector_cache_key(to), _vector_cache_key(up)]


func _vector_cache_key(v: Vector3) -> String:
	var quant: float = maxf(query_cache_quantization, 0.001)
	var scale: float = 1.0 / quant
	var ix: int = int(round(v.x * scale))
	var iy: int = int(round(v.y * scale))
	var iz: int = int(round(v.z * scale))
	return "%d,%d,%d" % [ix, iy, iz]


func _clear_detour_state() -> void:
	_has_detour = false
	_detour_target = Vector3.ZERO
	_detour_timer = 0.0
	_detour_progress_timer = 0.0
	_detour_last_distance = INF
	_detour_side_bias = 1.0 if randf() > 0.5 else -1.0


func _try_click_reaction(mouse_position: Vector2) -> void:
	if _player == null:
		return
	var camera: Camera3D = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return

	var viewport: Viewport = get_viewport()
	var ray_position: Vector2 = mouse_position
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		ray_position = viewport.get_visible_rect().size * 0.5

	var ray_origin: Vector3 = camera.project_ray_origin(ray_position)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(ray_position) * interaction_max_reach
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, click_raycast_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_player]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var hit_node: Node = hit.get("collider") as Node
	if hit_node == null:
		return
	if hit_area != null and hit_node != hit_area and not hit_area.is_ancestor_of(hit_node):
		return
	if hit_node != self and not is_ancestor_of(hit_node):
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	if ray_origin.distance_squared_to(hit_position) > interaction_max_reach * interaction_max_reach:
		return
	_trigger_click_reaction(hit_position)


func _trigger_click_reaction(hit_position: Vector3) -> void:
	var frame_id: int = Engine.get_process_frames()
	if _last_click_reaction_frame == frame_id:
		return
	_last_click_reaction_frame = frame_id

	var away: Vector3
	if _player != null:
		away = (global_position - _player.global_position).normalized()
	else:
		away = (global_position - hit_position).normalized()
	if away.length_squared() < 0.0001:
		away = global_basis.z.normalized()

	var up: Vector3 = _get_player_up(_player)
	_velocity += away * click_push_strength + up * click_upward_boost
	_knockback_timer = knockback_hold_duration
	_angry_timer = maxf(angry_duration, knockback_hold_duration + 0.6)
	_orbit_timer = maxf(_orbit_timer, 1.2)


func _refresh_query_excludes() -> void:
	var excludes: Array[RID] = []
	if hit_area != null:
		excludes.append(hit_area.get_rid())
	if _player != null and _player is CollisionObject3D:
		excludes.append((_player as CollisionObject3D).get_rid())
	_ray_query.exclude = excludes
	_shape_query.exclude = excludes
	_clear_query_caches()
