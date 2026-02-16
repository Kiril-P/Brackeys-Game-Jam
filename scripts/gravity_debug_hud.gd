extends CanvasLayer

@onready var gravity_label: Label = %GravityDebugLabel

func _process(_delta: float) -> void:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		gravity_label.text = "Gravity Up: N/A\nGravity Down: N/A"
		return

	var up_axis_name: String = _axis_name(player.up_direction)
	var down_axis_name: String = _axis_name(-player.up_direction)
	gravity_label.text = "Gravity Up: %s\nGravity Down: %s" % [up_axis_name, down_axis_name]


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
