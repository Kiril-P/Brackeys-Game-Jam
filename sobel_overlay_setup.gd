extends Node3D

class_name SobelOverlaySetup

@export_file("*.gdshader") var shader_path: String = "res://sobel_depth_edges_3d.gdshader"
@export var line_color: Color = Color(0.06, 0.08, 0.12, 1.0)
@export_range(0.1, 6.0, 0.1) var line_thickness: float = 1.0
@export_range(0.0001, 0.1, 0.0001) var depth_threshold: float = 0.006
@export_range(0.001, 1.0, 0.001) var normal_threshold: float = 0.12
@export_range(0.0, 2.0, 0.01) var depth_weight: float = 0.75
@export_range(0.0, 2.0, 0.01) var normal_weight: float = 1.0
@export_range(0.0001, 0.25, 0.0001) var edge_softness: float = 0.02
@export_range(-128, 128, 1) var render_priority: int = 64

var _quad_instance: MeshInstance3D
var _shader_material: ShaderMaterial

func _ready() -> void:
	var profile: PerformanceProfile = get_node_or_null("/root/GamePerformance") as PerformanceProfile
	_apply_sky_profile(profile)
	if profile != null and not profile.sobel_enabled():
		visible = false
		set_process(false)
		return

	_apply_sobel_profile(profile)
	_ensure_depth_post_process()
	_apply_uniforms()


func _ensure_depth_post_process() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("SobelOverlaySetup: No active Camera3D found in the viewport.")
		return

	_quad_instance = camera.get_node_or_null("SobelPostProcessQuad") as MeshInstance3D
	if _quad_instance == null:
		_quad_instance = MeshInstance3D.new()
		_quad_instance.name = "SobelPostProcessQuad"
		camera.add_child(_quad_instance)

	var quad_mesh := _quad_instance.mesh as QuadMesh
	if quad_mesh == null:
		quad_mesh = QuadMesh.new()
		quad_mesh.size = Vector2(2.0, 2.0)
		quad_mesh.flip_faces = true
		_quad_instance.mesh = quad_mesh

	_quad_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad_instance.extra_cull_margin = 10000.0

	_shader_material = _quad_instance.material_override as ShaderMaterial
	if _shader_material == null:
		_shader_material = ShaderMaterial.new()
		_quad_instance.material_override = _shader_material

	var loaded_shader := load(shader_path) as Shader
	if loaded_shader == null:
		push_error("SobelOverlaySetup: Could not load shader at '%s'." % shader_path)
		return

	_shader_material.shader = loaded_shader


func _apply_uniforms() -> void:
	if _shader_material == null:
		return

	_shader_material.set_shader_parameter("line_color", line_color)
	_shader_material.set_shader_parameter("line_thickness", line_thickness)
	_shader_material.set_shader_parameter("depth_threshold", depth_threshold)
	_shader_material.set_shader_parameter("normal_threshold", normal_threshold)
	_shader_material.set_shader_parameter("depth_weight", depth_weight)
	_shader_material.set_shader_parameter("normal_weight", normal_weight)
	_shader_material.set_shader_parameter("edge_softness", edge_softness)
	_shader_material.render_priority = render_priority


func _apply_sobel_profile(profile: PerformanceProfile) -> void:
	if profile == null:
		return
	if profile.is_web_profile():
		line_thickness = 0.8
	elif profile.is_low_end_profile():
		line_thickness = minf(line_thickness, 1.0)


func _apply_sky_profile(profile: PerformanceProfile) -> void:
	if profile == null:
		return
	var world_env: Environment = get_viewport().world_3d.environment
	if world_env == null or world_env.sky == null:
		return
	var sky_material: Material = world_env.sky.sky_material
	if sky_material == null:
		return
	if sky_material is ShaderMaterial:
		(sky_material as ShaderMaterial).set_shader_parameter("fallback_gradient_only", profile.sky_fallback_gradient_only())
