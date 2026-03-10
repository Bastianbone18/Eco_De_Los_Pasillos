extends Node3D
class_name BlessedMedallion

# =========================
# TEXTURAS
# =========================
@export var tex_idle: Texture2D = preload("res://Imagenes_pantallas/Medallon.png")
@export var tex_flash: Texture2D = preload("res://Imagenes_pantallas/Medallon_Dorado.png")

# =========================
# GAMEPLAY
# =========================
@export var slow_multiplier: float = 0.33
@export var slow_duration: float = 1.7
@export var player_group: StringName = &"Player"

# =========================
# LUZ SAGRADA (COLOR)
# =========================
@export var idle_light_color: Color = Color(1.0, 0.88, 0.65)   # #FFE0A6 aprox
@export var flash_light_color: Color = Color(1.0, 0.97, 0.90)  # #FFF7E6 aprox
@export var fade_light_color: Color = Color(1.0, 0.85, 0.55)   # dorado final

# =========================
# FLASH (CINEMÁTICO)
# =========================
@export var flash_peak_energy: float = 18.0
@export var flash_ramp_up: float = 0.08
@export var flash_hold: float = 0.10
@export var flash_fade: float = 0.55

# =========================
# LEVITACIÓN SUAVE
# =========================
@export var float_height: float = 0.05
@export var float_speed: float = 2.0
@export var rotation_speed: float = 0.55

# PS1 snap (retro)
@export var ps1_snap_deg_idle: float = 4.0
@export var ps1_snap_deg_flash: float = 12.0

# “breathing” + micro flicker
@export var idle_energy_base: float = 1.35
@export var idle_energy_pulse: float = 0.18
@export var idle_micro_flicker: float = 0.08 # 0.0 = apagado

# Halo extra (Sprite3D)
@export var halo_scale_idle: float = 1.35
@export var halo_scale_flash: float = 2.15
@export var halo_alpha_idle: float = 0.06
@export var halo_alpha_flash: float = 0.90

# PS1 “frame skip” durante flash
@export var ps1_flash_flicker_speed: float = 16.0 # más alto = más parpadeo retro

# =========================
# PLAYER BUFF
# =========================
@export var stamina_restore: float = 35.0
@export var speed_buff_multiplier: float = 1.18
@export var speed_buff_duration: float = 1.2

# =========================
# NODOS
# =========================
@onready var sprite: Sprite3D = $Sprite3D
@onready var halo: Sprite3D = $HaloSprite3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var area: Area3D = $Area3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

# =========================
# ESTADO
# =========================
var _used: bool = false
var _t: float = 0.0
var _base_sprite_pos: Vector3
var _base_sprite_scale: Vector3
var _base_halo_scale: Vector3

func _ready() -> void:
	sprite.texture = tex_idle
	sprite.modulate = Color(1, 1, 1, 1)

	halo.texture = tex_flash
	halo.modulate = Color(1, 1, 1, halo_alpha_idle)
	halo.scale = Vector3.ONE * halo_scale_idle

	light.light_color = idle_light_color
	light.light_energy = idle_energy_base

	_base_sprite_pos = sprite.position
	_base_sprite_scale = sprite.scale
	_base_halo_scale = halo.scale

	area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _used:
		return

	_t += delta

	# Levitación suave
	var y_offset: float = sin(_t * float_speed) * float_height
	sprite.position = Vector3(_base_sprite_pos.x, _base_sprite_pos.y + y_offset, _base_sprite_pos.z)

	# Rotación lenta + snap PS1
	sprite.rotation.y += rotation_speed * delta
	_ps1_snap_sprite_y(ps1_snap_deg_idle)

	# Halo acompaña (levita/respira)
	halo.position = sprite.position
	halo.rotation.y = sprite.rotation.y

	# Respiración luminosa sagrada
	var pulse: float = sin(_t * 2.5) * idle_energy_pulse
	var flick: float = 1.0
	if idle_micro_flicker > 0.0:
		# micro flicker muy sutil tipo PS1 (no glitch)
		var is_on: bool = (int(_t * 24.0) % 2) == 0
		flick = 1.0 if is_on else (1.0 - idle_micro_flicker)

	light.light_energy = (idle_energy_base + pulse) * flick

	# Halo casi invisible en idle
	var a: float = halo_alpha_idle + (sin(_t * 2.2) * 0.01)
	halo.modulate.a = clampf(a, 0.03, 0.09)

func _on_body_entered(body: Node) -> void:
	if _used:
		return

	# Solo el jugador
	if not body.is_in_group(player_group):
		return

	print("MEDALLON ENTER by:", body.name)

	# ===== Buff al jugador (DURA MÁS) =====
	if body.has_method("add_stamina"):
		body.call("add_stamina", stamina_restore)

	if body.has_method("apply_speed_buff"):
		# ✅ BUFF real: 1.2 / 1.5s (lo que quieras)
		body.call("apply_speed_buff", speed_buff_multiplier, speed_buff_duration)

	# ===== Sacred feedback visual (DURA MENOS) =====
	if body.has_method("play_sacred_feedback"):
		# ✅ FX visual: 0.55s (solo feedback, no gameplay)
		body.call("play_sacred_feedback", 0.55)

	_used = true
	area.monitoring = false
	area.monitorable = false

	# Aplicar slow al enemigo (solo una vez)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("ChaseEnemy")
	if enemies.size() > 0:
		var enemy: Node = enemies[0]
		if enemy.has_method("apply_slow"):
			enemy.call("apply_slow", slow_multiplier, slow_duration)

	# Audio (si tiene stream)
	if audio and audio.stream:
		audio.play()

	await _flash_sequence()
	queue_free()
	
func _flash_sequence() -> void:
	# Cambiar textura del medallón a “dorado”
	sprite.texture = tex_flash

	# Color de luz: blanco cálido al inicio
	light.light_color = flash_light_color

	# Preparar halo
	halo.modulate.a = halo_alpha_flash
	halo.scale = Vector3.ONE * halo_scale_flash

	# Tween principal
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)

	# Expansión del medallón (suave, sagrada)
	t.tween_property(sprite, "scale", _base_sprite_scale * 1.45, flash_ramp_up)
	t.parallel().tween_property(light, "light_energy", flash_peak_energy, flash_ramp_up)

	# Halo “abre” como bendición
	t.parallel().tween_property(halo, "scale", Vector3.ONE * (halo_scale_flash * 1.06), flash_ramp_up)

	t.tween_interval(flash_hold)

	# Durante fade, el color pasa a dorado (se siente “divino”)
	t.tween_property(light, "light_color", fade_light_color, flash_fade)
	t.parallel().tween_property(light, "light_energy", 0.0, flash_fade)

	# Desaparece elegante (no explosión)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, flash_fade)
	t.parallel().tween_property(halo, "modulate:a", 0.0, flash_fade)

	# PS1 flicker durante flash (frame skip sutil)
	var total_flash_time: float = flash_ramp_up + flash_hold + flash_fade
	await _ps1_flash_flicker(total_flash_time)

	await t.finished

func _ps1_snap_sprite_y(step_deg: float) -> void:
	if step_deg <= 0.0:
		return
	var deg: float = rad_to_deg(sprite.rotation.y)
	var snapped: float = snappedf(deg, step_deg)
	sprite.rotation.y = deg_to_rad(snapped)

func _ps1_flash_flicker(total_time: float) -> void:
	var left: float = total_time
	var phase: float = 0.0

	while left > 0.0:
		var dt: float = minf(1.0 / 60.0, left)
		left -= dt
		phase += dt

		# Alterna alpha del halo como frame skip
		var on: bool = (int(phase * ps1_flash_flicker_speed) % 2) == 0
		if on:
			halo.modulate.a = halo_alpha_flash
		else:
			halo.modulate.a = halo_alpha_flash * 0.55

		# Snap más fuerte durante flash (PS1)
		_ps1_snap_sprite_y(ps1_snap_deg_flash)

		await get_tree().process_frame
