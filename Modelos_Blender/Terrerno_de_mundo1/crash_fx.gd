extends CanvasLayer
class_name CrashFX

signal crash_finished


# =====================================================
# HIT (animación principal)
# =====================================================

@export var hit_anim_duration: float = 3.05
@export var fx_lead_in: float = 0.5   # empieza antes de terminar la anim


# =====================================================
# FX PULSE (shader)
# =====================================================

@export var fx_duration: float = 2.2
@export var fx_peak: float = 0.9
@export var fx_rise: float = 0.10
@export var fx_hold: float = 0.55     # fall = duration - (rise + hold)

@export var fx_loops: int = 1
@export var fx_gap: float = 0.05


# =====================================================
# OTROS
# =====================================================

@export var extra_delay_after_crash: float = 0.0


# =====================================================
# NODOS
# =====================================================

@onready var hit_rect: ColorRect = get_node_or_null("HitColor") as ColorRect
@onready var fx_rect: ColorRect = get_node_or_null("FX") as ColorRect
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var audio: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer


# =====================================================
# INTERNOS
# =====================================================

var _mat: ShaderMaterial
var _token: int = 0


# =====================================================
# READY
# =====================================================

func _ready() -> void:
	visible = false

	if hit_rect == null:
		push_error("[CrashFX] Falta hijo 'HitColor'.")
	else:
		hit_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	if fx_rect == null:
		push_error("[CrashFX] Falta hijo 'FX' (shader).")
	else:
		fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

		_mat = fx_rect.material as ShaderMaterial
		if _mat != null:
			_mat.set_shader_parameter("strength", 0.0)
		else:
			push_warning("[CrashFX] FX no tiene ShaderMaterial.")


# =====================================================
# PUBLIC API
# =====================================================

func play_crash() -> void:
	_token += 1
	var my_token: int = _token

	_show_fx()

	# Audio opcional
	if audio != null and audio.stream != null:
		audio.play()

	# Animación
	if anim != null and anim.has_animation("crash"):
		anim.play("crash")

	# ---- Esperar momento de inicio del shader ----
	var fx_start_at: float = max(0.0, hit_anim_duration - fx_lead_in)
	await get_tree().create_timer(fx_start_at).timeout
	if my_token != _token:
		return

	# ---- Pulsos FX ----
	await _play_fx_pulses(my_token)
	if my_token != _token:
		return

	# ---- Esperar resto de anim ----
	var remaining_anim: float = max(0.0, hit_anim_duration - fx_start_at)
	if remaining_anim > 0.0:
		await get_tree().create_timer(remaining_anim).timeout
		if my_token != _token:
			return

	# ---- Delay extra ----
	if extra_delay_after_crash > 0.0:
		await get_tree().create_timer(extra_delay_after_crash).timeout
		if my_token != _token:
			return

	_hide_fx()
	crash_finished.emit()


func stop() -> void:
	_token += 1
	_hide_fx()


# =====================================================
# VISUAL HELPERS
# =====================================================

func _show_fx() -> void:
	visible = true

	if hit_rect != null:
		hit_rect.visible = true

	if fx_rect != null:
		fx_rect.visible = false


func _hide_fx() -> void:
	if _mat != null:
		_mat.set_shader_parameter("strength", 0.0)

	visible = false


# =====================================================
# FX PULSES
# =====================================================

func _play_fx_pulses(my_token: int) -> void:
	if fx_rect != null:
		fx_rect.visible = true

	var loops: int = max(1, fx_loops)

	# Sin shader → solo respeta tiempos
	if _mat == null:
		var total_time: float = (fx_duration * loops) + (fx_gap * max(0, loops - 1))
		await get_tree().create_timer(total_time).timeout
		return

	for i: int in range(loops):
		if my_token != _token:
			return

		await _one_fx_pulse(my_token)

		if fx_gap > 0.0 and i < loops - 1:
			await get_tree().create_timer(fx_gap).timeout


func _one_fx_pulse(my_token: int) -> void:
	_mat.set_shader_parameter("strength", min(fx_peak, 0.35))
	await get_tree().process_frame
	if my_token != _token:
		return

	var rise: float = max(0.01, fx_rise)
	var hold: float = max(0.0, fx_hold)
	var fall: float = max(0.01, fx_duration - (rise + hold))

	# Rise
	var from_value: float = float(_mat.get_shader_parameter("strength"))
	_tween_strength(from_value, fx_peak, rise)
	await get_tree().create_timer(rise).timeout
	if my_token != _token:
		return

	# Hold
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
		if my_token != _token:
			return

	# Fall
	_tween_strength(fx_peak, 0.0, fall)
	await get_tree().create_timer(fall).timeout


# =====================================================
# TWEEN HELPERS
# =====================================================

func _set_strength(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("strength", v)


func _tween_strength(from_v: float, to_v: float, time: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(Callable(self, "_set_strength"), from_v, to_v, time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
