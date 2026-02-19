extends Node

class_name RuntimeCSGBaker

@export var target_root_path: NodePath = NodePath("..")
@export var force_bake_csg_count_threshold: int = 40

var _pending_candidates: Array[CSGShape3D] = []


func _ready() -> void:
	var target_root: Node = get_node_or_null(target_root_path)
	if target_root == null:
		return

	var candidates: Array[CSGShape3D] = _collect_bake_candidates(target_root)
	if candidates.is_empty():
		return

	var profile: PerformanceProfile = get_node_or_null("/root/GamePerformance") as PerformanceProfile
	var should_bake: bool = profile != null and profile.should_bake_csg_runtime()
	if not should_bake and force_bake_csg_count_threshold > 0:
		should_bake = candidates.size() >= force_bake_csg_count_threshold
	if not should_bake:
		return

	_pending_candidates = candidates
	call_deferred("_bake_runtime_meshes")


func _bake_runtime_meshes() -> void:
	var target_root: Node = get_node_or_null(target_root_path)
	if target_root == null:
		return

	var baked_container: Node3D = Node3D.new()
	baked_container.name = "BakedCSG"
	target_root.add_child(baked_container)

	var candidates: Array[CSGShape3D] = _pending_candidates
	if candidates.is_empty():
		candidates = _collect_bake_candidates(target_root)
	_pending_candidates = []

	for csg: CSGShape3D in candidates:
		var mesh_data: Array = csg.get_meshes()
		if mesh_data.size() < 2:
			continue

		for i: int in range(0, mesh_data.size(), 2):
			if i + 1 >= mesh_data.size():
				break
			var local_transform: Transform3D = mesh_data[i] as Transform3D
			var mesh: Mesh = mesh_data[i + 1] as Mesh
			if local_transform == null or mesh == null:
				continue

			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = mesh
			mesh_instance.global_transform = csg.global_transform * local_transform
			mesh_instance.material_override = csg.material
			mesh_instance.cast_shadow = csg.cast_shadow
			baked_container.add_child(mesh_instance)

		csg.visible = false


func _collect_bake_candidates(target_root: Node) -> Array[CSGShape3D]:
	var candidates: Array[CSGShape3D] = []
	_collect_recursive(target_root, target_root, candidates)
	return candidates


func _collect_recursive(node: Node, target_root: Node, out: Array[CSGShape3D]) -> void:
	if node != target_root and node.get_node_or_null("RuntimeCSGBaker") != null:
		return

	if node is CSGShape3D:
		var csg := node as CSGShape3D
		if csg.get_parent() is CSGShape3D:
			return
		out.append(csg)
		return

	for child: Node in node.get_children():
		_collect_recursive(child, target_root, out)
