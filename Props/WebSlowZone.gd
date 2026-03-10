extends Node3D
class_name WebSlowZone

@export var slow_multiplier: float = 0.7
@export var slow_duration: float = 0.6
@export var player_group: StringName = &"Player"
@onready var sticky_sound: AudioStreamPlayer3D = $StickySound

@onready var area: Area3D = $Area3D

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	
	
	if not body.is_in_group(player_group):
		return

	# Requiere que el Player tenga una función pública para aplicar slow:
	
	# player.apply_external_slow(multiplier, duration)
	if body.has_method("apply_external_slow"):
		body.call("apply_external_slow", slow_multiplier, slow_duration)
		
		
	else:
		push_warning("[WebSlowZone] El Player no tiene apply_external_slow(multiplier, duration)")
		
	if not body.is_in_group(player_group):
		return

	if body.has_method("apply_external_slow"):
		body.call("apply_external_slow", slow_multiplier, slow_duration)

	# 🔊 sonido 1 vez
	if sticky_sound and not sticky_sound.playing:
		sticky_sound.play()

	if body.has_method("trigger_camera_shake"):
		body.call("trigger_camera_shake", 0.25, 0.03)
