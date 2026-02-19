extends Node

class_name WorldGameplayFlow

@export_node_path("Node3D") var player_path: NodePath = NodePath("../Player")
@export_node_path("Node3D") var companion_path: NodePath = NodePath("../CompanionTV")
@export_node_path("CanvasLayer") var hud_path: NodePath = NodePath("../HUD")
@export_node_path("Node3D") var level_cube_root_path: NodePath = NodePath("../Level Cube")
@export_node_path("Portal3D") var cube_portal_level_1_path: NodePath = NodePath("../Level Cube/Portal3D")
@export_node_path("Portal3D") var cube_portal_level_2_path: NodePath = NodePath("../Level Cube/Portal3D3")
@export_node_path("Portal3D") var cube_portal_level_3_path: NodePath = NodePath("../Level Cube/Portal3D4")
@export_node_path("Portal3D") var cube_portal_level_4_path: NodePath = NodePath("../Level Cube/Portal3D5")
@export_node_path("Area3D") var level1_complete_trigger_path: NodePath = NodePath("../Level 1/Level1CompleteTrigger")
@export_node_path("Node") var level1_flow_path: NodePath = NodePath("../Level 1/Level1Flow")
@export var level1_starts_unlocked: bool = true
@export_node_path("StaticBody3D") var cube_blocker_level_1_path: NodePath = NodePath("../Level Cube/Portal3D/LockBlocker")
@export_node_path("StaticBody3D") var cube_blocker_level_2_path: NodePath = NodePath("../Level Cube/Portal3D3/LockBlocker")
@export_node_path("StaticBody3D") var cube_blocker_level_3_path: NodePath = NodePath("../Level Cube/Portal3D4/LockBlocker")
@export_node_path("StaticBody3D") var cube_blocker_level_4_path: NodePath = NodePath("../Level Cube/Portal3D5/LockBlocker")
@export_range(0.01, 2.0, 0.01) var lock_blocker_outward_offset: float = 0.52
@export var lock_blocker_size: Vector3 = Vector3(2.95, 2.95, 0.12)
@export_range(0.01, 1.0, 0.01) var lock_blocker_thickness: float = 0.12
@export_range(0.0, 1.0, 0.01) var lock_blocker_alpha: float = 0.55
@export_range(0.0, 8.0, 0.1) var lock_blocker_emission_energy: float = 8.0
@export_range(0.0, 12.0, 0.1) var lock_laser_bar_emission_energy: float = 12.0
@export var show_lock_blocker_panel: bool = false
@export_range(0.0, 1.0, 0.01) var lock_visual_outward_from_portal: float = 0.08
@export_range(-0.1, 0.1, 0.01) var lock_visual_depth_bias: float = 0.0

const LEVEL_1: StringName = &"level_1"
const LEVEL_2: StringName = &"level_2"
const LEVEL_3: StringName = &"level_3"
const LEVEL_4: StringName = &"level_4"

const TUTORIAL_HUB_INTRO: StringName = &"hub_intro"
const TUTORIAL_GRAVITY_TEACH: StringName = &"gravity_teach"
const TUTORIAL_CUBE_TEACH: StringName = &"cube_teach"
const TUTORIAL_LEVEL1_ENTER: StringName = &"level1_enter"
const TUTORIAL_LEVEL1_CORRECT_PATH: StringName = &"level1_correct_path"
const TUTORIAL_LEVEL1_UNLOCK_L2: StringName = &"level1_unlock_l2"
const TUTORIAL_LOCKED_SIDE: StringName = &"locked_side"

const CUBE_APPROACH_DISTANCE: float = 8.0
const LOCKED_SIDE_FEEDBACK_DISTANCE: float = 3.2
const LOCKED_SIDE_FACING_DOT: float = 0.58
const LOCKED_FEEDBACK_COOLDOWN: float = 4.5

var _progress
var _player: Node3D
var _companion: Node3D
var _hud: CanvasLayer
var _level_cube_root: Node3D
var _cube_portals: Dictionary = {}
var _cube_lock_blockers: Dictionary = {}
var _level1_complete_trigger: Area3D
var _level1_flow: Node

var _locked_feedback_timer: float = 0.0
var _level1_trigger_reached: bool = false
var _last_player_up: Vector3 = Vector3.UP


func _ready() -> void:
	_progress = get_node_or_null("/root/GameProgress")
	if _progress == null:
		push_warning("WorldGameplayFlow: GameProgress autoload is missing.")

	_resolve_references()
	_configure_lock_blockers()
	_align_lock_blockers()
	_connect_signals()
	_apply_portal_lock_state()
	_start_onboarding()


func _physics_process(delta: float) -> void:
	_locked_feedback_timer = maxf(_locked_feedback_timer - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		return

	_process_tutorial_steps()
	_process_locked_side_feedback()


func _resolve_references() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_companion = get_node_or_null(companion_path) as Node3D
	_hud = get_node_or_null(hud_path) as CanvasLayer
	_level_cube_root = get_node_or_null(level_cube_root_path) as Node3D
	_level1_complete_trigger = get_node_or_null(level1_complete_trigger_path) as Area3D
	_level1_flow = get_node_or_null(level1_flow_path)

	_cube_portals.clear()
	_cube_portals[LEVEL_1] = get_node_or_null(cube_portal_level_1_path) as Portal3D
	_cube_portals[LEVEL_2] = get_node_or_null(cube_portal_level_2_path) as Portal3D
	_cube_portals[LEVEL_3] = get_node_or_null(cube_portal_level_3_path) as Portal3D
	_cube_portals[LEVEL_4] = get_node_or_null(cube_portal_level_4_path) as Portal3D

	_cube_lock_blockers.clear()
	_cube_lock_blockers[LEVEL_1] = get_node_or_null(cube_blocker_level_1_path) as StaticBody3D
	_cube_lock_blockers[LEVEL_2] = get_node_or_null(cube_blocker_level_2_path) as StaticBody3D
	_cube_lock_blockers[LEVEL_3] = get_node_or_null(cube_blocker_level_3_path) as StaticBody3D
	_cube_lock_blockers[LEVEL_4] = get_node_or_null(cube_blocker_level_4_path) as StaticBody3D

	for level_id_var: Variant in _cube_lock_blockers.keys():
		var level_id: StringName = level_id_var
		if _cube_lock_blockers.get(level_id) == null:
			push_warning("WorldGameplayFlow: Missing lock blocker node for %s." % String(level_id))

	_last_player_up = _read_player_up()


func _connect_signals() -> void:
	if _progress != null and not _progress.progression_changed.is_connected(_on_progression_changed):
		_progress.progression_changed.connect(_on_progression_changed)

	var level1_cube_portal: Portal3D = _cube_portals.get(LEVEL_1) as Portal3D
	if level1_cube_portal != null:
		if not level1_cube_portal.on_teleport.is_connected(_on_level1_cube_portal_teleport):
			level1_cube_portal.on_teleport.connect(_on_level1_cube_portal_teleport)
		if not level1_cube_portal.on_teleport_receive.is_connected(_on_level1_cube_portal_receive):
			level1_cube_portal.on_teleport_receive.connect(_on_level1_cube_portal_receive)

	if _level1_complete_trigger != null \
			and not _level1_complete_trigger.body_entered.is_connected(_on_level1_complete_trigger_entered):
		_level1_complete_trigger.body_entered.connect(_on_level1_complete_trigger_entered)

	if _companion != null and _companion.has_signal("tutorial_line_started"):
		var started_cb: Callable = Callable(self, "_on_companion_tutorial_line_started")
		if not _companion.is_connected("tutorial_line_started", started_cb):
			_companion.connect("tutorial_line_started", started_cb)

	if _level1_flow != null and _level1_flow.has_signal("tutorial_line_requested"):
		var level1_line_cb: Callable = Callable(self, "_on_level1_flow_tutorial_line_requested")
		if not _level1_flow.is_connected("tutorial_line_requested", level1_line_cb):
			_level1_flow.connect("tutorial_line_requested", level1_line_cb)


func _start_onboarding() -> void:
	_queue_tutorial_once(
		TUTORIAL_HUB_INTRO,
		"Welcome to the Gravity Playground. The cube ahead selects your puzzle sectors.",
		_audio_path("hub_intro"),
		4.2
	)


func _process_tutorial_steps() -> void:
	_process_gravity_tutorial_step()
	_process_cube_tutorial_step()


func _process_gravity_tutorial_step() -> void:
	var current_up: Vector3 = _read_player_up()
	if current_up.is_equal_approx(_last_player_up):
		return

	_last_player_up = current_up
	_queue_tutorial_once(
		TUTORIAL_GRAVITY_TEACH,
		"Nice. Gravity changed. Keep using it to redefine what counts as floor.",
		_audio_path("gravity_teach"),
		3.8
	)


func _process_cube_tutorial_step() -> void:
	if _level_cube_root == null:
		return
	if _progress != null and _progress.has_tutorial_seen(TUTORIAL_CUBE_TEACH):
		return
	if _player.global_position.distance_to(_level_cube_root.global_position) > CUBE_APPROACH_DISTANCE:
		return

	_queue_tutorial_once(
		TUTORIAL_CUBE_TEACH,
		"Each cube side links to a level. Only stable routes are unlocked.",
		_audio_path("cube_teach"),
		3.6
	)


func _process_locked_side_feedback() -> void:
	if _locked_feedback_timer > 0.0:
		return

	for level_id: StringName in [LEVEL_2, LEVEL_3, LEVEL_4]:
		var portal: Portal3D = _cube_portals.get(level_id) as Portal3D
		if portal == null:
			continue
		if not _is_portal_locked(portal):
			continue
		if not _is_player_facing_locked_portal(portal):
			continue

		_queue_tutorial_line(
			TUTORIAL_LOCKED_SIDE,
			"This side is locked for now. Stabilize available sectors first.",
			_audio_path("locked_side"),
			2.8
		)
		_locked_feedback_timer = LOCKED_FEEDBACK_COOLDOWN
		return


func _on_progression_changed() -> void:
	_apply_portal_lock_state()


func _apply_portal_lock_state() -> void:
	for level_id_var: Variant in _cube_portals.keys():
		var level_id: StringName = level_id_var
		var portal: Portal3D = _cube_portals.get(level_id) as Portal3D
		if portal == null:
			continue

		var unlocked: bool = level_id == LEVEL_1 and level1_starts_unlocked
		if not unlocked and _progress != null:
			unlocked = _progress.is_unlocked(level_id)
		_set_portal_locked(portal, not unlocked)
		_set_lock_blocker_locked(level_id, not unlocked)

	var level1_portal: Portal3D = _cube_portals.get(LEVEL_1) as Portal3D
	if level1_starts_unlocked and level1_portal != null:
		_set_portal_locked(level1_portal, false)
		_set_lock_blocker_locked(LEVEL_1, false)


func _set_portal_locked(portal: Portal3D, locked: bool) -> void:
	if portal == null:
		return
	portal.is_teleport = not locked
	if portal.teleport_area != null:
		portal.teleport_area.monitoring = not locked
		portal.teleport_area.monitorable = not locked


func _set_lock_blocker_locked(level_id: StringName, locked: bool) -> void:
	var blocker: StaticBody3D = _cube_lock_blockers.get(level_id) as StaticBody3D
	if blocker == null:
		return
	blocker.visible = locked
	var collision: CollisionShape3D = blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not locked


func _align_lock_blockers() -> void:
	var center_world: Vector3 = _compute_cube_portal_center_world()
	for level_id_var: Variant in _cube_lock_blockers.keys():
		var level_id: StringName = level_id_var
		_align_lock_blocker_hub_side(level_id, center_world)


func _align_lock_blocker_hub_side(level_id: StringName, center_world: Vector3) -> void:
	var blocker: StaticBody3D = _cube_lock_blockers.get(level_id) as StaticBody3D
	var portal: Portal3D = _cube_portals.get(level_id) as Portal3D
	if blocker == null or portal == null:
		return

	var offset_direction_local: Vector3 = Vector3(0, 0, 1)
	var outward_world: Vector3 = portal.global_position - center_world
	if outward_world.length_squared() > 0.0001:
		var outward_local: Vector3 = portal.global_basis.inverse() * outward_world.normalized()
		if outward_local.length_squared() > 0.0001:
			offset_direction_local = outward_local.normalized()

	blocker.position = offset_direction_local * maxf(lock_blocker_outward_offset, 0.01)
	_align_lock_blocker_visuals(blocker)


func _compute_cube_portal_center_world() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for portal_var: Variant in _cube_portals.values():
		var portal: Portal3D = portal_var as Portal3D
		if portal == null:
			continue
		sum += portal.global_position
		count += 1
	if count > 0:
		return sum / float(count)
	if _level_cube_root != null:
		return _level_cube_root.global_position
	push_warning("WorldGameplayFlow: Unable to compute portal center; using world origin.")
	return Vector3.ZERO


func _configure_lock_blockers() -> void:
	var resolved_size: Vector3 = lock_blocker_size
	resolved_size.x = maxf(resolved_size.x, 0.1)
	resolved_size.y = maxf(resolved_size.y, 0.1)
	resolved_size.z = maxf(lock_blocker_thickness, 0.01)

	for level_id_var: Variant in _cube_lock_blockers.keys():
		var level_id: StringName = level_id_var
		var blocker: StaticBody3D = _cube_lock_blockers.get(level_id) as StaticBody3D
		if blocker == null:
			continue

		var collision: CollisionShape3D = blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			var blocker_shape: BoxShape3D = collision.shape
			blocker_shape.size = resolved_size
		else:
			push_warning("WorldGameplayFlow: Lock blocker collision for %s is missing a BoxShape3D." % String(level_id))

		var mesh_instance: MeshInstance3D = blocker.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh is BoxMesh:
			var blocker_mesh: BoxMesh = mesh_instance.mesh
			blocker_mesh.size = resolved_size
			mesh_instance.layers = 1 << 0
			_configure_lock_blocker_material(mesh_instance)
			_configure_lock_blocker_laser_bars(blocker, resolved_size)
			_align_lock_blocker_visuals(blocker)
		else:
			push_warning("WorldGameplayFlow: Lock blocker mesh for %s is missing a BoxMesh." % String(level_id))


func _align_lock_blocker_visuals(blocker: StaticBody3D) -> void:
	if blocker == null:
		return

	var outward_local: Vector3 = blocker.position
	if outward_local.length_squared() <= 0.0001:
		outward_local = Vector3(0, 0, 1)
	var outward_dir: Vector3 = outward_local.normalized()
	# Keep collision body in its current gameplay position while pulling visual meshes toward cube face.
	var target_from_portal: Vector3 = outward_dir * maxf(lock_visual_outward_from_portal + lock_visual_depth_bias, 0.0)
	var visual_anchor: Vector3 = target_from_portal - blocker.position

	var mesh_instance: MeshInstance3D = blocker.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.position = visual_anchor

	var bars_root: Node3D = blocker.get_node_or_null("LaserBars") as Node3D
	if bars_root != null:
		bars_root.position = visual_anchor


func _configure_lock_blocker_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	var source_material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
	if source_material == null:
		return

	var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.12, 1.0)
	material.emission_energy_multiplier = maxf(lock_blocker_emission_energy, 0.0)
	material.albedo_color = Color(1.0, 0.1, 0.1, 1.0)
	mesh_instance.material_override = material
	mesh_instance.visible = show_lock_blocker_panel


func _configure_lock_blocker_laser_bars(blocker: Node3D, blocker_size: Vector3) -> void:
	if blocker == null:
		return

	var bars_root: Node3D = blocker.get_node_or_null("LaserBars") as Node3D
	if bars_root == null:
		bars_root = Node3D.new()
		bars_root.name = "LaserBars"
		blocker.add_child(bars_root)

	for child: Node in bars_root.get_children():
		child.free()

	var bar_material: StandardMaterial3D = _create_lock_bar_material()
	var layers: int = 1 << 0
	var z_offset: float = maxf(blocker_size.z * 0.15, 0.02)
	var vertical_width: float = clampf(blocker_size.x * 0.06, 0.08, 0.20)
	var horizontal_width: float = vertical_width
	var vertical_height: float = blocker_size.y * 0.9
	var horizontal_length: float = blocker_size.x * 0.84
	var side_x: float = blocker_size.x * 0.28
	var line_y: float = blocker_size.y * 0.24
	var laser_depth: float = maxf(blocker_size.z * 0.45, 0.08)

	_add_lock_bar(
		bars_root,
		&"VLeft",
		Vector3(vertical_width, vertical_height, laser_depth),
		Vector3(-side_x, 0.0, z_offset),
		layers,
		bar_material
	)
	_add_lock_bar(
		bars_root,
		&"VMid",
		Vector3(vertical_width, vertical_height, laser_depth),
		Vector3(0.0, 0.0, z_offset),
		layers,
		bar_material
	)
	_add_lock_bar(
		bars_root,
		&"VRight",
		Vector3(vertical_width, vertical_height, laser_depth),
		Vector3(side_x, 0.0, z_offset),
		layers,
		bar_material
	)
	_add_lock_bar(
		bars_root,
		&"HTop",
		Vector3(horizontal_length, horizontal_width, laser_depth),
		Vector3(0.0, line_y, z_offset),
		layers,
		bar_material
	)
	_add_lock_bar(
		bars_root,
		&"HBottom",
		Vector3(horizontal_length, horizontal_width, laser_depth),
		Vector3(0.0, -line_y, z_offset),
		layers,
		bar_material
	)


func _add_lock_bar(
	parent: Node3D,
	bar_name: StringName,
	size: Vector3,
	local_position: Vector3,
	layers: int,
	material: StandardMaterial3D
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = String(bar_name)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.layers = layers
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _create_lock_bar_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.no_depth_test = false
	material.albedo_color = Color(1.0, 0.16, 0.16, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.1, 0.1, 1.0)
	material.emission_energy_multiplier = maxf(lock_laser_bar_emission_energy, 0.0)
	return material


func _is_portal_locked(portal: Portal3D) -> bool:
	if portal == null:
		return false
	if not portal.is_teleport:
		return true
	return portal.teleport_area != null and not portal.teleport_area.monitoring


func _is_player_facing_locked_portal(portal: Portal3D) -> bool:
	if _player == null:
		return false
	var to_portal: Vector3 = portal.global_position - _player.global_position
	if to_portal.length_squared() > LOCKED_SIDE_FEEDBACK_DISTANCE * LOCKED_SIDE_FEEDBACK_DISTANCE:
		return false

	var camera: Camera3D = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return true

	var view_forward: Vector3 = -camera.global_basis.z.normalized()
	return view_forward.dot(to_portal.normalized()) >= LOCKED_SIDE_FACING_DOT


func _on_level1_cube_portal_teleport(node: Node3D) -> void:
	if not _is_player_node(node):
		return
	_level1_trigger_reached = false
	_queue_tutorial_once(
		TUTORIAL_LEVEL1_ENTER,
		"Level 1 active. In this space, the obvious route is usually wrong.",
		_audio_path("level1_enter"),
		4.0
	)


func _on_level1_complete_trigger_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	if _level1_trigger_reached:
		return
	if _level1_flow != null and _level1_flow.has_method("is_completion_ready"):
		var completion_ready: Variant = _level1_flow.call("is_completion_ready")
		if typeof(completion_ready) == TYPE_BOOL and not bool(completion_ready):
			_queue_tutorial_line(
				TUTORIAL_LEVEL1_CORRECT_PATH,
				"Route not stable yet. Solve the final seal before returning to hub.",
				_audio_path("level1_correct_path"),
				3.4
			)
			return

	_level1_trigger_reached = true
	_queue_tutorial_once(
		TUTORIAL_LEVEL1_CORRECT_PATH,
		"Correct route found. Return through the hub gate to lock in this completion.",
		_audio_path("level1_correct_path"),
		4.2
	)


func _on_level1_cube_portal_receive(node: Node3D) -> void:
	if not _is_player_node(node):
		return
	if not _level1_trigger_reached:
		return

	_level1_trigger_reached = false
	if _progress == null:
		return
	if not _progress.mark_completed(LEVEL_1):
		return

	_queue_tutorial_once(
		TUTORIAL_LEVEL1_UNLOCK_L2,
		"Sector stabilized. Level 2 is now unlocked on the cube.",
		_audio_path("level1_unlock_l2"),
		3.5
	)


func _queue_tutorial_once(line_id: StringName, subtitle: String, audio_path: String, fallback_duration: float) -> void:
	if _progress != null and _progress.has_tutorial_seen(line_id):
		return
	if _progress != null:
		_progress.mark_tutorial_seen(line_id)
	_queue_tutorial_line(line_id, subtitle, audio_path, fallback_duration)


func _queue_tutorial_line(line_id: StringName, subtitle: String, audio_path: String, fallback_duration: float) -> void:
	if _companion != null and _companion.has_method("queue_tutorial_line"):
		_companion.call("queue_tutorial_line", line_id, subtitle, audio_path, fallback_duration)
		return
	_show_subtitle(subtitle, fallback_duration)


func _on_companion_tutorial_line_started(_line_id: StringName, subtitle: String, duration: float) -> void:
	_show_subtitle(subtitle, duration)


func _on_level1_flow_tutorial_line_requested(line_id: StringName, subtitle: String, audio_path: String, fallback_duration: float) -> void:
	_queue_tutorial_line(line_id, subtitle, audio_path, fallback_duration)


func _show_subtitle(text: String, duration: float) -> void:
	if _hud == null or not _hud.has_method("show_companion_subtitle"):
		return
	_hud.call("show_companion_subtitle", text, duration)


func _is_player_node(node: Node) -> bool:
	if _player == null or node == null:
		return false
	if node == _player:
		return true
	return _player.is_ancestor_of(node)


func _read_player_up() -> Vector3:
	if _player == null:
		return Vector3.UP
	var candidate: Variant = _player.get("up_direction")
	if typeof(candidate) == TYPE_VECTOR3:
		var up: Vector3 = candidate
		if not up.is_zero_approx():
			return up.normalized()
	return Vector3.UP


func _audio_path(line_name: String) -> String:
	return "res://audio/companion/tutorial/%s.wav" % line_name
