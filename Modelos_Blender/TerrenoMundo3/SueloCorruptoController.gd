extends Node
class_name SueloCorruptoController

@export var suelo_mesh: MeshInstance3D
@export var corruption_step: float = 0.33
@export var tween_time: float = 1.2

var corruption: float = 0.0
var _tween: Tween

func _ready() -> void:
	if suelo_mesh == null:
		push_error("[SueloCorruptoController] suelo_mesh no asignado")
		return

	_apply_corruption_immediate(corruption)

func add_corruption_step(amount: float = -1.0) -> void:
	if suelo_mesh == null:
		return

	var add_value: float = corruption_step if amount < 0.0 else amount
	var target: float = clamp(corruption + add_value, 0.0, 1.0)

	if is_equal_approx(target, corruption):
		return

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_method(_set_corruption, corruption, target, tween_time)

func _set_corruption(value: float) -> void:
	corruption = clamp(value, 0.0, 1.0)
	_apply_corruption_immediate(corruption)

func _apply_corruption_immediate(value: float) -> void:
	var mat: Material = suelo_mesh.get_active_material(0)

	if mat is ShaderMaterial:
		var shader_mat: ShaderMaterial = mat
		shader_mat.set_shader_parameter("corruption", value)
	else:
		push_warning("[SueloCorruptoController] El material del suelo no es ShaderMaterial")
