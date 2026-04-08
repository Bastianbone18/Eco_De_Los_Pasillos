extends CanvasLayer

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

@export var next_scene_path: String = "res://Pantallas/Game_Over.tscn"

func _ready() -> void:
	play_jumpscare()

func play_jumpscare() -> void:
	if video_player == null:
		push_error("[Jumpscare] No se encontró VideoStreamPlayer.")
		get_tree().change_scene_to_file(next_scene_path)
		return

	# Asegurar que arranque desde 0
	video_player.stop()
	video_player.play()

	await video_player.finished
	get_tree().change_scene_to_file(next_scene_path)
