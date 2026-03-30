extends CanvasLayer

@onready var photo: AnimatedSprite2D = $AnimatedSprite2D

@export var time_to_full_distortion: float = 9.0
@export var max_progress: float = 1.0
@export var auto_start: bool = false

var elapsed: float = 0.0
var active_effect: bool = false
var shader_mat: ShaderMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if photo.material is ShaderMaterial:
		shader_mat = photo.material as ShaderMaterial
		shader_mat.set_shader_parameter("progress", 0.0)
	else:
		push_warning("⚠️ AnimatedSprite2D no tiene ShaderMaterial")

	if auto_start:
		start_effect()

func _process(delta: float) -> void:
	if not active_effect:
		return

	if shader_mat == null:
		return

	elapsed += delta

	var t: float = clamp(elapsed / time_to_full_distortion, 0.0, max_progress)
	t = smoothstep(0.0, 1.0, t)

	shader_mat.set_shader_parameter("progress", t)

func start_effect() -> void:
	elapsed = 0.0
	active_effect = true

	if shader_mat:
		shader_mat.set_shader_parameter("progress", 0.0)

func stop_effect() -> void:
	active_effect = false

func set_distortion_duration(value: float) -> void:
	time_to_full_distortion = max(value, 0.1)
