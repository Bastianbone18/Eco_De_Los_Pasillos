extends Control

signal controls_finished

@export var fade_in_time: float = 0.25
@export var visible_time: float = 2.8
@export var fade_out_time: float = 0.25
@export var start_offset_y: float = 12.0

var _base_position: Vector2
var _is_playing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	modulate.a = 0.0
	_base_position = position


func play_controls() -> void:
	if _is_playing:
		return
	_is_playing = true

	visible = true
	modulate.a = 0.0
	position = _base_position + Vector2(0.0, start_offset_y)

	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.set_trans(Tween.TRANS_SINE)
	tween_in.set_ease(Tween.EASE_OUT)
	tween_in.parallel().tween_property(self, "modulate:a", 1.0, fade_in_time)
	tween_in.parallel().tween_property(self, "position", _base_position, fade_in_time)

	await tween_in.finished
	await get_tree().create_timer(visible_time, true, false, true).timeout

	var tween_out := create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.set_trans(Tween.TRANS_SINE)
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.parallel().tween_property(self, "modulate:a", 0.0, fade_out_time)
	tween_out.parallel().tween_property(self, "position", _base_position + Vector2(0.0, -8.0), fade_out_time)

	await tween_out.finished

	emit_signal("controls_finished")
	queue_free()
