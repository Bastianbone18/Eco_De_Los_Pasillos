extends Control

@onready var exit_button = $VBoxContainer2/ExitButton
@onready var menu_button = $VBoxContainer2/MenuButton
@onready var message_label = $VBoxContainer/LabelMessage  # Asegúrate de que el label del mensaje exista
@onready var score_label = $VBoxContainer/LabelScore  # Asegúrate de que el label del score exista
@onready var click_audio = $AudioStreamPlayerClick  # Nodo para el sonido de clic
@onready var game_over_audio = $AudioStreamPlayerGameOver  # Nodo para el sonido de Game Over

func _ready():
	# Liberar el ratón para que sea visible en la pantalla de Game Over
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Reproducir el audio de Game Over en loop
	if game_over_audio:
		game_over_audio.play()

	# Conectar las señales de los botones
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	# Mostrar el mensaje de Game Over y los datos del jugador
	if message_label:
		message_label.text = "Tu historia termina aquí " + GameData.player_name
	if score_label:
		score_label.text = "Tiempo sobreviviendo: " + str(GameData.survival_time) + " segundos"

# Función para manejar el botón de salir
func _on_exit_pressed():
	_play_click_sound()
	get_tree().quit()

# Función para manejar el botón de volver al menú
func _on_menu_pressed():
	_play_click_sound()
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")  # Cambiar a la escena del menú

# Función para reproducir el sonido de clic
func _play_click_sound():
	if click_audio:
		click_audio.play()
		
