extends CanvasLayer
class_name SobreviveMisionHUD

@onready var root: Control = get_node_or_null("Root") as Control
@onready var top_center: Control = get_node_or_null("Root/TopCenter") as Control
@onready var timer_label: Label = get_node_or_null("Root/TopCenter/TimerLabel") as Label
@onready var bottom_left: Control = get_node_or_null("Root/BottomLeft") as Control
@onready var objective_label: Label = get_node_or_null("Root/BottomLeft/ObjectiveLabel") as Label
@onready var sub_label: Label = get_node_or_null("Root/BottomLeft/SubLabel") as Label

# ===== CONFIG =====
@export var fade_in_time: float = 0.20
@export var fade_out_time: float = 0.15

# Colores por cercanía
@export var safe_color: Color = Color("#F2D38A")
@export var warn_color: Color = Color("#B85A2B")
@export var danger_color: Color = Color("#6A1010")

# Umbrales de cercanía (ratio 0..1)
@export var warn_ratio: float = 0.68
@export var danger_ratio: float = 0.88

# Pulso escalas
@export var pulse_scale_safe: float = 1.00
@export var pulse_scale_warn: float = 1.05
@export var pulse_scale_panic: float = 1.10

# Jitter (px)
@export var jitter_px_warn: float = 0.8
@export var jitter_px_panic: float = 2.0

# Flicker sutil (solo muy cerca)
@export var panic_flicker_strength: float = 0.22

# ===== STATE =====
var _active: bool = false
var _total_time: float = 1.0
var _time_left: float = 0.0

var _danger: float = 0.0 # 0..1 (distancia enemigo)

var _pulse_tween: Tween = null
var _fade_tween: Tween = null

var _base_top_pos: Vector2 = Vector2.ZERO
var _base_bottom_pos: Vector2 = Vector2.ZERO

# ==================================================
# API
# ==================================================
func start(duration_sec: float, objective_text: String, sub_text: String = "") -> void:
	if not _ensure_nodes():
		return

	_active = true
	_total_time = max(0.01, float(duration_sec))
	_time_left = _total_time
	_danger = 0.0

	visible = true
	root.modulate.a = 0.0

	objective_label.text = objective_text
	if sub_label != null:
		sub_label.text = sub_text
		sub_label.visible = (sub_text.strip_edges() != "")

	_update_texts()
	_apply_color(safe_color)

	_fade_to(1.0, fade_in_time)
	_start_soft_pulse()

# ✅ ChaseManager llamará esto constantemente
func set_danger_ratio(r: float) -> void:
	_danger = clamp(r, 0.0, 1.0)

func stop() -> void:
	if not visible:
		return

	_active = false
	_stop_pulse()
	_reset_jitter_positions()
	_fade_to(0.0, fade_out_time)

	if _fade_tween:
		_fade_tween.finished.connect(func():
			visible = false
			queue_free()
		, CONNECT_ONE_SHOT)
	else:
		visible = false
		queue_free()

# ==================================================
func _ready() -> void:
	if not _ensure_nodes():
		visible = false
		return

	visible = true
	root.modulate.a = 0.0

	_base_top_pos = top_center.position
	_base_bottom_pos = bottom_left.position

	timer_label.text = "00:00"
	objective_label.text = ""
	if sub_label:
		sub_label.text = ""
		sub_label.visible = false

func _process(delta: float) -> void:
	if not _active:
		return
	if not _ensure_nodes():
		return

	# Timer normal (cuenta atrás)
	_time_left = max(0.0, _time_left - float(delta))
	_update_texts()

	# ✅ Estilo ahora depende de DISTANCIA (danger ratio)
	_update_style_from_danger(float(delta))

	if _time_left <= 0.0:
		_active = false
		stop()

# ==================================================
func _update_texts() -> void:
	var seconds_left: int = int(ceil(_time_left))
	var mm: int = seconds_left / 60
	var ss: int = seconds_left % 60
	timer_label.text = "%02d:%02d" % [mm, ss]

# ==================================================
# ✅ Estilo por distancia
# ==================================================
func _update_style_from_danger(delta: float) -> void:
	# suavizar cambios para que no “salte”
	var d: float = clamp(_danger, 0.0, 1.0)

	# color por umbrales
	var c: Color = safe_color
	if d >= danger_ratio:
		c = danger_color
	elif d >= warn_ratio:
		c = warn_color

	_apply_color(c)

	# Intensidad no lineal (más agresiva cerca)
	var panic: float = pow(d, 1.65)

	# Pulso más grande cerca
	var target_scale: float = lerp(pulse_scale_safe, pulse_scale_panic, panic)
	_set_pulse_strength(target_scale)

	# Jitter sube MUCHO cerca (solo un poquito a media distancia)
	var jitter_amt: float = 0.0
	if d >= warn_ratio:
		var t: float = clamp((d - warn_ratio) / max(0.001, (1.0 - warn_ratio)), 0.0, 1.0)
		jitter_amt = lerp(jitter_px_warn, jitter_px_panic, pow(t, 1.8))
	_apply_jitter(jitter_amt)

	# Flicker sutil solo casi perdiendo
	if d >= danger_ratio and panic_flicker_strength > 0.0:
		var flick: float = 1.0 - (randf() * panic_flicker_strength * panic)
		root.modulate.a = lerp(root.modulate.a, flick, 0.35)
	else:
		root.modulate.a = lerp(root.modulate.a, 1.0, 0.12)

# ==================================================
func _apply_color(c: Color) -> void:
	timer_label.modulate = c
	objective_label.modulate = c
	if sub_label:
		sub_label.modulate = Color(c.r, c.g, c.b, 0.85)

func _start_soft_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE * 1.02, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE * 1.00, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_pulse_tween.tween_property(bottom_left, "scale", Vector2.ONE * 1.01, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(bottom_left, "scale", Vector2.ONE * 1.00, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _set_pulse_strength(target_scale: float) -> void:
	timer_label.scale = timer_label.scale.lerp(Vector2.ONE * target_scale, 0.25)
	bottom_left.scale = bottom_left.scale.lerp(Vector2.ONE * (1.0 + (target_scale - 1.0) * 0.70), 0.25)

func _apply_jitter(amount_px: float) -> void:
	if amount_px <= 0.0:
		_reset_jitter_positions()
		return

	var jx: float = (randf() * 2.0 - 1.0) * amount_px
	var jy: float = (randf() * 2.0 - 1.0) * amount_px

	top_center.position = _base_top_pos + Vector2(round(jx), round(jy))
	bottom_left.position = _base_bottom_pos + Vector2(round(-jx * 0.6), round(jy * 0.6))

func _reset_jitter_positions() -> void:
	top_center.position = _base_top_pos
	bottom_left.position = _base_bottom_pos

func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	timer_label.scale = Vector2.ONE
	bottom_left.scale = Vector2.ONE

func _fade_to(alpha: float, t: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(root, "modulate:a", alpha, max(0.01, t)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _ensure_nodes() -> bool:
	if root == null:
		push_error("[SobreviveMisionHUD] Falta nodo: Root")
		return false
	if top_center == null:
		push_error("[SobreviveMisionHUD] Falta nodo: Root/TopCenter")
		return false
	if timer_label == null:
		push_error("[SobreviveMisionHUD] Falta nodo: Root/TopCenter/TimerLabel")
		return false
	if bottom_left == null:
		push_error("[SobreviveMisionHUD] Falta nodo: Root/BottomLeft")
		return false
	if objective_label == null:
		push_error("[SobreviveMisionHUD] Falta nodo: Root/BottomLeft/ObjectiveLabel")
		return false
	return true
