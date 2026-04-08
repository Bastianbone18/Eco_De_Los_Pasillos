extends Node3D

@onready var lluvia: GPUParticles3D = $LluviaSangre

@export var follow_player: bool = true
@export var player_path: NodePath
@export var height_offset: float = 4.5
@export var transition_time: float = 1.2

var player: Node3D = null
var current_stage: int = 0
var _tween: Tween = null


func _ready() -> void:
	if lluvia == null:
		push_error("[LluviBlod] No se encontró el nodo hijo 'LluviaSangre'")
		return

	if lluvia.process_material == null:
		push_error("[LluviBlod] 'LluviaSangre' no tiene process_material asignado")
		return

	player = get_node_or_null(player_path) as Node3D

	current_stage = 0
	_setup_stage_immediate(current_stage)
	_set_emitting_if_needed()


func _process(_delta: float) -> void:
	if not follow_player:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("Player") as Node3D
		if player == null:
			return

	global_position = player.global_position + Vector3(0.0, height_offset, 0.0)


func increase_rain_stage() -> void:
	print("[LluviBlod] increase_rain_stage() - stage actual: ", current_stage)
	set_rain_stage(current_stage + 1)


func set_rain_stage(stage: int) -> void:
	if lluvia == null:
		return

	stage = clamp(stage, 0, 3)

	if stage == current_stage:
		return

	current_stage = stage
	print("[LluviBlod] Nuevo stage de lluvia: ", current_stage)
	_apply_stage_smooth(stage)


func _get_pm() -> ParticleProcessMaterial:
	if lluvia == null:
		return null

	return lluvia.process_material as ParticleProcessMaterial


func _setup_stage_immediate(stage: int) -> void:
	var pm := _get_pm()
	if pm == null:
		push_warning("[LluviBlod] 'LluviaSangre' no tiene ParticleProcessMaterial válido")
		return

	match stage:
		0:
			lluvia.amount = 1
			lluvia.lifetime = 1.2
			pm.initial_velocity_min = 12.0
			pm.initial_velocity_max = 16.0
			pm.gravity = Vector3(0, -20, 0)
			pm.spread = 4.0

		1:
			lluvia.amount = 300
			lluvia.lifetime = 1.2
			pm.initial_velocity_min = 14.0
			pm.initial_velocity_max = 18.0
			pm.gravity = Vector3(0, -22, 0)
			pm.spread = 6.0

		2:
			lluvia.amount = 750
			lluvia.lifetime = 1.15
			pm.initial_velocity_min = 16.0
			pm.initial_velocity_max = 21.0
			pm.gravity = Vector3(0, -24, 0)
			pm.spread = 7.0

		3:
			lluvia.amount = 1400
			lluvia.lifetime = 1.0
			pm.initial_velocity_min = 18.0
			pm.initial_velocity_max = 25.0
			pm.gravity = Vector3(0, -28, 0)
			pm.spread = 9.0


func _apply_stage_smooth(stage: int) -> void:
	var pm := _get_pm()
	if pm == null:
		push_warning("[LluviBlod] 'LluviaSangre' no tiene ParticleProcessMaterial válido")
		return

	var target_amount: int = 1
	var target_lifetime: float = 1.2
	var target_vel_min: float = 12.0
	var target_vel_max: float = 16.0
	var target_gravity: Vector3 = Vector3(0, -20, 0)
	var target_spread: float = 4.0

	match stage:
		0:
			target_amount = 1
			target_lifetime = 1.2
			target_vel_min = 12.0
			target_vel_max = 16.0
			target_gravity = Vector3(0, -20, 0)
			target_spread = 4.0

		1:
			target_amount = 1000
			target_lifetime = 1.2
			target_vel_min = 14.0
			target_vel_max = 18.0
			target_gravity = Vector3(0, -22, 0)
			target_spread = 6.0

		2:
			target_amount = 3000
			target_lifetime = 1.15
			target_vel_min = 16.0
			target_vel_max = 21.0
			target_gravity = Vector3(0, -24, 0)
			target_spread = 7.0

		3:
			target_amount = 5000
			target_lifetime = 1.0
			target_vel_min = 18.0
			target_vel_max = 25.0
			target_gravity = Vector3(0, -28, 0)
			target_spread = 9.0

	if _tween:
		_tween.kill()

	if target_amount > 1 and not lluvia.emitting:
		lluvia.emitting = true

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(lluvia, "amount", target_amount, transition_time)
	_tween.tween_property(lluvia, "lifetime", target_lifetime, transition_time)
	_tween.tween_property(pm, "initial_velocity_min", target_vel_min, transition_time)
	_tween.tween_property(pm, "initial_velocity_max", target_vel_max, transition_time)
	_tween.tween_property(pm, "gravity", target_gravity, transition_time)
	_tween.tween_property(pm, "spread", target_spread, transition_time)

	await _tween.finished
	_set_emitting_if_needed()


func _set_emitting_if_needed() -> void:
	if lluvia == null:
		return

	lluvia.emitting = current_stage > 0
