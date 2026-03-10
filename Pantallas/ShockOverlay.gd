extends CanvasLayer
class_name ShockOverlay

@export var default_duration: float = 4.0
@export var default_peak: float = 0.85

@onready var fx: ColorRect = $FX
@onready var anim: AnimationPlayer = $Anim # (no se usa por ahora, pero lo dejamos)

var _mat: ShaderMaterial
var _token: int = 0

func _ready() -> void:
	visible = false
	_mat = fx.material as ShaderMaterial
	if _mat != null:
		_mat.set_shader_parameter("strength", 0.0)

func play_shock(duration: float = -1.0, peak: float = -1.0) -> void:
	if duration <= 0.0:
		duration = default_duration
	if peak < 0.0:
		peak = default_peak

	_token += 1
	var my_token: int = _token

	if _mat == null:
		push_warning("[ShockOverlay] FX no tiene ShaderMaterial.")
		visible = false
		return

	visible = true
	_mat.set_shader_parameter("strength", 0.0)

	# 1) impacto
	_tween_strength(0.0, peak, 0.15)
	await get_tree().create_timer(0.15).timeout
	if my_token != _token:
		return

	# 2) sostén corto
	var hold_time: float = min(0.8, duration * 0.25)
	await get_tree().create_timer(hold_time).timeout
	if my_token != _token:
		return

	# 3) recovery (baja hasta 0)
	var remaining: float = max(0.2, duration - (0.15 + hold_time))
	var current_strength: float = float(_mat.get_shader_parameter("strength"))
	_tween_strength(current_strength, 0.0, remaining)

	await get_tree().create_timer(remaining).timeout
	if my_token != _token:
		return

	visible = false

func stop() -> void:
	_token += 1
	if _mat != null:
		_mat.set_shader_parameter("strength", 0.0)
	visible = false

func _set_strength(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("strength", v)

func _tween_strength(from_v: float, to_v: float, time: float) -> void:
	if _mat == null:
		return
	var tw: Tween = create_tween()
	tw.tween_method(Callable(self, "_set_strength"), from_v, to_v, time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
