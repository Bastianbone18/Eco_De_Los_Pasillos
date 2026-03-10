extends Area3D
class_name StopMusicArea

@export var fade_out_time: float = 1.0
@export var one_shot: bool = true

# ✅ “terror kill” (apagón incomodo)
@export var use_terror_kill: bool = true

# Si tu grupo es "Player" (como dijiste), déjalo así:
@export var player_group: StringName = &"Player"

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if one_shot and _used:
		return

	if not body.is_in_group(player_group):
		return

	_used = true

	if use_terror_kill:
		# ✅ Apagón tipo “cinta muriendo” (usa tu MusicManager integrado)
		await MusicManager.world2_kill_music_like_tape(fade_out_time)
	else:
		# apagón normal
		await MusicManager.fade_out_and_stop(fade_out_time)

	if one_shot:
		monitoring = false
		monitorable = false
