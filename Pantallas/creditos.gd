extends Control

# Referencia al AudioStreamPlayer para los sonidos de los botones
@onready var button_sound_player = $AudioStreamPlayerBoton  # Cambia el nombre si el nodo tiene otro nombre

func _ready():
	# Cargar el sonido del botón si no está configurado
	if button_sound_player:
		button_sound_player.stream = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")  # Asegúrate de que la ruta sea correcta

# Función para reproducir el sonido del botón
func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

# Funciones de los botones en los créditos
func _on_tiktok_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	OS.shell_open("https://www.tiktok.com/@bastianbone18")

func _on_ig_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	OS.shell_open("https://www.instagram.com/juanchoprietom/")

func _on_art_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	OS.shell_open("https://www.artstation.com/bastianbone18")

func _on_volver_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
