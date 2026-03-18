extends CanvasLayer

# ----------------------
# NODOS
# ----------------------
@onready var boton_creditos = $ColorRect/VBoxContainer/BotonCreditos
@onready var boton_menu = $ColorRect/VBoxContainer/BotonMenu
@onready var slider_musica = $ColorRect/VBoxContainer/HBoxMusica/SliderMusicaFondo
@onready var slider_atmosfera = $ColorRect/VBoxContainer/HBoxSFX/SliderAtmosfera
@onready var fullscreen_button = $ColorRect/VBoxContainer/PantallaCompleta
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton   # hover (debe existir)
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick   # click (debes agregarlo)
@onready var root_ui: Control = $ColorRect

# ----------------------
# SONIDOS
# ----------------------
var hover_sound = preload("res://Musica y sonidos/Sonidos/Click_linterna.ogg")
var click_sound = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")

const BUS_NAME: String = "Atmosfera"   # Bus controlado por el slider de atmósfera
var _debounce := false
var _pause_tween: Tween

var music_bus := -1
var music_lowpass: AudioEffectLowPassFilter

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	# Configurar buses de audio
	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	# Conectar hover a todos los botones (deben estar en el grupo "botones")
	_connect_hover_to_buttons()

	# Conectar señales de botones y sliders
	boton_creditos.pressed.connect(_on_boton_creditos_pressed)
	boton_menu.pressed.connect(_on_boton_menu_pressed)
	slider_musica.value_changed.connect(_on_slider_musica_value_changed)
	slider_atmosfera.value_changed.connect(_on_slider_atmosfera_value_changed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)

	hide()
	root_ui.hide()

	music_bus = AudioServer.get_bus_index("Musica")

	# Buscar LowPass del bus
	var fx_count = AudioServer.get_bus_effect_count(music_bus)
	for i in range(fx_count):
		var fx = AudioServer.get_bus_effect(music_bus, i)
		if fx is AudioEffectLowPassFilter:
			music_lowpass = fx

	slider_musica.value = db2linear(AudioServer.get_bus_volume_db(music_bus))
	slider_atmosfera.value = db2linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Atmosfera")))

	update_fullscreen_text()

	print("✅ PauseMenu listo")

# ----------------------
# CONEXIÓN DE HOVER A BOTONES
# ----------------------
func _connect_hover_to_buttons() -> void:
	var botones = get_tree().get_nodes_in_group("botones")
	for button in botones:
		if not button.is_connected("mouse_entered", Callable(self, "_on_button_hover")):
			button.mouse_entered.connect(_on_button_hover)

# ----------------------
# HOVER
# ----------------------
func _on_button_hover() -> void:
	if hover_player:
		hover_player.stop()
		hover_player.stream = hover_sound
		hover_player.pitch_scale = randf_range(0.95, 1.05)
		hover_player.play()

# ----------------------
# CLICK (llamada desde cada botón)
# ----------------------
func play_click_sound() -> void:
	if click_player:
		click_player.stop()
		click_player.stream = click_sound
		click_player.pitch_scale = randf_range(0.95, 1.05)
		click_player.play()

func _process(_delta):
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
		await _apply_pause_music_effect()
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		boton_menu.grab_focus()
	else:
		get_tree().paused = false
		await _restore_music_from_pause()
		hide()
		root_ui.hide()
		get_viewport().gui_release_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		await get_tree().process_frame
		get_viewport().gui_release_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

func _apply_pause_music_effect():
	if music_bus == -1:
		return
	if _pause_tween and _pause_tween.is_running():
		_pause_tween.kill()
	var current_db = AudioServer.get_bus_volume_db(music_bus)
	_pause_tween = create_tween()
	_pause_tween.set_parallel(true)
	_pause_tween.tween_method(
		func(v): AudioServer.set_bus_volume_db(music_bus, v),
		current_db,
		current_db - 12,
		0.4
	)
	if music_lowpass:
		_pause_tween.tween_property(
			music_lowpass,
			"cutoff_hz",
			900,
			0.4
		)
	await _pause_tween.finished

func _restore_music_from_pause():
	if music_bus == -1:
		return
	if _pause_tween and _pause_tween.is_running():
		_pause_tween.kill()
	var current_db = AudioServer.get_bus_volume_db(music_bus)
	_pause_tween = create_tween()
	_pause_tween.set_parallel(true)
	_pause_tween.tween_method(
		func(v): AudioServer.set_bus_volume_db(music_bus, v),
		current_db,
		current_db + 12,
		0.4
	)
	if music_lowpass:
		_pause_tween.tween_property(
			music_lowpass,
			"cutoff_hz",
			20000,
			0.4
		)
	await _pause_tween.finished

func _on_boton_creditos_pressed():
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

func _on_boton_menu_pressed():
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

func _on_slider_musica_value_changed(value):
	value = clamp(value, 0.0001, 1.0)
	var bus = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_volume_db(bus, linear2db(value))

func _on_slider_atmosfera_value_changed(value):
	value = clamp(value, 0.0001, 1.0)
	var bus = AudioServer.get_bus_index("Atmosfera")
	AudioServer.set_bus_volume_db(bus, linear2db(value))

func update_fullscreen_text():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_button.text = "Modo ventana"
	else:
		fullscreen_button.text = "Pantalla completa"

func _on_fullscreen_button_pressed():
	play_click_sound()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_fullscreen_text()

func linear2db(value):
	return 20 * log(value) / log(10)

func db2linear(db):
	return pow(10, db / 20)
