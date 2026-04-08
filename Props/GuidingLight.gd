extends Node3D
class_name GuidingLight

signal reached(light: GuidingLight)

# =====================================================
# TEXTURAS
# =====================================================
@export var tex_normal: Texture2D = preload("res://Imagenes_pantallas/LuzProtectora.png")
@export var tex_warning: Texture2D = preload("res://Imagenes_pantallas/LuzProtectora_Media.png")
@export var tex_danger: Texture2D = preload("res://Imagenes_pantallas/LuzProtectora_Baja.png")

# =====================================================
# COLORES
# =====================================================
@export var normal_color  := Color(1.0, 0.92, 0.75)
@export var warning_color := Color(1.0, 0.55, 0.3)
@export var danger_color  := Color(0.9, 0.15, 0.15)

# =====================================================
# CONFIG
# =====================================================
@export var start_active: bool = false

# Pitch audio (solo al recoger)
@export var pitch_normal: float = 1.0
@export var pitch_warning: float = 0.95
@export var pitch_danger: float = 0.85
@export var pitch_rand: float = 0.03

# =====================================================
# FX PS1 / TERROR
# =====================================================
@export var crazy_fx: bool = true

@export var warning_flicker_speed: float = 12.0
@export var danger_flicker_speed: float = 24.0

@export var warning_jitter: float = 0.01
@export var danger_jitter: float = 0.03
@export var jitter_step: float = 0.004

@export var danger_blackout_chance: float = 0.18
@export var blackout_time: float = 0.06

@export var danger_color_glitch_strength: float = 0.18

# =====================================================
# NODOS
# =====================================================
@onready var area: Area3D = $Area3D
@onready var light_node: OmniLight3D = $OmniLight3D
@onready var sprite: Sprite3D = $Sprite3D
@onready var pickup_audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

# =====================================================
# ESTADO INTERNO
# =====================================================
var _visual_state: int = 0
var _t: float = 0.0
var _collected: bool = false

var _base_sprite_pos: Vector3
var _blackout_left: float = 0.0
var _flicker_phase: float = 0.0

# =====================================================
# READY
# =====================================================
func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	_base_sprite_pos = sprite.position
	set_active(start_active)
	_apply_visuals()

# =====================================================
# ACTIVAR / DESACTIVAR
# =====================================================
func set_active(value: bool) -> void:
	# NUNCA se reactiva después de recogida (evita bugs)
	if _collected:
		value = false

	light_node.visible = value
	sprite.visible = value
	area.set_deferred("monitoring", value)

	if not value:
		_t = 0.0
		_flicker_phase = 0.0
		_blackout_left = 0.0

# =====================================================
# PROCESO VISUAL
# =====================================================
func _process(delta: float) -> void:
	if not sprite.visible:
		return

	_t += delta

	var float_y: float = 1.2 + sin(_t * 2.5) * 0.05

	# =========================
	# NORMAL (sin FX locura)
	# =========================
	if not crazy_fx or _visual_state == 0:
		sprite.position = Vector3(_base_sprite_pos.x, float_y, _base_sprite_pos.z)
		sprite.modulate = Color.WHITE
		light_node.light_energy = 1.6 + sin(_t * 4.0) * 0.1
		return

	# =========================
	# WARNING / DANGER FX
	# =========================
	_flicker_phase += delta

	var flicker_speed := (warning_flicker_speed if _visual_state == 1 else danger_flicker_speed)
	var flicker := 1.0 if int(_flicker_phase * flicker_speed) % 2 == 0 else (0.45 if _visual_state == 1 else 0.18)

	var jitter_amount := (warning_jitter if _visual_state == 1 else danger_jitter)
	var jx := snappedf(randf_range(-jitter_amount, jitter_amount), jitter_step)
	var jz := snappedf(randf_range(-jitter_amount, jitter_amount), jitter_step)

	sprite.position = Vector3(_base_sprite_pos.x + jx, float_y, _base_sprite_pos.z + jz)

	var snap_deg := 8.0 if _visual_state == 1 else 16.0
	var target_deg := snappedf(rad_to_deg(sprite.rotation.y), snap_deg)
	sprite.rotation.y = lerp_angle(sprite.rotation.y, deg_to_rad(target_deg) + sin(_t) * 0.12, 0.35)

	var is_blackout := false

	if _visual_state == 2:
		if _blackout_left <= 0.0 and randf() < danger_blackout_chance * delta:
			_blackout_left = blackout_time

		if _blackout_left > 0.0:
			_blackout_left -= delta
			is_blackout = true

	if is_blackout:
		light_node.visible = false
		sprite.visible = false
		return
	else:
		light_node.visible = true
		sprite.visible = true

	if _visual_state == 2:
		var g := danger_color_glitch_strength
		var m := int(_t * 30.0) % 3
		if m == 0:
			sprite.modulate = Color(1.0, 1.0 - g, 1.0 - g)
		elif m == 1:
			sprite.modulate = Color(1.0 - g, 1.0, 1.0 - g)
		else:
			sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color.WHITE

	if _visual_state == 1:
		light_node.light_energy = (1.85 + sin(_t * 8.0) * 0.25) * flicker
	else:
		light_node.light_energy = (2.10 + sin(_t * 14.0) * 0.55) * flicker

# =====================================================
# COLISIÓN (INSTANTÁNEA 🔥)
# =====================================================
func _on_body_entered(body: Node) -> void:
	if _collected:
		return

	if not body.is_in_group("Player") and body.name != "Player":
		return

	_collected = true
	area.set_deferred("monitoring", false)
	set_active(false)

	if pickup_audio:
		var base_pitch := pitch_normal
		match _visual_state:
			1: base_pitch = pitch_warning
			2: base_pitch = pitch_danger

		pickup_audio.pitch_scale = base_pitch * randf_range(1.0 - pitch_rand, 1.0 + pitch_rand)
		pickup_audio.play()

	emit_signal("reached", self)

# =====================================================
# ESTADO VISUAL
# =====================================================
func set_visual_state(state: int) -> void:
	_visual_state = clampi(state, 0, 2)
	_apply_visuals()

func _apply_visuals() -> void:
	match _visual_state:
		0:
			sprite.texture = tex_normal
			light_node.light_color = normal_color
			sprite.scale = Vector3.ONE
		1:
			sprite.texture = tex_warning
			light_node.light_color = warning_color
			sprite.scale = Vector3.ONE * 0.98
		2:
			sprite.texture = tex_danger
			light_node.light_color = danger_color
			sprite.scale = Vector3.ONE * 0.94

	sprite.modulate = Color.WHITE
