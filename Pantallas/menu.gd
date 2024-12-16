extends Control

# Referencias a los controles y al AudioStreamPlayer
@onready var slider_musica_menu = $Volumen/SliderMusicaMenu  # Ruta del slider de volumen
@onready var button_sound_player = $AudioStreamPlayerBoton  # Nodo para el sonido de los botones

# Configuración inicial

func _ready():
	# Configurar el Slider
	slider_musica_menu.min_value = 0  # Valor mínimo
	slider_musica_menu.max_value = 100  # Valor máximo
	slider_musica_menu.step = 0.1  # Precisión de 0.1 para el movimiento del slider
	
	# Conectar el slider con la función que ajusta el volumen
	slider_musica_menu.connect("value_changed", Callable(self, "_on_slider_musica_menu_changed"))
	
	# Configura el slider al valor actual del bus "Menu"
	var bus_index = AudioServer.get_bus_index("Menu")  # Obtener el índice del bus "Menu"
	var volumen_actual = AudioServer.get_bus_volume_db(bus_index)  # Obtener el volumen en decibelios
	slider_musica_menu.value = db_to_slider_value(volumen_actual)  # Ajustar el slider al volumen actual

# Función para ajustar el volumen del bus "Menu"
func _on_slider_musica_menu_changed(value):
	var bus_index = AudioServer.get_bus_index("Menu")  # Obtener el índice del bus "Menu"
	var volumen_db = slider_value_to_db(value)  # Convertir el valor del slider a decibelios
	AudioServer.set_bus_volume_db(bus_index, volumen_db)  # Ajustar el volumen del bus

# Convertir de decibelios a valor del slider
func db_to_slider_value(db):
	return lerp(0.0, float(slider_musica_menu.max_value), (db + 80) / 80)

# Convertir valor del slider a decibelios
func slider_value_to_db(value):
	return lerp(-80.0, 0.0, float(value) / float(slider_musica_menu.max_value))

# Función para reproducir sonido al presionar el botón
func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

# Función para cuando el botón "Play" es presionado
func _on_play_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/Register.tscn")

# Función para cuando el botón "Options" es presionado
func _on_options_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")

# Función para cuando el botón "Exit" es presionado
func _on_exit_pressed():
	play_button_sound()
	get_tree().quit()

