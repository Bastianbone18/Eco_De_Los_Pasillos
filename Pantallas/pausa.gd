extends CanvasLayer

@onready var boton_creditos = $ColorRect/VBoxContainer/BotonCreditos
@onready var boton_menu = $ColorRect/VBoxContainer/BotonMenu
@onready var slider_musica = $ColorRect/VBoxContainer/HBoxMusica/SliderMusicaFondo
@onready var slider_atmosfera = $ColorRect/VBoxContainer/HBoxSFX/SliderAtmosfera
@onready var fullscreen_button = $ColorRect/VBoxContainer/PantallaCompleta
@onready var button_sound_player = $AudioStreamPlayerBoton
@onready var root_ui: Control = $ColorRect

var _debounce := false

func _ready():


	# ✅ debe correr siempre (para poder abrir pausa)
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	boton_creditos.pressed.connect(_on_boton_creditos_pressed)
	boton_menu.pressed.connect(_on_boton_menu_pressed)
	slider_musica.value_changed.connect(_on_slider_musica_value_changed)
	slider_atmosfera.value_changed.connect(_on_slider_atmosfera_value_changed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)

	hide()
	root_ui.hide()

	slider_musica.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")))
	slider_atmosfera.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Atmosfera")))
	update_fullscreen_text()

	print("✅ PauseMenu listo. En árbol:", is_inside_tree(), " Acción 'pausa' existe?:", InputMap.has_action("pausa"))


func _process(_delta):
	# ✅ polling global: no depende de _input/_unhandled_input
	if Input.is_action_just_pressed("pausa") and not _debounce:
		_debounce = true
		await _toggle_pausa_async()
		await get_tree().create_timer(0.08).timeout
		_debounce = false


func _toggle_pausa_async() -> void:
	var opening := not visible

	if opening:
		show()
		root_ui.show()
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		boton_menu.grab_focus()
		print("Mouse mode (open):", Input.get_mouse_mode())
	else:
		# 1) despausar
		get_tree().paused = false

		# 2) ocultar UI
		hide()
		root_ui.hide()

		# 3) restaurar gameplay input (doble frame)
		get_viewport().gui_release_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		await get_tree().process_frame
		get_viewport().gui_release_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

		print("Mouse mode (close):", Input.get_mouse_mode())


func play_button_sound():
	if button_sound_player:
		button_sound_player.play()


func _on_boton_creditos_pressed():
	play_button_sound()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")


func _on_boton_menu_pressed():
	play_button_sound()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")


func _on_slider_musica_value_changed(value):
	var bus = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_volume_db(bus, linear2db(value))


func _on_slider_atmosfera_value_changed(value):
	var bus = AudioServer.get_bus_index("Atmosfera")
	AudioServer.set_bus_volume_db(bus, linear2db(value))


func update_fullscreen_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_button.text = "Ventana"
	else:
		fullscreen_button.text = "Completa"


func _on_fullscreen_button_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_fullscreen_text()


func linear2db(value):
	return 20 * log(value) / log(10) if value > 0 else -80


func db2linear(db):
	return pow(10, db / 20)
