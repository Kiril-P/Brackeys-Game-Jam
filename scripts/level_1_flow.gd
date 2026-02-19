extends Node

class_name Level1Flow

signal tutorial_line_requested(line_id: StringName, subtitle: String, audio_path: String, fallback_duration: float)

@export_node_path("Node3D") var player_path: NodePath = NodePath("../../Player")
@export_node_path("Area3D") var stairs_loop_trigger_path: NodePath = NodePath("../StairsLoopTrigger")
@export_node_path("Area3D") var reverse_reveal_trigger_path: NodePath = NodePath("../ReverseRevealTrigger")
@export_node_path("CollisionShape3D") var dense_gate_collision_path: NodePath = NodePath("../DenseGate/CollisionShape3D")
@export_node_path("Area3D") var dense_choice_a_path: NodePath = NodePath("../DenseChoiceTriggerA")
@export_node_path("Area3D") var dense_choice_b_path: NodePath = NodePath("../DenseChoiceTriggerB")
@export_node_path("Area3D") var dense_choice_c_path: NodePath = NodePath("../DenseChoiceTriggerC")
@export_node_path("Portal3D") var dense_progress_portal_path: NodePath = NodePath("../CSGBox3D10/Portal3D3")
@export_node_path("Portal3D") var dense_target_state_0_path: NodePath = NodePath("../CSGBox3D10/Portal3D")
@export_node_path("Portal3D") var dense_target_state_1_path: NodePath = NodePath("../CSGBox3D10/Portal3D2")
@export_node_path("Portal3D") var dense_target_state_2_path: NodePath = NodePath("../Portal3D3")
@export_node_path("Node3D") var dense_state_indicator_0_path: NodePath = NodePath("../DenseStateIndicator/State0")
@export_node_path("Node3D") var dense_state_indicator_1_path: NodePath = NodePath("../DenseStateIndicator/State1")
@export_node_path("Node3D") var dense_state_indicator_2_path: NodePath = NodePath("../DenseStateIndicator/State2")
@export_node_path("Area3D") var final_orientation_trigger_path: NodePath = NodePath("../FinalOrientationSealTrigger")
@export_node_path("CollisionShape3D") var return_gate_collision_path: NodePath = NodePath("../ReturnGate/CollisionShape3D")

@export var required_final_up: Vector3 = Vector3.LEFT
@export_range(5.0, 90.0, 1.0) var stairs_hint_delay_seconds: float = 18.0
@export_range(5.0, 120.0, 1.0) var dense_hint_delay_seconds: float = 22.0
@export_range(1.0, 20.0, 0.5) var hint_cooldown_seconds: float = 5.0

const STATE_ENTRY: int = 0
const STATE_STAIRS_LOOP: int = 1
const STATE_DENSE_PORTAL: int = 2
const STATE_FINAL_SEAL: int = 3
const STATE_RETURN_OPEN: int = 4

const CHOICE_A: StringName = &"A"
const CHOICE_B: StringName = &"B"
const CHOICE_C: StringName = &"C"

const LINE_STAIRS_INTRO: StringName = &"level1_stairs_intro"
const LINE_STAIRS_BACKTRACK_NUDGE: StringName = &"level1_stairs_backtrack_nudge"
const LINE_DENSE_INTRO: StringName = &"level1_dense_intro"
const LINE_DENSE_STATE_HINT: StringName = &"level1_dense_state_hint"
const LINE_FINAL_SEAL_HINT: StringName = &"level1_final_seal_hint"
const LINE_RETURN_HUB_HINT: StringName = &"level1_return_hub_hint"

var stairs_loops_completed: int = 0
var dense_route_state: int = 0
var dense_fail_count: int = 0
var final_seal_passed: bool = false

var _state: int = STATE_ENTRY
var _dense_gate_open: bool = false
var _stairs_stall_timer: float = 0.0
var _dense_stall_timer: float = 0.0
var _hint_cooldown: float = 0.0
var _stairs_hint_tier: int = 0
var _dense_hint_tier: int = 0

var _player: Node3D
var _stairs_loop_trigger: Area3D
var _reverse_reveal_trigger: Area3D
var _dense_gate_collision: CollisionShape3D
var _dense_choice_a: Area3D
var _dense_choice_b: Area3D
var _dense_choice_c: Area3D
var _dense_progress_portal: Portal3D
var _dense_target_state_0: Portal3D
var _dense_target_state_1: Portal3D
var _dense_target_state_2: Portal3D
var _dense_state_indicator_0: Node3D
var _dense_state_indicator_1: Node3D
var _dense_state_indicator_2: Node3D
var _final_orientation_trigger: Area3D
var _return_gate_collision: CollisionShape3D


func _ready() -> void:
	_resolve_refs()
	_connect_triggers()
	_set_dense_gate_open(false)
	_set_return_gate_open(false)
	_apply_dense_route_state(0)
	_emit_tutorial(LINE_STAIRS_INTRO, "Both stair paths loop ahead. Repeat once, then break the pattern.", 3.8)


func _physics_process(delta: float) -> void:
	_hint_cooldown = maxf(_hint_cooldown - delta, 0.0)
	_process_stairs_hint_tiers(delta)
	_process_dense_hint_tiers(delta)


func _resolve_refs() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_stairs_loop_trigger = get_node_or_null(stairs_loop_trigger_path) as Area3D
	_reverse_reveal_trigger = get_node_or_null(reverse_reveal_trigger_path) as Area3D
	_dense_gate_collision = get_node_or_null(dense_gate_collision_path) as CollisionShape3D
	_dense_choice_a = get_node_or_null(dense_choice_a_path) as Area3D
	_dense_choice_b = get_node_or_null(dense_choice_b_path) as Area3D
	_dense_choice_c = get_node_or_null(dense_choice_c_path) as Area3D
	_dense_progress_portal = get_node_or_null(dense_progress_portal_path) as Portal3D
	_dense_target_state_0 = get_node_or_null(dense_target_state_0_path) as Portal3D
	_dense_target_state_1 = get_node_or_null(dense_target_state_1_path) as Portal3D
	_dense_target_state_2 = get_node_or_null(dense_target_state_2_path) as Portal3D
	_dense_state_indicator_0 = get_node_or_null(dense_state_indicator_0_path) as Node3D
	_dense_state_indicator_1 = get_node_or_null(dense_state_indicator_1_path) as Node3D
	_dense_state_indicator_2 = get_node_or_null(dense_state_indicator_2_path) as Node3D
	_final_orientation_trigger = get_node_or_null(final_orientation_trigger_path) as Area3D
	_return_gate_collision = get_node_or_null(return_gate_collision_path) as CollisionShape3D


func _connect_triggers() -> void:
	if _stairs_loop_trigger != null and not _stairs_loop_trigger.body_entered.is_connected(_on_stairs_loop_trigger_entered):
		_stairs_loop_trigger.body_entered.connect(_on_stairs_loop_trigger_entered)
	if _reverse_reveal_trigger != null and not _reverse_reveal_trigger.body_entered.is_connected(_on_reverse_reveal_trigger_entered):
		_reverse_reveal_trigger.body_entered.connect(_on_reverse_reveal_trigger_entered)
	if _dense_choice_a != null and not _dense_choice_a.body_entered.is_connected(_on_dense_choice_a_entered):
		_dense_choice_a.body_entered.connect(_on_dense_choice_a_entered)
	if _dense_choice_b != null and not _dense_choice_b.body_entered.is_connected(_on_dense_choice_b_entered):
		_dense_choice_b.body_entered.connect(_on_dense_choice_b_entered)
	if _dense_choice_c != null and not _dense_choice_c.body_entered.is_connected(_on_dense_choice_c_entered):
		_dense_choice_c.body_entered.connect(_on_dense_choice_c_entered)
	if _final_orientation_trigger != null and not _final_orientation_trigger.body_entered.is_connected(_on_final_seal_entered):
		_final_orientation_trigger.body_entered.connect(_on_final_seal_entered)


func _on_stairs_loop_trigger_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	stairs_loops_completed += 1
	if _state <= STATE_STAIRS_LOOP:
		_state = STATE_STAIRS_LOOP
		_stairs_stall_timer = 0.0


func _on_reverse_reveal_trigger_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	if stairs_loops_completed <= 0:
		_emit_tutorial(LINE_STAIRS_BACKTRACK_NUDGE, "First confirm the loop once. Then return while facing forward and walking backward.", 3.8)
		return
	if not _is_player_moving_backward():
		dense_fail_count += 1
		_emit_tutorial(LINE_STAIRS_BACKTRACK_NUDGE, "Walk backward through this lane to break the loop.", 3.0)
		return
	if _dense_gate_open:
		return

	_set_dense_gate_open(true)
	_state = STATE_DENSE_PORTAL
	_stairs_stall_timer = 0.0
	_dense_stall_timer = 0.0
	_emit_tutorial(LINE_DENSE_INTRO, "Dense routes ahead. Each doorway choice changes the route state.", 3.6)


func _on_dense_choice_a_entered(body: Node3D) -> void:
	_on_dense_choice_trigger_entered(CHOICE_A, body)


func _on_dense_choice_b_entered(body: Node3D) -> void:
	_on_dense_choice_trigger_entered(CHOICE_B, body)


func _on_dense_choice_c_entered(body: Node3D) -> void:
	_on_dense_choice_trigger_entered(CHOICE_C, body)


func _on_dense_choice_trigger_entered(choice_id: StringName, body: Node3D) -> void:
	if not _is_player_body(body):
		return
	if not _dense_gate_open or final_seal_passed:
		return
	if _state < STATE_DENSE_PORTAL:
		return

	_advance_dense_state_from_choice(choice_id)


func _advance_dense_state_from_choice(choice_id: StringName) -> void:
	var previous: int = dense_route_state
	match dense_route_state:
		0:
			match choice_id:
				CHOICE_A:
					dense_route_state = 1
				CHOICE_B:
					dense_route_state = 0
				CHOICE_C:
					dense_route_state = 2
		1:
			match choice_id:
				CHOICE_A:
					dense_route_state = 1
				CHOICE_B:
					dense_route_state = 2
				CHOICE_C:
					dense_route_state = 0
		2:
			dense_route_state = 2

	if dense_route_state != 2:
		dense_fail_count += 1
	else:
		_dense_fail_count_decay()

	_apply_dense_route_state(dense_route_state)
	_dense_stall_timer = 0.0

	if dense_route_state == 2 and previous != 2:
		_state = STATE_FINAL_SEAL
		_emit_tutorial(LINE_FINAL_SEAL_HINT, "Route stabilized. Align gravity to the marked orientation to unlock the return gate.", 4.2)
		return

	if dense_route_state != 2 and dense_fail_count >= 2:
		_emit_tutorial(LINE_DENSE_STATE_HINT, "State matters more than speed. Try a different doorway order.", 3.0)


func _apply_dense_route_state(state: int) -> void:
	dense_route_state = clampi(state, 0, 2)
	if _dense_progress_portal != null:
		var target: Portal3D = _dense_target_state_0
		if dense_route_state == 1:
			target = _dense_target_state_1
		elif dense_route_state == 2:
			target = _dense_target_state_2
		if target != null:
			_dense_progress_portal.exit_portal = target

	if _dense_state_indicator_0 != null:
		_dense_state_indicator_0.visible = dense_route_state == 0
	if _dense_state_indicator_1 != null:
		_dense_state_indicator_1.visible = dense_route_state == 1
	if _dense_state_indicator_2 != null:
		_dense_state_indicator_2.visible = dense_route_state == 2


func _on_final_seal_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	if _state < STATE_FINAL_SEAL:
		return
	if final_seal_passed:
		return

	var current_up: Vector3 = _read_player_up()
	var target_up: Vector3 = required_final_up.normalized() if not required_final_up.is_zero_approx() else Vector3.LEFT
	if current_up.dot(target_up) < 0.98:
		dense_fail_count += 1
		_emit_tutorial(LINE_FINAL_SEAL_HINT, "Wrong alignment. Match your gravity to the seal direction first.", 3.2)
		return

	final_seal_passed = true
	_state = STATE_RETURN_OPEN
	_set_return_gate_open(true)
	_emit_tutorial(LINE_RETURN_HUB_HINT, "Seal accepted. Return through the hub gate to lock this completion.", 3.5)


func is_completion_ready() -> bool:
	return final_seal_passed and _state >= STATE_RETURN_OPEN


func _set_dense_gate_open(value: bool) -> void:
	_dense_gate_open = value
	if _dense_gate_collision != null:
		_dense_gate_collision.disabled = value


func _set_return_gate_open(value: bool) -> void:
	if _return_gate_collision != null:
		_return_gate_collision.disabled = value


func _process_stairs_hint_tiers(delta: float) -> void:
	if _state > STATE_STAIRS_LOOP:
		return
	if stairs_loops_completed <= 0:
		return
	if _dense_gate_open:
		return

	_stairs_stall_timer += delta
	if _stairs_hint_tier == 0 and _stairs_stall_timer >= stairs_hint_delay_seconds:
		_stairs_hint_tier = 1
		_emit_tutorial(LINE_STAIRS_BACKTRACK_NUDGE, "You already proved the loop. Backtrack while walking backward to force a change.", 3.8)
		return
	if _stairs_hint_tier == 1 and _stairs_stall_timer >= stairs_hint_delay_seconds * 1.9:
		_stairs_hint_tier = 2
		_emit_tutorial(LINE_STAIRS_BACKTRACK_NUDGE, "Keep your view forward, hold back movement, and cross the reveal lane again.", 3.6)


func _process_dense_hint_tiers(delta: float) -> void:
	if _state < STATE_DENSE_PORTAL:
		return
	if final_seal_passed:
		return
	if dense_route_state == 2:
		return

	_dense_stall_timer += delta
	if _dense_hint_tier == 0 and _dense_stall_timer >= dense_hint_delay_seconds:
		_dense_hint_tier = 1
		_emit_tutorial(LINE_DENSE_STATE_HINT, "Doorways are state switches. Look at the indicator, then pick the next door.", 3.7)
		return
	if _dense_hint_tier == 1 and _dense_stall_timer >= dense_hint_delay_seconds * 2.0:
		_dense_hint_tier = 2
		_emit_tutorial(LINE_DENSE_STATE_HINT, "Target indicator state is 2. Reach it, then head to the seal.", 3.2)


func _dense_fail_count_decay() -> void:
	dense_fail_count = maxi(dense_fail_count - 1, 0)


func _emit_tutorial(line_id: StringName, subtitle: String, fallback_duration: float) -> void:
	if _hint_cooldown > 0.0:
		return
	tutorial_line_requested.emit(line_id, subtitle, _audio_path(String(line_id)), maxf(fallback_duration, 0.1))
	_hint_cooldown = hint_cooldown_seconds


func _audio_path(line_name: String) -> String:
	return "res://audio/companion/tutorial/%s.wav" % line_name


func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return false
	if body == _player:
		return true
	return _player.is_ancestor_of(body)


func _read_player_up() -> Vector3:
	if _player == null:
		return Vector3.UP
	var candidate: Variant = _player.get("up_direction")
	if typeof(candidate) == TYPE_VECTOR3:
		var up: Vector3 = candidate
		if not up.is_zero_approx():
			return up.normalized()
	return Vector3.UP


func _is_player_moving_backward() -> bool:
	if _player == null:
		return false

	var velocity_variant: Variant = _player.get("velocity")
	if typeof(velocity_variant) != TYPE_VECTOR3:
		return false
	var velocity: Vector3 = velocity_variant
	if velocity.length_squared() < 0.01:
		return false

	var camera: Camera3D = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return false
	var view_forward: Vector3 = -camera.global_basis.z.normalized()
	return velocity.normalized().dot(view_forward) <= -0.2
