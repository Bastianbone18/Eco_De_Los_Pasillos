extends CanvasLayer
class_name AnxietyOverlay

@onready var fx: ColorRect = $FX
@onready var mat: ShaderMaterial = fx.material as ShaderMaterial

@export var ramp_seconds: float = 8.0
@export var max_strength: float = 1.0
@export var min_strength: float = 0.0
@export var ease_power: float = 1.9

# ✅ nuevo: cuánto dura después del diálogo
@export var hold_after_end_seconds: float = 1.8
# ✅ nuevo: fade más lento
@export var fade_out_time: float = 1.3

var _active: bool = false
var _t: float = 0.0
var _base_strength: float = 0.0

func _ready() -> void:
	visible = false
	_set_strength(0.0)

func begin_ramp(start_strength: float = 0.10) -> void:
	_active = true
	_t = 0.0
	_base_strength = clampf(start_strength, 0.0, 1.0)
	visible = true
	_set_strength(_base_strength)

func end_ramp() -> void:
	# deja de aumentar
	_active = false

	# ✅ mantiene el estado actual un rato
	if hold_after_end_seconds > 0.0:
		await get_tree().create_timer(hold_after_end_seconds).timeout

	# ✅ luego desvanece suave
	var from: float = float(mat.get_shader_parameter("strength"))

	var tw: Tween = create_tween()
	tw.tween_method(Callable(self, "_set_strength"), from, 0.0, fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(_on_fade_finished)

func _on_fade_finished() -> void:
	visible = false

func _process(delta: float) -> void:
	if not _active:
		return

	_t += delta

	var denom: float = maxf(ramp_seconds, 0.001)
	var p: float = clampf(_t / denom, 0.0, 1.0)

	# acelera al final (más pánico)
	p = pow(p, ease_power)

	var s: float = lerpf(_base_strength, max_strength, p)
	_set_strength(s)

func _set_strength(v: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("strength", clampf(v, min_strength, max_strength))
