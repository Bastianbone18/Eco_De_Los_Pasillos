extends ColorRect

@export var enemy_group_name: StringName = &"ChaseEnemy"
@export var max_distance: float = 18.0
@export var min_distance: float = 2.5
@export var smooth_speed: float = 10.0

@export var only_when_chasing: bool = true

var _enemy: Node3D
var _player: Node3D
var _current := 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	_enemy = get_tree().get_first_node_in_group(enemy_group_name) as Node3D

	# Asegura que material exista
	if material == null:
		push_warning("[FearOverlay] No tiene material (ShaderMaterial).")
	else:
		material.set_shader_parameter("intensity", 0.0)

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _enemy == null:
		_enemy = get_tree().get_first_node_in_group(enemy_group_name) as Node3D

	var target_intensity := 0.0

	if _player != null and _enemy != null:
		# Si quieres que solo funcione en chase:
		if only_when_chasing and _enemy.has_method("is_chasing"):
			if not _enemy.is_chasing():
				target_intensity = 0.0
				
			else:
				target_intensity = _compute_intensity()
		else:
			target_intensity = _compute_intensity()

	# Suavizado (evita flicker)
	_current = lerp(_current, target_intensity, 1.0 - exp(-smooth_speed * delta))

	if material:
		material.set_shader_parameter("intensity", _current)

func _compute_intensity() -> float:
	var dist := _enemy.global_position.distance_to(_player.global_position)
	var t := inverse_lerp(max_distance, min_distance, dist)
	t = clamp(t, 0.0, 1.0)
	return t * t  # curva más terror (sube más fuerte al final)
