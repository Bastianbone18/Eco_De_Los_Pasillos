extends Control

@onready var name_input = $LineEdit
@onready var message_label = $LabelError  # Asegúrate de que el nodo exista y tenga este nombre

var player_name = ""

func _ready():
	if name_input == null:
		print("Error: Nodo 'LineEdit' no encontrado.")
	if message_label == null:
		print("Error: Nodo 'LabelError' no encontrado.")
	$Button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed():
	player_name = name_input.text.strip_edges()  # Quita espacios extra
	
	if player_name == "":
		if message_label:
			message_label.text = "El nombre no puede estar vacío."  # Muestra mensaje de error
		else:
			print("Error: Nodo 'LabelError' no encontrado.")
		return
	
	if player_name.length() > 12:  # Valida longitud del nombre
		if message_label:
			message_label.text = "El nombre debe tener menos de 12 caracteres."
		else:
			print("Error: Nodo 'LabelError' no encontrado.")
		return
	
	# Si pasa las validaciones
	print("Nombre ingresado: %s" % player_name)
	save_player_name(player_name)
	get_tree().change_scene_to_file("res://Btas_y pruebas/Mundo_prueba.tscn")
	
	


func save_player_name(player_name_to_save):
	var save_data = {"player_name": player_name_to_save}
	var save_path = "user://save_file.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		print("Error al abrir el archivo para guardar.")
		return
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Nombre guardado correctamente.")
