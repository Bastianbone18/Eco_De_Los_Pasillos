extends Control

var music_player: AudioStreamPlayer2D

func _ready():
	# Encuentra el nodo AudioStreamPlayer2D y almacénalo en la variable
	music_player = $AudioStreamPlayer2D
	music_player.play()  # Reproduce la música


func _on_play_pressed():
	get_tree().change_scene_to_file("res://Btas_y pruebas/Mundo_prueba.tscn")  # Cambia a la escena 3D


func _on_options_pressed():
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")


func _on_exit_pressed():
	get_tree().quit()
