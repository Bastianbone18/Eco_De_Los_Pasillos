extends Control

# ----------------------
# NODOS
# ----------------------
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton   # hover (debe existir)
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick   # click (debes agregarlo)

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
	# Asegura música de menú sonando (no reinicia si ya suena)
	MusicManager.play_menu()

	# Configurar buses de audio
	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	# Conectar hover a todos los botones (deben estar en el grupo "botones")
	_connect_hover_to_buttons()

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
func _on_tiktok_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	OS.shell_open("https://github.com/Bastianbone18/Eco_De_Los_Pasillos")

func _on_ig_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	OS.shell_open("https://github.com/datanilo")

func _on_art_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	OS.shell_open("https://www.artstation.com/bastianbone18")

func _on_volver_pressed() -> void:
	play_click_sound()
	await get_tree().create_timer(0.05).timeout
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
