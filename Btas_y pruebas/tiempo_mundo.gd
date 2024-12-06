extends Node3D

var tiempo_actual = 0.0  # Almacena el tiempo sobrevivido

func _ready():
	tiempo_actual = 0.0  # Reiniciar el tiempo al cargar la escena

func _process(delta):
	tiempo_actual += delta  # Incrementar el tiempo con cada frame

	# Condición para finalizar el juego (puedes personalizar esta lógica)
	if should_end_game():
		end_game()

func should_end_game() -> bool:
	# Define tu lógica de finalización, por ejemplo, si la salud del jugador llega a 0
	return false

func end_game():
	# Guardar el tiempo sobrevivido en el singleton
	GameData.survival_time = tiempo_actual

	# Cambiar a la pantalla de Game Over
	get_tree().change_scene_to_file("res://Pantallas/GameOver.tscn")
