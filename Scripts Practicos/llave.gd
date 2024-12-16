extends StaticBody3D

@onready var pickup_sound = $AudioStreamPlayer3D
var is_picked_up = false  # Bandera para evitar que el sonido se reproduzca varias veces

func _ready():
	print("¡Funciona!")

func action_use():
	if is_picked_up:
		return  # Si ya se recogió, no hacer nada

	is_picked_up = true  # Marcar como recogido
	if pickup_sound:
		pickup_sound.play()

	# Espera 3 segundos antes de eliminar
	await get_tree().create_timer(3).timeout
	queue_free()
