extends CanvasLayer

# Referencias a los botones, sliders y AudioStreamPlayer para los sonidos de los botones
@onready var boton_creditos = $ColorRect/VBoxContainer/BotonCreditos
@onready var boton_menu = $ColorRect/VBoxContainer/BotonMenu
@onready var slider_musica = $ColorRect/VBoxContainer/SliderMusicaFondo
@onready var slider_atmosfera = $ColorRect/VBoxContainer/SliderAtmosfera
@onready var button_sound_player = $AudioStreamPlayerBoton  # Reproductor de sonido para botones

func _ready():
	# Conectar señales de botones a funciones usando Callable
	boton_creditos.connect("pressed", Callable(self, "_on_boton_creditos_pressed"))
	boton_menu.connect("pressed", Callable(self, "_on_boton_menu_pressed"))
	slider_musica.connect("value_changed", Callable(self, "_on_slider_musica_value_changed"))
	slider_atmosfera.connect("value_changed", Callable(self, "_on_slider_atmosfera_value_changed"))

	visible = false  # Ocultar menú al inicio

	# Establecer valores iniciales de los sliders
	slider_musica.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")))
	slider_atmosfera.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Atmosfera")))

func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

func toggle_pausa():
	visible = not visible
	get_tree().paused = visible
	if visible:
		mostrar_cursor()
	else:
		ocultar_cursor()

func _on_boton_creditos_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

func _on_boton_menu_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

func mostrar_cursor():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func ocultar_cursor():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event.is_action_pressed("pausa"):
		toggle_pausa()

func linear2db(value):
	const LOG10 = 2.302585092994046
	return 20 * log(value) / LOG10 if value > 0 else -80

func db2linear(db):
	return pow(10, db / 20)

func _on_slider_musica_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_volume_db(bus_index, linear2db(value))

func _on_slider_atmosfera_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Atmosfera")
	AudioServer.set_bus_volume_db(bus_index, linear2db(value))
