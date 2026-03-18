extends Control

# ----------------------
# NODOS
# ----------------------
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton   # hover (debes agregarlo)
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick   # click (ya existe)
@onready var name_input: LineEdit = $LineEdit
@onready var message_label: Label = $LabelError

# ----------------------
# SONIDOS
# ----------------------
var hover_sound = preload("res://Musica y sonidos/Sonidos/Click_linterna.ogg")
var click_sound = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")

const BUS_NAME: String = "Menu"   # mismo bus que en el menú principal

# ----------------------
# READY
# ----------------------
func _ready() -> void:
	# Asegurar música de menú (no reinicia si ya suena)
	MusicManager.play_menu()

	# Configurar buses de audio
	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	# Conectar hover a todos los botones (deben estar en el grupo "botones")
	_connect_hover_to_buttons()

	# Conectar señal pressed del botón confirmar
	$Button.pressed.connect(_on_confirm_pressed)

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
# BOTÓN CONFIRMAR
# ----------------------
func _on_confirm_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout

	var player_name: String = name_input.text.strip_edges()

	if player_name == "":
		if message_label:
			message_label.text = "Ningún nombre ha sido declarado."
		return

	if player_name.length() > 12:
		if message_label:
			message_label.text = "El nombre no debe superar los 12 caracteres."
		return

	GameData.player_name = player_name
	GameData.survival_time = 0.0
	print("Nombre ingresado: %s" % player_name)

	get_tree().change_scene_to_file("res://Pantallas/MenuSlots.tscn")
