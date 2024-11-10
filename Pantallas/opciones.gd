extends Control

# Referencias a los controles y al AudioStreamPlayer
@onready var slider_musica_menu = $VBoxContainer/SliderMusicaMenu

@onready var audio_menu = get_node("/root/AudioServer/Bus/AudioStreamPlayerMenu")  # Cambia la ruta si es necesario

# Configuración inicial
func _ready():
	# Conectar el slider con la función que ajusta el volumen
	slider_musica_menu.connect("value_changed", Callable(self, "_on_slider_musica_menu_changed"))
	
	# Configura el slider al valor actual del bus (puedes ajustar esto según necesites)
	var volumen_actual = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Menu"))
	slider_musica_menu.value = db_to_slider_value(volumen_actual)

# Función para ajustar el volumen del bus "Menu"
func _on_slider_musica_menu_changed(value):
	# Convertir el valor del slider a decibelios y aplicar al bus
	var volumen_db = slider_value_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu"), volumen_db)

# Convertir de decibelios a valor del slider
func db_to_slider_value(db):
	# Este valor es logarítmico, para que el slider tenga un rango adecuado
	return lerp(0.0, float(slider_musica_menu.max_value), (db + 80) / 80)

# Convertir valor del slider a decibelios
func slider_value_to_db(value):
	# Este valor es logarítmico, para que el slider tenga un rango adecuado
	return lerp(-80.0, 0.0, float(value) / float(slider_musica_menu.max_value))
	
# Función para los botones de la escena
func _on_creditos_pressed():
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")
