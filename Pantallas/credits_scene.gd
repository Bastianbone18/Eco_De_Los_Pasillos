extends Control

@export var title_node_path: NodePath = ^"Titulo"
@export var thanks_node_path: NodePath

@onready var fondo: ColorRect = $Fondo
@onready var transition: ColorRect = $TransitionRect
@onready var talk: AudioStreamPlayer = $TalkSound
@onready var laugh: AudioStreamPlayer = $LaughSound

var titulo: Node = null
var texto_agradecimiento: Node = null

var type_speed: float = 0.03
var total_duration: float = 18.0
var finished: bool = false

var titulo_texto: String = ""
var agradecimiento_texto: String = ""


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	randomize()

	if fondo:
		fondo.color = Color("#120707")

	if talk:
		talk.volume_db = -6.0

	titulo = _resolver_nodo_titulo()
	texto_agradecimiento = _resolver_nodo_agradecimiento()

	if titulo == null:
		push_error("❌ No se encontró el nodo del título")
		_debug_imprimir_arbol()
		return

	if texto_agradecimiento == null:
		push_error("❌ No se encontró el nodo del texto de agradecimiento")
		_debug_imprimir_arbol()
		return

	titulo_texto = _get_node_text(titulo)
	agradecimiento_texto = _get_node_text(texto_agradecimiento)

	_set_node_text(titulo, "")
	_set_node_text(texto_agradecimiento, "")

	start_global_timer()
	start_intro_transition()


func _resolver_nodo_titulo() -> Node:
	if title_node_path != NodePath():
		var by_path := get_node_or_null(title_node_path)
		if by_path != null:
			return by_path

	var by_name := find_child("Titulo", true, false)
	if by_name != null:
		return by_name

	for node in _get_all_text_nodes(self):
		if node.name.to_lower().contains("titulo"):
			return node

	return null


func _resolver_nodo_agradecimiento() -> Node:
	if thanks_node_path != NodePath():
		var by_path := get_node_or_null(thanks_node_path)
		if by_path != null:
			return by_path

	var posibles_nombres := [
		"TextoAgradecimiento",
		"Agradecimiento",
		"Texto",
		"Mensaje",
		"ThanksText"
	]

	for nombre in posibles_nombres:
		var found := find_child(nombre, true, false)
		if found != null and found != titulo and _node_tiene_texto(found):
			return found

	for node in _get_all_text_nodes(self):
		if node != titulo:
			return node

	return null


func _get_all_text_nodes(root: Node) -> Array:
	var result: Array = []

	for child in root.get_children():
		if _node_tiene_texto(child):
			result.append(child)

		result.append_array(_get_all_text_nodes(child))

	return result


func _node_tiene_texto(node: Node) -> bool:
	if node == null:
		return false

	if node is Label:
		return true

	if node is RichTextLabel:
		return true

	return false


func _get_node_text(node: Node) -> String:
	if node == null:
		return ""

	var value = node.get("text")
	if value == null:
		return ""

	return str(value)


func _set_node_text(node: Node, value: String) -> void:
	if node == null:
		return

	node.set("text", value)


func start_intro_transition() -> void:
	var tiempo: float = 0.0
	var duracion: float = 4.0

	var rojo_inicio := Color("#660505")
	var negro_final := Color("#120707")

	if transition:
		transition.visible = true
		transition.color = rojo_inicio

	if laugh:
		laugh.play()

	while tiempo < duracion:
		var t := tiempo / duracion

		if transition:
			if tiempo < duracion - 0.5:
				transition.color = rojo_inicio.lerp(negro_final, t)
			else:
				var pulse := sin(Time.get_ticks_msec() * 0.02) * 0.08
				transition.color = Color(
					rojo_inicio.r + pulse,
					rojo_inicio.g,
					rojo_inicio.b,
					1.0
				)

		await get_tree().process_frame
		tiempo += get_process_delta_time()

	if transition:
		transition.visible = false

	await start_sequence()


func start_global_timer() -> void:
	await get_tree().create_timer(total_duration).timeout
	end_credits()


func start_sequence() -> void:
	await typewriter(titulo, titulo_texto)
	flash_label(titulo)

	await get_tree().create_timer(0.35).timeout

	await typewriter(texto_agradecimiento, agradecimiento_texto)


func typewriter(label_node: Node, full_text: String) -> void:
	if label_node == null:
		return

	_set_node_text(label_node, "")

	for i in range(full_text.length()):
		var current := _get_node_text(label_node)
		_set_node_text(label_node, current + full_text[i])

		if full_text[i] != " " and full_text[i] != "\n":
			if randi_range(0, 1) == 0:
				play_talk()

		await get_tree().create_timer(type_speed).timeout


func play_talk() -> void:
	if talk == null:
		return

	talk.pitch_scale = randf_range(0.95, 1.2)
	talk.play()


func flash_label(label_node: Node) -> void:
	if label_node == null:
		return

	var tween := create_tween()
	tween.tween_property(label_node, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.10)
	tween.tween_property(label_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func end_credits() -> void:
	if finished:
		return

	finished = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")


func _debug_imprimir_arbol() -> void:
	print("===== DEBUG NODOS CREDITOS =====")
	_print_tree_recursive(self, "")
	print("================================")


func _print_tree_recursive(node: Node, indent: String) -> void:
	print(indent + node.name + " [" + node.get_class() + "]")
	for child in node.get_children():
		_print_tree_recursive(child, indent + "  ")
