extends ColorRect
class_name MentalAlert

@export var flash_fade_in_speed: float = 8.0
@export var flash_fade_out_speed: float = 2.4
@export var corruption_lerp_speed: float = 4.0

var flash_strength: float = 0.0
var flash_target: float = 0.0
var flash_timer: float = 0.0
var flash_active: bool = false

var corruption_strength: float = 0.0
var visual_strength: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if material:
		material.set_shader_parameter("strength", 0.0)


func _process(delta: float) -> void:
	if material == null:
		return

	if flash_active:
		flash_strength = move_toward(flash_strength, flash_target, flash_fade_in_speed * delta)

		if flash_strength >= flash_target - 0.01:
			flash_timer -= delta
			if flash_timer <= 0.0:
				flash_active = false
				flash_target = 0.0
	else:
		flash_strength = move_toward(flash_strength, 0.0, flash_fade_out_speed * delta)

	var target_visual: float = max(corruption_strength, flash_strength)
	visual_strength = move_toward(visual_strength, target_visual, corruption_lerp_speed * delta)

	material.set_shader_parameter("strength", float(clamp(visual_strength, 0.0, 1.0)))


func trigger_alert(intensity: float = 0.85, duration: float = 0.45) -> void:
	flash_target = float(clamp(intensity, 0.0, 1.0))
	flash_timer = max(duration, 0.01)
	flash_active = true


func clear_alert() -> void:
	flash_active = false
	flash_target = 0.0
	flash_strength = 0.0


func set_corruption(amount: float) -> void:
	corruption_strength = float(clamp(amount, 0.0, 1.0))


func clear_corruption() -> void:
	corruption_strength = 0.0
