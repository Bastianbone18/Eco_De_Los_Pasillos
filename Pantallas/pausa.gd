extends CanvasLayer

# Referencias a los botones, sliders y AudioStreamPlayer para los sonidos de los botones
@onready var boton_creditos = $ColorRect/VBoxContainer/BotonCreditos
@onready var boton_menu = $ColorRect/VBoxContainer/BotonMenu
@onready var slider_musica = $ColorRect/VBoxContainer/SliderMusicaFondo
@onready var slider_atmosfera = $ColorRect/VBoxContainer/SliderAtmosfera
@onready var button_sound_player = $AudioStreamPlayerBoton  # Reproductor de sonido para botones

# Configuración inicial
func _ready():
	# Verificar que los botones, sliders y el AudioStreamPlayer existan antes de conectarlos
	if boton_creditos and boton_menu and slider_musica and slider_atmosfera and button_sound_player:
		# Conectar señales de botones a funciones usando Callable
		boton_creditos.connect("pressed", Callable(self, "_on_boton_creditos_pressed"))
		boton_menu.connect("pressed", Callable(self, "_on_boton_menu_pressed"))
		# Conectar los sliders a las funciones de ajuste de volumen
		slider_musica.connect("value_changed", Callable(self, "_on_slider_musica_value_changed"))
		slider_atmosfera.connect("value_changed", Callable(self, "_on_slider_atmosfera_value_changed"))
	else:
		print("Error: uno o más nodos no están disponibles.")

	visible = false  # Ocultar menú al inicio

	# Establecer valores iniciales de los sliders
	slider_musica.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")))
	slider_atmosfera.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Atmosfera")))

# Función para reproducir el sonido del botón
func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

# Mostrar u ocultar el menú de pausa
func toggle_pausa():
	visible = not visible
	get_tree().paused = visible
	if visible:
		mostrar_cursor()
	else:
		ocultar_cursor()

# Función para el botón "Créditos"
func _on_boton_creditos_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	print("Mostrar créditos")
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

# Función para el botón "Menú"
func _on_boton_menu_pressed():
	play_button_sound()  # Reproduce el sonido al hacer clic
	print("Regresar al menú principal")
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

# Muestra el cursor
func mostrar_cursor():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Oculta el cursor
func ocultar_cursor():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Detectar entrada de la tecla de pausa
func _input(event):
	if event.is_action_pressed("pausa"):
		toggle_pausa()

# Función para convertir valor lineal a decibelios
func linear2db(value):
	const LOG10 = 2.302585092994046  # ln(10) para el cambio de base
	return 20 * log(value) / LOG10 if value > 0 else -80  # Ajusta el valor mínimo a -80 dB para silencio total

# Función para convertir de decibelios a valor lineal
func db2linear(db):
	return pow(10, db / 20)

# Funciones de ajuste de volumen para los sliders
func _on_slider_musica_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_volume_db(bus_index, linear2db(value))

func _on_slider_atmosfera_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Atmosfera")
	AudioServer.set_bus_volume_db(bus_index, linear2db(value))
