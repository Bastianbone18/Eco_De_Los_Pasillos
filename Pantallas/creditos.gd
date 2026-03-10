extends Control

@onready var button_sound_player = $AudioStreamPlayerBoton

func _ready():
	# Asegura música de menú sonando (no reinicia si ya suena)
	MusicManager.play_menu()

func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

func _on_tiktok_pressed():
	play_button_sound()
	OS.shell_open("https://www.tiktok.com/@bastianbone18")

func _on_ig_pressed():
	play_button_sound()
	OS.shell_open("https://www.instagram.com/juanchoprietom/")

func _on_art_pressed():
	play_button_sound()
	OS.shell_open("https://www.artstation.com/bastianbone18")

func _on_volver_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
