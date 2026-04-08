extends CanvasLayer
class_name DarknessOverlay

@warning_ignore("unused_signal")
signal game_over_requested

# --- Timing/thresholds (los setea LightManager al iniciar)
@export var time_per_light: float = 6.0
@export var warning_threshold: float = 0.4
@export var danger_threshold: float = 0.2

@export var hands_anim_name: String = "hands"
@export var hands_fps: int = 24
@export var hands_source_size: Vector2 = Vector2(1920, 1080)

# Audio de presión
@export_file("*.ogg", "*.wav", "*.mp3") var pressure_sound_path: String = "res://Musica y sonidos/Sonidos/ManosSonido.ogg"
@export var pressure_volume_start_db: float = -28.0
@export var pressure_volume_mid_db: float = -16.0
@export var pressure_volume_end_db: float = -6.0
@export var pressure_pitch_start: float = 0.82
@export var pressure_pitch_mid: float = 0.96
@export var pressure_pitch_end: float = 1.08

# Frames (0..179)
const SAFE_START: int = 0
const SAFE_END: int = 107
const ORANGE_START: int = 108
const ORANGE_END: int = 143
const RED_START: int = 144
const RED_END: int = 179
const RED_FAST_START: int = 168

@onready var hands: AnimatedSprite2D = (
	get_node_or_null("HandsRoot/Hands") as AnimatedSprite2D
	if get_node_or_null("HandsRoot/Hands") != null
	else get_node_or_null("Hands") as AnimatedSprite2D
)

@onready var neck_snap: AudioStreamPlayer = get_node_or_null("NeckSnap") as AudioStreamPlayer
@onready var pressure_loop: AudioStreamPlayer = get_node_or_null("PressureLoop") as AudioStreamPlayer

var _active: bool = false
var _ready_ok: bool = false
var _is_killing: bool = false
var _kill_token: int = 0

func _enter_tree() -> void:
	visible = false

func _ready() -> void:
	if not is_in_group("darkness_overlay"):
		add_to_group("darkness_overlay")

	if hands == null:
		push_error("[DarknessOverlay] No encuentro 'Hands' (AnimatedSprite2D).")
		_ready_ok = false
		return

	_ready_ok = true
	layer = 100

	# Setup base
	hands.visible = true
	hands.centered = true
	hands.offset = Vector2.ZERO
	hands.z_index = 1000
	hands.z_as_relative = false
	hands.modulate = Color(1, 1, 1, 1)

	hands.play(hands_anim_name)
	hands.pause()
	hands.frame = SAFE_START

	_relayout()
	get_viewport().size_changed.connect(_on_viewport_resized)

	# NeckSnap
	if neck_snap != null:
		neck_snap.process_mode = Node.PROCESS_MODE_ALWAYS
		if neck_snap.stream == null:
			push_error("[DarknessOverlay] NeckSnap existe pero NO tiene Stream asignado.")

	# PressureLoop
	_setup_pressure_loop()

	_active = false
	_is_killing = false
	visible = false

func _setup_pressure_loop() -> void:
	if pressure_loop == null:
		push_warning("[DarknessOverlay] No existe 'PressureLoop'. Créalo como hijo de DarknessOverlay.")
		return

	pressure_loop.process_mode = Node.PROCESS_MODE_ALWAYS
	pressure_loop.bus = "Master"

	if pressure_loop.stream == null:
		var loaded_stream: Resource = load(pressure_sound_path)
		if loaded_stream is AudioStream:
			pressure_loop.stream = loaded_stream as AudioStream
		else:
			push_error("[DarknessOverlay] No se pudo cargar el sonido de presión: %s" % pressure_sound_path)
			return

	pressure_loop.volume_db = pressure_volume_start_db
	pressure_loop.pitch_scale = pressure_pitch_start
	pressure_loop.stop()

func _on_viewport_resized() -> void:
	_relayout()

func _relayout() -> void:
	if not _ready_ok:
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	hands.position = vp * 0.5

	var sx: float = vp.x / hands_source_size.x
	var sy: float = vp.y / hands_source_size.y
	var s: float = max(sx, sy)

	hands.scale = Vector2(s, s)

# -------------------------
# API usada por LightManager
# -------------------------
func set_active(v: bool) -> void:
	_active = v
	visible = _active

	if not _ready_ok:
		return

	_stop_kill_sequence()

	hands.visible = true
	hands.modulate.a = 1.0
	hands.pause()

	if not _active:
		hands.frame = SAFE_START
		_stop_pressure_loop()
		return

	hands.frame = SAFE_START
	_start_pressure_loop()
	_apply_pressure_from_progress(0.0)
	_relayout()

func play_intro_hint(_duration: float = 1.2) -> void:
	pass

func set_time_left(time_left: float) -> void:
	if not _active or not _ready_ok:
		return

	time_left = clamp(time_left, 0.0, time_per_light)

	var warning_time: float = time_per_light * warning_threshold
	var danger_time: float = time_per_light * danger_threshold

	# progreso global 0 -> 1
	var global_progress: float = 1.0 - (time_left / max(time_per_light, 0.0001))
	_apply_pressure_from_progress(global_progress)

	# SAFE
	if time_left > warning_time:
		_stop_kill_sequence()
		hands.pause()

		var elapsed: float = time_per_light - time_left
		var denom: float = max(0.0001, time_per_light - warning_time)
		var t: float = clamp(elapsed / denom, 0.0, 1.0)

		hands.frame = int(lerp(float(SAFE_START), float(SAFE_END), t))
		return

	# ORANGE
	if time_left > danger_time:
		_stop_kill_sequence()
		hands.pause()

		var elapsed2: float = warning_time - time_left
		var denom2: float = max(0.0001, warning_time - danger_time)
		var t2: float = clamp(elapsed2 / denom2, 0.0, 1.0)

		hands.frame = int(lerp(float(ORANGE_START), float(ORANGE_END), t2))
		return

	# RED
	if not _is_killing:
		_is_killing = true
		_kill_token += 1
		hands.pause()
		hands.frame = RED_START
		_run_red_close_step(_kill_token)

func _stop_kill_sequence() -> void:
	if _is_killing:
		_is_killing = false
		_kill_token += 1

func _start_pressure_loop() -> void:
	if pressure_loop == null:
		return
	if pressure_loop.stream == null:
		return

	pressure_loop.volume_db = pressure_volume_start_db
	pressure_loop.pitch_scale = pressure_pitch_start

	if not pressure_loop.playing:
		pressure_loop.play()

func _stop_pressure_loop() -> void:
	if pressure_loop == null:
		return

	pressure_loop.stop()
	pressure_loop.volume_db = pressure_volume_start_db
	pressure_loop.pitch_scale = pressure_pitch_start

func _apply_pressure_from_progress(progress: float) -> void:
	if pressure_loop == null:
		return
	if pressure_loop.stream == null:
		return

	progress = clamp(progress, 0.0, 1.0)

	if not pressure_loop.playing:
		pressure_loop.play()

	# 0.0 - 0.6 = empieza lento
	# 0.6 - 1.0 = aprieta más fuerte
	if progress <= 0.6:
		var t: float = progress / 0.6
		pressure_loop.volume_db = lerp(pressure_volume_start_db, pressure_volume_mid_db, t)
		pressure_loop.pitch_scale = lerp(pressure_pitch_start, pressure_pitch_mid, t)
	else:
		var t2: float = (progress - 0.6) / 0.4
		pressure_loop.volume_db = lerp(pressure_volume_mid_db, pressure_volume_end_db, t2)
		pressure_loop.pitch_scale = lerp(pressure_pitch_mid, pressure_pitch_end, t2)

func _play_neck_snap() -> void:
	_stop_pressure_loop()

	if neck_snap == null:
		push_error("[DarknessOverlay] No existe el nodo NeckSnap.")
		return

	if neck_snap.stream == null:
		push_error("[DarknessOverlay] NeckSnap no tiene Stream asignado.")
		return

	neck_snap.stop()
	neck_snap.play()

func _run_red_close_step(token: int) -> void:
	if not _active or not _ready_ok:
		return

	if token != _kill_token:
		return

	_apply_pressure_from_progress(1.0)

	if hands.frame >= RED_END:
		hands.pause()
		call_deferred("_play_neck_snap")
		emit_signal("game_over_requested")
		return

	var delay: float = 1.0 / float(hands_fps)
	if hands.frame >= RED_FAST_START:
		delay *= 0.55
	else:
		delay *= 1.15

	hands.frame += 1

	get_tree().create_timer(delay).timeout.connect(func() -> void:
		_run_red_close_step(token)
	)
