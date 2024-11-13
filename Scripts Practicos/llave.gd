extends StaticBody3D

@onready var pickup_sound = $AudioStreamPlayer3D

func action_use():
	if pickup_sound:
		pickup_sound.play()
	await get_tree().create_timer(3).timeout  # Espera medio segundo antes de eliminar
	queue_free()

