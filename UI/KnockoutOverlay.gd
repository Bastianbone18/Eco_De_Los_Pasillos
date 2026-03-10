extends CanvasLayer
class_name KnockoutOverlay

signal finished

@export var anim_name: StringName = &"knockout_hit"

@onready var rect: ColorRect = $KnockoutOverlay
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var _playing := false

func play_knockout() -> void:
	if _playing:
		return
	_playing = true

	visible = true
	layer = 200 # encima de todo (ajusta si ya usas layers)

	# Reset visual (por si quedó en negro de una llamada anterior)
	if rect:
		var c := rect.color
		c.a = 0.0
		rect.color = c

	# Arranca anim + audio en el MISMO frame
	if anim:
		anim.stop()
		anim.play(anim_name)

	if audio and audio.stream:
		audio.stop()
		audio.play()

	# Espera fin de anim (más confiable que esperar audio)
	if anim and anim.animation_finished.is_connected(_on_anim_finished) == false:
		anim.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(name: StringName) -> void:
	if name != anim_name:
		return

	# Mantén negro si quieres (no ocultamos rect)
	# Si prefieres ocultar el overlay después del anim:
	# visible = false

	_playing = false
	emit_signal("finished")
