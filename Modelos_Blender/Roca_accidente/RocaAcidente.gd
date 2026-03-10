extends Node3D

# ==================================================
# ------------------ REFERENCIAS -------------------
# ==================================================
@onready var area: Area3D = $Area3D

# Diálogo
@export var dialogue_path: String = "res://Dialogos/Roca_accidente.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

# Nombre del nodo dentro del .dialogue
const DIALOGUE_NODE := "roca_accidente"

# ==================================================
# ------------------ ESTADO ------------------------
# ==================================================
var player_inside := false
var used := false
var _busy := false

var puntero_ui: Node = null
var balloon_instance: Node = null

# ==================================================
# -------------------- READY -----------------------
# ==================================================
func _ready() -> void:
	# La roca SIEMPRE se queda, pero si ya se examinó, no vuelve a hablar.
	used = GameData.roca_accidente_done

	area.body_entered.connect(_on_area_entered)
	area.body_exited.connect(_on_area_exited)

	# Retícula / puntero (CenterContainer con Reticula.gd)
	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if not puntero_ui:
		push_warning("⚠️ No se encontró CenterContainer para el puntero")

	# Si ya está usado, apaga el Area3D para que no moleste
	if used:
		area.monitoring = false
		area.monitorable = false

# ==================================================
# ------------------ AREA EVENTS -------------------
# ==================================================
func _on_area_entered(body: Node) -> void:
	if used or _busy:
		return

	if body.is_in_group("Player"):
		player_inside = true
		if puntero_ui and puntero_ui.has_method("mostrar_puntero"):
			puntero_ui.mostrar_puntero()

func _on_area_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_inside = false
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()

# ==================================================
# ------------------ INPUT -------------------------
# ==================================================
func _process(_delta: float) -> void:
	if used or _busy or not player_inside:
		return

	if Input.is_action_just_pressed("action_use"):
		_interactuar()

# ==================================================
# ------------------ INTERACT ----------------------
# ==================================================
func _interactuar() -> void:
	if used or _busy:
		return

	_busy = true
	used = true

	# Apaga el área para evitar spam (la roca y su colisión se quedan)
	area.monitoring = false
	area.monitorable = false

	# Oculta puntero
	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	_iniciar_dialogo()

# ==================================================
# ------------------ DIÁLOGO -----------------------
# ==================================================
func _iniciar_dialogo() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_finalizar()
		return

	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_finalizar()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	# Conectar final del diálogo
	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogo_terminado):
			balloon_instance.dialogue_finished.connect(_on_dialogo_terminado)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_finalizar()
		return

	# Iniciar diálogo
	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, DIALOGUE_NODE)
	else:
		push_error("❌ balloon_instance no tiene método start()")
		_finalizar()

func _on_dialogo_terminado() -> void:
	# ✅ Flag propio de la roca
	GameData.roca_accidente_done = true
	_finalizar()

func _finalizar() -> void:
	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
		balloon_instance = null

	_busy = false
