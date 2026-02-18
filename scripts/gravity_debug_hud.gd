extends CanvasLayer

@onready var gravity_label: Label = %GravityDebugLabel

const UPDATE_INTERVAL: float = 0.2

var _player: CharacterBody3D
var _update_timer: float = 0.0
var _last_text: String = ""


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_update_label_text()


func _process(_delta: float) -> void:
	_update_timer -= _delta
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
