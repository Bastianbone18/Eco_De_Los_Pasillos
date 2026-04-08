extends CharacterBody3D
class_name EnemigoChase

signal captured(player: Node)

# =========================
# CONFIG MOVIMIENTO
# =========================
@export var gravity: float = 9.8
@export var turn_speed: float = 8.0
@export var model_yaw_offset_deg: float = 180.0

# ✅ Layer donde vive el Player (para TouchArea)
@export var player_collision_layer: int = 1

# AUDIO
@export var scream_stream: AudioStream = preload("res://Musica y sonidos/Sonidos/Grito_demoniaco.ogg")
@export var scream_volume_db: float = 2.0
@export var scream_duration: float = 1.4

# Persecución por fases
@export var phase1_time: float = 25.0
@export var phase2_time: float = 90.0

@export var speed_phase1: float = 5.4
@export var speed_phase2: float = 6.15
@export var speed_phase3: float = 7.1

# Catch-up suave
@export var catchup_distance: float = 18.0
@export var catchup_extra_speed: float = 0.9

# =========================
# CINEMÁTICA
# =========================
@export var start_run_delay: float = 0.15

# Anim names
@export var anim_idle: StringName   = &"Iddle"
@export var anim_scream: StringName = &"Grito"
@export var anim_run: StringName    = &"Correr"

# Nodes
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var touch_area: Area3D = $TouchArea

# =========================
# LUZ ROJA PROXIMIDAD (3D)
# =========================
@export var proximity_light_path: NodePath
@export var fear_max_distance: float = 18.0
@export var fear_min_distance: float = 2.5
@export var max_light_energy: float = 3.0
@export var light_pulse_speed: float = 6.0
@export var light_energy_smooth: float = 12.0

@onready var proximity_light: Light3D = get_node_or_null(proximity_light_path) as Light3D
var _current_light_energy: float = 0.0

# =========================
# ESTADO CHASE
# =========================
var _target: Node3D = null
var _chasing: bool = false
var _locked: bool = true
var _has_captured: bool = false
var _chase_time: float = 0.0

# =========================
# SLOW (por medallón)
# =========================
var _slow_mult: float = 1.0
var _slow_timer: float = 0.0
var _stun_timer: float = 0.0


func apply_slow(mult: float, duration: float) -> void:
	mult = clamp(mult, 0.05, 1.0)
	duration = max(duration, 0.0)

	_slow_mult = min(_slow_mult, mult)
	_slow_timer = max(_slow_timer, duration)
	_stun_timer = max(_stun_timer, 0.25)

	print("[ENEMY] SLOW -> mult=", _slow_mult, " dur=", _slow_timer, " chase_time=", _chase_time)


func _ready() -> void:
	add_to_group("ChaseEnemy")
	set_physics_process(false)
	_setup_touch_area()
	_play(anim_idle)

	if proximity_light:
		proximity_light.light_energy = 0.0
		_current_light_energy = 0.0


func _setup_touch_area() -> void:
	if touch_area == null:
		return

	touch_area.collision_layer = 0
	touch_area.collision_mask = 0
	touch_area.set_collision_mask_value(player_collision_layer, true)

	touch_area.monitorable = true
	touch_area.monitoring = false

	var shape := touch_area.get_node_or_null("CollisionShape3D")
	if shape:
		shape.disabled = false

	if not touch_area.body_entered.is_connected(_on_touch_area_body_entered):
		touch_area.body_entered.connect(_on_touch_area_body_entered)


func _set_touch_enabled(enabled: bool) -> void:
	if touch_area == null:
		return

	touch_area.set_deferred("monitoring", enabled)

	var shape := touch_area.get_node_or_null("CollisionShape3D")
	if shape:
		shape.set_deferred("disabled", not enabled)


# =========================
# API
# =========================
func prepare_and_show(at_transform: Transform3D) -> void:
	var keep_scale: Vector3 = global_transform.basis.get_scale()

	global_position = at_transform.origin
	global_rotation = at_transform.basis.get_euler()

	var b: Basis = Basis.from_euler(global_rotation).scaled(keep_scale)
	global_transform = Transform3D(b, global_position)

	_has_captured = false
	_chasing = false
	_locked = true
	_target = null
	_chase_time = 0.0
	velocity = Vector3.ZERO

	_slow_mult = 1.0
	_slow_timer = 0.0
	_stun_timer = 0.0

	_current_light_energy = 0.0
	if proximity_light:
		proximity_light.light_energy = 0.0

	_set_touch_enabled(false)

	visible = true
	set_physics_process(true)
	_play(anim_idle)


func set_target(t: Node3D) -> void:
	_target = t


func hold_idle() -> void:
	_locked = true
	_chasing = false
	_chase_time = 0.0
	set_physics_process(true)
	_play(anim_idle)
	_set_light_energy_target(0.0)
	_set_touch_enabled(false)


func scream_then_chase() -> void:
	_do_scream_then_chase()


func _do_scream_then_chase() -> void:
	_locked = true
	_chasing = false
	_set_light_energy_target(0.0)
	_set_touch_enabled(false)

	_play(anim_scream)

	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = scream_stream
	sfx.volume_db = scream_volume_db
	sfx.unit_size = 7.0
	sfx.max_distance = 40.0
	add_child(sfx)
	sfx.play()

	await get_tree().create_timer(scream_duration).timeout

	if is_instance_valid(sfx):
		sfx.queue_free()

	await get_tree().create_timer(start_run_delay).timeout

	_locked = false
	_chasing = true
	_chase_time = 0.0
	_play(anim_run)
	_set_touch_enabled(true)


func stop_all() -> void:
	_chasing = false
	_locked = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	_play(anim_idle)
	_set_light_energy_target(0.0)
	_set_touch_enabled(false)


func is_chasing() -> bool:
	return _chasing and not _locked and not _has_captured and _target != null


# =========================
# MOVIMIENTO
# =========================
func _physics_process(delta: float) -> void:
	if _has_captured:
		_update_light(delta, 0.0)
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_mult = 1.0

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if _target != null:
		var to_vec: Vector3 = (_target.global_position - global_position)
		_face_target_horizontally(to_vec, delta)

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_light(delta, _compute_light_target_energy())
		return

	if _locked or not _chasing or _target == null:
		move_and_slide()
		_update_light(delta, 0.0)
		return

	_chase_time += delta

	var flat: Vector3 = (_target.global_position - global_position)
	flat.y = 0.0
	var dist: float = flat.length()

	if dist < 0.001:
		move_and_slide()
		_update_light(delta, _compute_light_target_energy())
		return

	var dir: Vector3 = flat / dist

	var base_spd: float = _get_current_phase_speed()
	if dist > catchup_distance:
		base_spd += catchup_extra_speed

	var final_spd: float = base_spd * _slow_mult

	velocity.x = dir.x * final_spd
	velocity.z = dir.z * final_spd

	move_and_slide()
	_update_light(delta, _compute_light_target_energy())


func _get_current_phase_speed() -> float:
	if _chase_time < phase1_time:
		return speed_phase1
	elif _chase_time < phase2_time:
		return speed_phase2
	else:
		return speed_phase3


func _face_target_horizontally(to_vec: Vector3, delta: float) -> void:
	var v: Vector3 = Vector3(to_vec.x, 0.0, to_vec.z)
	if v.length() < 0.001:
		return
	v = v.normalized()

	var yaw: float = atan2(v.x, v.z) + deg_to_rad(model_yaw_offset_deg)
	rotation.y = lerp_angle(rotation.y, yaw, turn_speed * delta)


func _on_touch_area_body_entered(body: Node) -> void:
	if _has_captured:
		return
	if not body.is_in_group("Player"):
		return

	_has_captured = true
	_locked = true
	_chasing = false
	set_physics_process(false)
	velocity = Vector3.ZERO

	_set_light_energy_target(0.0)
	_set_touch_enabled(false)
	_play(anim_idle)

	call_deferred("_emit_captured_deferred", body)


func _emit_captured_deferred(body: Node) -> void:
	emit_signal("captured", body)


func _play(name: StringName) -> void:
	if animation_player and animation_player.has_animation(name):
		animation_player.play(name)


# =========================
# LUZ PROXIMIDAD (helpers)
# =========================
func _compute_light_target_energy() -> float:
	if proximity_light == null:
		return 0.0
	if _target == null:
		return 0.0
	if not is_chasing():
		return 0.0

	var dist: float = global_position.distance_to(_target.global_position)
	var t: float = inverse_lerp(fear_max_distance, fear_min_distance, dist)
	t = clamp(t, 0.0, 1.0)
	t = t * t

	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * light_pulse_speed)
	return t * max_light_energy * (0.6 + 0.4 * pulse)


func _set_light_energy_target(value: float) -> void:
	if proximity_light == null:
		return
	_current_light_energy = value
	proximity_light.light_energy = value


func _update_light(delta: float, target_energy: float) -> void:
	if proximity_light == null:
		return
	_current_light_energy = lerp(_current_light_energy, target_energy, 1.0 - exp(-light_energy_smooth * delta))
	proximity_light.light_energy = _current_light_energy
