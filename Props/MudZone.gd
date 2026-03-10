extends Node3D
class_name MudZone

@export var drain_multiplier: float = 1.4
@export var player_group: StringName = &"Player"
@export var stop_audio_on_exit: bool = true

@onready var area: Area3D = $Area3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _player_inside: Node = null

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return

	_player_inside = body

	if body.has_method("apply_stamina_drain"):
		body.call("apply_stamina_drain", drain_multiplier)

	if audio_player:
		# Reproduce una vez por entrada
		audio_player.stop()
		audio_player.play()

func _on_body_exited(body: Node) -> void:
	if body != _player_inside:
		return

	if body.has_method("apply_stamina_drain"):
		body.call("apply_stamina_drain", 1.0) # vuelve a normal

	_player_inside = null

	if stop_audio_on_exit and audio_player:
		audio_player.stop()
