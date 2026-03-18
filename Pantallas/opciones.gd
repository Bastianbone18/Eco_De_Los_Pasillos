extends Control

# ----------------------
# NODOS
# ----------------------
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton   # hover
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick   # click (debes agregarlo)
@onready var pantalla_toggle: Button = $PantallaToggle
@onready var mensaje_label: Label = $MensajeLabel

# ----------------------
# SONIDOS
# ----------------------
var hover_sound = preload("res://Musica y sonidos/Sonidos/Click_linterna.ogg")
var click_sound = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")

const BUS_NAME: String = "Menu"   # mismo bus que en el menú

# ----------------------
# READY
# ----------------------
func _ready() -> void:
	MusicManager.play_menu()
	actualizar_mensaje()

	# Configurar buses de audio
	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	# Conectar hover a todos los botones (deben estar en el grupo "botones")
	_connect_hover_to_buttons()

	# Conectar señal del toggle de pantalla
	pantalla_toggle.pressed.connect(_on_pantalla_toggle_pressed)
	_actualizar_icono_pantalla()

	# Escuchar cambios externos del modo de ventana
	if not DisplaySettings.window_mode_changed.is_connected(_on_window_mode_changed):
		DisplaySettings.window_mode_changed.connect(_on_window_mode_changed)

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

# ----------------------
# FUNCIONES DE LOS BOTONES (ya conectadas desde el editor)
# ----------------------
func _on_creditos_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

func _on_back_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

func _on_pantalla_toggle_pressed() -> void:
	play_click_sound()
	DisplaySettings.toggle_fullscreen()
	_actualizar_icono_pantalla()

# ----------------------
# ACTUALIZACIÓN DE MENSAJE ALEATORIO
# ----------------------
func actualizar_mensaje() -> void:
	var mensajes = [
		"Las voces susurran desde el abismo, pero ¿quién osa responder?",
		"Lo que está roto no siempre busca ser reparado...",
		"Tu sombra se alarga en la oscuridad...",
		"El camino recto es el más fácil... y el más engañoso.",
		"La casa desierta se llenará de sombras,\n y allí morarán los espectros de la soledad.",
		"La ciudad yace desierta;\n sus moradores son solo sombras."
	]
	mensaje_label.text = mensajes.pick_random()

# ----------------------
# MANEJO DE PANTALLA COMPLETA / VENTANA
# ----------------------
func _on_window_mode_changed(_is_fullscreen: bool) -> void:
	_actualizar_icono_pantalla()

func _actualizar_icono_pantalla() -> void:
	if DisplaySettings.is_fullscreen():
		pantalla_toggle.text = "▢"   # cambiar a ventana
	else:
		pantalla_toggle.text = "□"   # cambiar a completa
