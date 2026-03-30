extends Node3D

@export var lifetime_min: float = 2.0
@export var lifetime_max: float = 3.0
@export var fade_out_time: float = 0.15

# 🔧 AJUSTES NUEVOS (más sutil)
@export var base_alpha: float = 0.32
@export var random_scale_offset: float = 0.03
@export var random_y_offset: float = 0.04
@export var base_sprite_scale: Vector3 = Vector3(0.82, 0.82, 1.0)

@export var glitch_strength: float = 0.45
@export var ghost_strength: float = 0.55
@export var noise_strength: float = 0.30
@export var warp_strength: float = 0.24
@export var dissolve_strength: float = 0.22
@export var flicker_strength: float = 0.28
@export var intensity: float = 1.15

@export var tint: Color = Color(0.82, 0.86, 0.92, 0.45)

@export var debug_enabled: bool = true

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var life_timer: Timer = $LifeTimer

var _camera: Camera3D = null
var _is_despawning: bool = false
var _material_instance: ShaderMaterial = null


func _dbg(message: String) -> void:
	if not debug_enabled:
		return
	print("[FakeShadow] ", message)


func _ready() -> void:
	randomize()

	if not sprite_3d:
		push_error("[FakeShadow] falta Sprite3D")
		queue_free()
		return

	if not life_timer:
		push_error("[FakeShadow] falta LifeTimer")
		queue_free()
		return

	_make_material_unique()
	_apply_visual_setup()
	_apply_random_visual_variation()

	life_timer.one_shot = true
	life_timer.wait_time = randf_range(lifetime_min, lifetime_max)
	life_timer.timeout.connect(_on_life_timer_timeout)
	life_timer.start()

	_dbg("READY -> pos=%s lifetime=%s" % [str(global_position), str(life_timer.wait_time)])


func setup(camera: Camera3D) -> void:
	_camera = camera
	_dbg("setup() camera=%s" % str(camera))


func _process(delta: float) -> void:
	if _is_despawning:
		return

	_update_shader_time_fx()


func _make_material_unique() -> void:
	if sprite_3d.material_override == null:
		push_error("[FakeShadow] Sprite3D no tiene material_override")
		return

	_material_instance = sprite_3d.material_override.duplicate() as ShaderMaterial
	sprite_3d.material_override = _material_instance


func _apply_visual_setup() -> void:
	if _material_instance == null:
		return

	_set_shader_param_if_exists("glitch_strength", glitch_strength)
	_set_shader_param_if_exists("ghost_strength", ghost_strength)
	_set_shader_param_if_exists("noise_strength", noise_strength)
	_set_shader_param_if_exists("warp_strength", warp_strength)
	_set_shader_param_if_exists("dissolve_strength", dissolve_strength)
	_set_shader_param_if_exists("flicker_strength", flicker_strength)
	_set_shader_param_if_exists("intensity", intensity)
	_set_shader_param_if_exists("tint", tint)
	_set_shader_param_if_exists("fixed_y_billboard", 1.0)

	var mod := sprite_3d.modulate
	mod.a = base_alpha
	sprite_3d.modulate = mod


func _apply_random_visual_variation() -> void:
	var s := 1.0 + randf_range(-random_scale_offset, random_scale_offset)

	# 🔧 AHORA SOLO ESCALA EL SPRITE, NO EL NODE3D
	sprite_3d.scale = Vector3(
		base_sprite_scale.x * s,
		base_sprite_scale.y * s,
		base_sprite_scale.z
	)

	global_position.y += randf_range(-random_y_offset, random_y_offset)

	var mod := sprite_3d.modulate
	mod.a *= randf_range(0.85, 1.05)
	sprite_3d.modulate = mod

	if _material_instance != null:
		_set_shader_param_if_exists("glitch_strength", glitch_strength + randf_range(-0.08, 0.08))
		_set_shader_param_if_exists("ghost_strength", ghost_strength + randf_range(-0.08, 0.08))
		_set_shader_param_if_exists("noise_strength", noise_strength + randf_range(-0.05, 0.05))
		_set_shader_param_if_exists("warp_strength", warp_strength + randf_range(-0.05, 0.05))
		_set_shader_param_if_exists("dissolve_strength", dissolve_strength + randf_range(-0.06, 0.06))


func _face_camera_like_billboard() -> void:
	if _camera == null:
		return

	var cam_pos: Vector3 = _camera.global_transform.origin
	var my_pos: Vector3 = global_transform.origin

	var dir: Vector3 = cam_pos - my_pos
	dir.y = 0.0

	if dir.length_squared() > 0.0001:
		look_at(my_pos + dir.normalized(), Vector3.UP, true)


func _update_shader_time_fx() -> void:
	if _material_instance == null:
		return

	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.08
	_set_shader_param_if_exists("intensity", intensity * pulse)


func _on_life_timer_timeout() -> void:
	_dbg("timeout -> despawn")
	_despawn()


func _despawn() -> void:
	if _is_despawning:
		return

	_is_despawning = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_3d, "modulate:a", 0.0, fade_out_time)

	if _material_instance != null:
		var current_dissolve: float = _get_shader_param_safe("dissolve_strength", dissolve_strength)
		tween.tween_method(_tween_dissolve, current_dissolve, 1.0, fade_out_time)

	tween.finished.connect(_on_fade_finished)


func _on_fade_finished() -> void:
	_dbg("fade terminado -> queue_free()")
	queue_free()


func _tween_dissolve(value: float) -> void:
	_set_shader_param_if_exists("dissolve_strength", value)


func _set_shader_param_if_exists(param_name: String, value) -> void:
	if _material_instance == null:
		return
	_material_instance.set_shader_parameter(param_name, value)


func _get_shader_param_safe(param_name: String, fallback: float) -> float:
	if _material_instance == null:
		return fallback

	var value = _material_instance.get_shader_parameter(param_name)
	if value == null:
		return fallback
	return float(value)
