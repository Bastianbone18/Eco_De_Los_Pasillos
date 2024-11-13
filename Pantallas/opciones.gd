extends Control

# Referencias al AudioStreamPlayer para los botones
@onready var button_sound_player = $AudioStreamPlayerBoton  # Nodo para el sonido de los botones

# Configuración inicial
func _ready():
	# Puedes realizar otras configuraciones aquí si es necesario
	pass

# Función para reproducir sonido al presionar el botón
func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

# Función para cuando el botón "Creditos" es presionado
func _on_creditos_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

# Función para cuando el botón "Volver" es presionado
func _on_back_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")
