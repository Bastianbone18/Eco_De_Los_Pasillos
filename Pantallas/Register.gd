extends Control

@onready var name_input = $LineEdit
@onready var message_label = $LabelError  # Asegúrate de que el nodo exista y tenga este nombre
@onready var click_audio = $AudioStreamPlayerClick  # Nodo para el sonido de clic

func _ready():
	if name_input == null:
		print("Error: Nodo 'LineEdit' no encontrado.")
	if message_label == null:
		print("Error: Nodo 'LabelError' no encontrado.")
	$Button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed():
	var player_name = name_input.text.strip_edges()  # Quita espacios extra

	# Validaciones del nombre
	if player_name == "":
		if message_label:
			message_label.text = "El nombre no puede estar vacío."  # Muestra mensaje de error
		return
	if player_name.length() > 12:
		if message_label:
			message_label.text = "El nombre debe tener menos de 12 caracteres."
		return

	# Guardar el nombre del jugador en el singleton
	GameData.player_name = player_name
	GameData.survival_time = 0.0  # Reinicia el tiempo sobrevivido al iniciar el juego

	print("Nombre ingresado: %s" % player_name)
	get_tree().change_scene_to_file("res://Btas_y pruebas/Mundo_prueba.tscn")
	
	  # Cambia a la escena principal
func _play_click_sound():
	if click_audio:
		click_audio.play()
