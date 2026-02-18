extends Node

class_name RuntimeCSGBaker

@export var target_root_path: NodePath = NodePath("..")


func _ready() -> void:
	var profile: PerformanceProfile = get_node_or_null("/root/GamePerformance") as PerformanceProfile
	if profile == null or not profile.should_bake_csg_runtime():
		return
	call_deferred("_bake_runtime_meshes")


func _bake_runtime_meshes() -> void:
	var target_root: Node = get_node_or_null(target_root_path)
	if target_root == null:
		return

	var baked_container: Node3D = Node3D.new()
	baked_container.name = "BakedCSG"
	target_root.add_child(baked_container)

	for csg: CSGShape3D in _collect_bake_candidates(target_root):
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
	_collect_recursive(target_root, candidates)
	return candidates


func _collect_recursive(node: Node, out: Array[CSGShape3D]) -> void:
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		if csg.get_parent() is CSGShape3D:
			return
		if _has_csg_children(csg):
			return
		out.append(csg)
		return

	for child: Node in node.get_children():
		_collect_recursive(child, out)


func _has_csg_children(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CSGShape3D:
			return true
	return false
