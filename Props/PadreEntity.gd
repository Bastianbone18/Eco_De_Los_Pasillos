extends Node3D
class_name PadreEntity

signal apparition_started
signal apparition_finished
signal apparition_resolved(found_by_player: bool)
signal punishment_changed(amount: float)

@onready var sprite: Sprite3D = $Sprite3D
@onready var timer: Timer = $Timer
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

@export var tiempo_para_mirar: float = 1.0
@export var tiempo_minimo_visible: float = 0.65
@export var distancia_maxima: float = 18.0
@export var tolerancia_mirada: float = 0.82
@export var duracion_maxima_aparicion: float = 5.0

@export var fade_speed_in: float = 7.0
@export var fade_speed_out: float = 2.8
@export var punishment_build_speed: float = 0.45
@export var punishment_decay_speed: float = 1.4

@export var shader_idle_intensity: float = 1.0
@export var shader_glitch_idle: float = 0.24
@export var shader_ghost_idle: float = 0.30
@export var shader_noise_idle: float = 0.14
@export var shader_warp_idle: float = 0.12

@export var shader_glitch_spawn_boost: float = 0.10
@export var shader_ghost_disappear_boost: float = 0.18
@export var shader_glitch_disappear_boost: float = 0.08

@export var shader_glitch_punish_boost: float = 0.18
@export var shader_ghost_punish_boost: float = 0.16
@export var shader_noise_punish_boost: float = 0.10
@export var shader_warp_punish_boost: float = 0.06

@export var play_warning_sound_on_spawn: bool = true

@export var debug_enabled: bool = true
@export var debug_print_once_only: bool = true

var camera: Camera3D = null
var active: bool = false
var disappearing: bool = false

var look_timer: float = 0.0
var visible_timer: float = 0.0
var punishment_amount: float = 0.0
var alpha_current: float = 0.0

var was_found_by_player: bool = false
var resolved_emitted: bool = false

var _debug_printed_keys: Dictionary = {}


func _dbg(message: String) -> void:
	if not debug_enabled:
		return
	print("[PadreEntity] ", message)


func _dbg_once(key: String, message: String) -> void:
	if not debug_enabled:
		return
	if debug_print_once_only and _debug_printed_keys.has(key):
		return
	_debug_printed_keys[key] = true
	print("[PadreEntity] ", message)


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_set_alpha(0.0)
	hide()

	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	if audio_player:
		audio_player.bus = "Atmosfera"

	_set_shader_float("intensity", shader_idle_intensity)
	_set_shader_float("glitch_strength", shader_glitch_idle)
	_set_shader_float("ghost_strength", shader_ghost_idle)
	_set_shader_float("noise_strength", shader_noise_idle)
	_set_shader_float("warp_strength", shader_warp_idle)
	_set_shader_float("dissolve_strength", 0.0)

	_dbg_once("ready", "READY")


func aparecer(world_pos: Vector3, duracion: float = -1.0) -> void:
	global_position = world_pos
	camera = get_viewport().get_camera_3d()

	active = true
	disappearing = false

	look_timer = 0.0
	visible_timer = 0.0
	punishment_amount = 0.0
	alpha_current = 0.0
	was_found_by_player = false
	resolved_emitted = false

	show()
	_set_alpha(0.0)

	if duracion <= 0.0:
		duracion = duracion_maxima_aparicion

	_set_shader_float("intensity", shader_idle_intensity)
	_set_shader_float("glitch_strength", shader_glitch_idle + shader_glitch_spawn_boost)
	_set_shader_float("ghost_strength", shader_ghost_idle)
	_set_shader_float("noise_strength", shader_noise_idle)
	_set_shader_float("warp_strength", shader_warp_idle)
	_set_shader_float("dissolve_strength", 0.0)

	timer.start(duracion)

	if play_warning_sound_on_spawn and audio_player and audio_player.stream:
		audio_player.stop()
		audio_player.play()

	_dbg("aparecer() -> pos=%s duración=%s" % [str(world_pos), str(duracion)])
	emit_signal("apparition_started")


func desaparecer() -> void:
	if not active:
		return
	if disappearing:
		return

	disappearing = true
	timer.stop()


func _process(delta: float) -> void:
	if not active:
		return

	if camera == null:
		camera = get_viewport().get_camera_3d()

	

	if disappearing:
		alpha_current = move_toward(alpha_current, 0.0, fade_speed_out * delta)
		_set_alpha(alpha_current)

		var dissolve: float = 1.0 - alpha_current
		_set_shader_float("dissolve_strength", clamp(dissolve, 0.0, 1.0))
		_set_shader_float("ghost_strength", shader_ghost_idle + dissolve * shader_ghost_disappear_boost)
		_set_shader_float("glitch_strength", shader_glitch_idle + dissolve * shader_glitch_disappear_boost)

		if alpha_current <= 0.01:
			_finish_apparition()
		return

	visible_timer += delta
	alpha_current = move_toward(alpha_current, 1.0, fade_speed_in * delta)
	_set_alpha(alpha_current)

	var spawn_glitch_target: float = move_toward(
		_get_shader_float("glitch_strength"),
		shader_glitch_idle,
		1.2 * delta
	)
	_set_shader_float("glitch_strength", spawn_glitch_target)

	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return

	var mirando: bool = _player_is_looking_at_me()

	if mirando:
		look_timer += delta
		punishment_amount = move_toward(punishment_amount, 0.0, punishment_decay_speed * delta)

		if visible_timer >= tiempo_minimo_visible and look_timer >= tiempo_para_mirar:
			was_found_by_player = true
			_dbg("encontrado por jugador")
			desaparecer()
	else:
		look_timer = max(look_timer - delta * 0.5, 0.0)
		punishment_amount = move_toward(punishment_amount, 1.0, punishment_build_speed * delta)

	_apply_punishment(punishment_amount)


func _face_camera_like_billboard() -> void:
	if camera == null:
		return

	var cam_pos: Vector3 = camera.global_transform.origin
	var my_pos: Vector3 = global_transform.origin
	var dir: Vector3 = cam_pos - my_pos
	dir.y = 0.0

	if dir.length_squared() > 0.0001:
		look_at(my_pos + dir.normalized(), Vector3.UP, true)


func _player_is_looking_at_me() -> bool:
	if camera == null:
		return false

	var to_entity: Vector3 = global_position - camera.global_position
	var distance: float = to_entity.length()

	if distance > distancia_maxima:
		return false

	to_entity = to_entity.normalized()
	var cam_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var dot_value: float = cam_forward.dot(to_entity)

	return dot_value >= tolerancia_mirada


func _apply_punishment(amount: float) -> void:
	var a: float = clamp(amount, 0.0, 1.0)
	emit_signal("punishment_changed", a)
	set_punishment_visuals(a)

	var c: Color = sprite.modulate
	c.r = 1.0
	c.g = 1.0 - a * 0.12
	c.b = 1.0 - a * 0.12
	c.a = alpha_current
	sprite.modulate = c


func _set_alpha(value: float) -> void:
	var c: Color = sprite.modulate
	c.a = clamp(value, 0.0, 1.0)
	sprite.modulate = c


func _set_shader_float(param_name: String, value: float) -> void:
	if sprite.material_override and sprite.material_override is ShaderMaterial:
		var mat: ShaderMaterial = sprite.material_override
		mat.set_shader_parameter(param_name, value)


func _get_shader_float(param_name: String) -> float:
	if sprite.material_override and sprite.material_override is ShaderMaterial:
		var mat: ShaderMaterial = sprite.material_override
		var value = mat.get_shader_parameter(param_name)
		if value is float:
			return value
		if value is int:
			return float(value)
	return 0.0


func _on_timer_timeout() -> void:
	was_found_by_player = false
	_dbg("timeout -> no fue encontrado")
	desaparecer()


func set_punishment_visuals(amount: float) -> void:
	var a: float = clamp(amount, 0.0, 1.0)
	_set_shader_float("glitch_strength", shader_glitch_idle + a * shader_glitch_punish_boost)
	_set_shader_float("ghost_strength", shader_ghost_idle + a * shader_ghost_punish_boost)
	_set_shader_float("noise_strength", shader_noise_idle + a * shader_noise_punish_boost)
	_set_shader_float("warp_strength", shader_warp_idle + a * shader_warp_punish_boost)


func _finish_apparition() -> void:
	active = false
	disappearing = false
	look_timer = 0.0
	visible_timer = 0.0
	punishment_amount = 0.0

	emit_signal("punishment_changed", 0.0)

	_set_shader_float("warp_strength", shader_warp_idle)
	_set_shader_float("dissolve_strength", 0.0)
	_set_shader_float("glitch_strength", shader_glitch_idle)
	_set_shader_float("ghost_strength", shader_ghost_idle)
	_set_shader_float("noise_strength", shader_noise_idle)
	_set_shader_float("intensity", shader_idle_intensity)

	_set_alpha(0.0)
	hide()

	if not resolved_emitted:
		resolved_emitted = true
		_dbg("emitiendo apparition_resolved -> %s" % str(was_found_by_player))
		emit_signal("apparition_resolved", was_found_by_player)

	_dbg("emitiendo apparition_finished")
	emit_signal("apparition_finished")
