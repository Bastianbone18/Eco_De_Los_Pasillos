extends Control

var music_player: AudioStreamPlayer

func _ready():
	# Encuentra el nodo AudioStreamPlayer y almacénalo en la variable
	music_player = $AudioStreamPlayer  # Asegúrate de que AudioStreamPlayer está en la jerarquía correcta
	if music_player:  # Verifica que el nodo haya sido encontrado correctamente
		music_player.play()  # Reproduce la música
	else:
		print("Error: AudioStreamPlayer no encontrado en la jerarquía")

func _on_play_pressed():
	# Cambia a la escena 3D
	get_tree().change_scene_to_file("res://Btas_y pruebas/Mundo_prueba.tscn")  # Asegúrate de que la ruta sea correcta

func _on_options_pressed():
	# Cambia a la escena de opciones
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")  # Asegúrate de que la ruta sea correcta

func _on_exit_pressed():
	# Sale del juego
	get_tree().quit()

