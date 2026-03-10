extends Control
# Pantalla donde el jugador ingresa su nombre.

@onready var name_input: LineEdit = $LineEdit
@onready var message_label: Label = $LabelError
@onready var click_audio: AudioStreamPlayer = $AudioStreamPlayerClick

func _ready() -> void:
	# Apaga música de menú al entrar a Register
	MusicManager.play_menu()

	if name_input == null:
		print("Error: Nodo 'LineEdit' no encontrado.")
	if message_label == null:
		print("Error: Nodo 'LabelError' no encontrado.")

	$Button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed() -> void:
	var player_name: String = name_input.text.strip_edges()  # ← tipo explícito

	if player_name == "":
		if message_label:
			message_label.text = "El nombre no puede estar vacío."
		return

	if player_name.length() > 12:
		if message_label:
			message_label.text = "El nombre debe tener menos de 12 caracteres."
		return

	GameData.player_name = player_name
	GameData.survival_time = 0.0
	print("Nombre ingresado: %s" % player_name)

	get_tree().change_scene_to_file("res://Pantallas/MenuSlots.tscn")

func _play_click_sound() -> void:
	if click_audio:
		click_audio.play()
