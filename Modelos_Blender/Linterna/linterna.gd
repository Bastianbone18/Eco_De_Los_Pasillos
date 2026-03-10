extends Node3D

# ==================================================
# ------------------ REFERENCIAS -------------------
# ==================================================
@onready var mesh: MeshInstance3D = $Linterna
@onready var luz: OmniLight3D = $OmniLight3D
@onready var area: Area3D = $Area3D

# ==================================================
# ------------------ ESTADO ------------------------
# ==================================================
var player_inside: bool = false
var picked_up: bool = false
var puntero_ui: Node = null

# Animación 2D de linterna
var linterna_anim_instance: CanvasLayer = null

# ==================================================
# -------------------- READY -----------------------
# ==================================================
func _ready() -> void:
	# ✅ Si ya tienes linterna por GameData (por save/retry), NO debe existir aquí
	if GameData.has_flashlight:
		queue_free()
		return

	area.body_entered.connect(_on_area_entered)
	area.body_exited.connect(_on_area_exited)

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if not puntero_ui:
		push_warning("⚠️ No se encontró CenterContainer para el puntero")

# ==================================================
# ------------------ AREA EVENTS -------------------
# ==================================================
func _on_area_entered(body: Node) -> void:
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
# ------------------ PROCESO -----------------------
# ==================================================
func _process(_delta: float) -> void:
	if not player_inside or picked_up:
		return

	if Input.is_action_just_pressed("action_use"):
		_recoger_linterna()

# ==================================================
# ------------------ PICKUP ------------------------
# ==================================================
func _recoger_linterna() -> void:
	var player := get_tree().get_current_scene().get_node_or_null("Player")
	if not player:
		return

	picked_up = true

	# Estado del jugador (runtime)
	if "has_flashlight" in player:
		player.has_flashlight = true

	# ✅ Estado persistente
	GameData.has_flashlight = true
	GameData.flashlight_on = false

	# ✅ CLAVE: si ya la recogiste, NO tiene sentido repetir “Buscar_linterna”
	GameData.buscar_linterna_done = true

	print("[Linterna] Pickup OK -> has_flashlight=true | buscar_linterna_done=true")

	# ✅ GUARDAR ya mismo (para que Reintentar no te quite la linterna)
	if SaveManager and SaveManager.has_method("save_from_gamedata"):
		SaveManager.save_from_gamedata(GameData)

	# UI
	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	# Ocultar objeto 3D
	if mesh:
		mesh.visible = false
	if luz:
		luz.visible = false
	if area:
		area.monitoring = false

	await get_tree().create_timer(0.4).timeout
	mostrar_dialogo_linterna()

# ==================================================
# ------------------ DIÁLOGO -----------------------
# ==================================================
func mostrar_dialogo_linterna() -> void:
	var dialogue_path := "res://Dialogos/linterna_encontrada.dialogue"
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el recurso del diálogo de la linterna")
		_finish_and_cleanup()
		return

	var dialogue_resource := load(dialogue_path)
	var balloon_scene := preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon)

	# ✅ Conectar fin
	if balloon.has_signal("dialogue_finished"):
		balloon.dialogue_finished.connect(_on_dialogo_terminado)
	else:
		# fallback por si tu balloon usa DialogueManager.dialogue_ended
		_wait_dialogue_ended(dialogue_resource)

	# Iniciar diálogo
	if balloon.has_method("start"):
		balloon.start(dialogue_resource, "linterna_encontrada")
	else:
		push_error("❌ Balloon no tiene start()")
		_finish_and_cleanup()
		return

	# Animación 2D
	var anim_scene := preload("res://PNG_OBJETOS/LintAnimacion.tscn")
	linterna_anim_instance = anim_scene.instantiate()
	get_tree().get_current_scene().add_child(linterna_anim_instance)

	var anim_sprite := linterna_anim_instance.get_node_or_null("AnimLinterna")
	if anim_sprite is AnimatedSprite2D:
		(anim_sprite as AnimatedSprite2D).play("Mostrar")
	else:
		push_warning("⚠️ No se encontró 'AnimLinterna' en la escena")

func _wait_dialogue_ended(dialogue_res: Resource) -> void:
	await get_tree().process_frame
	while true:
		var ended_res: Resource = await DialogueManager.dialogue_ended
		if ended_res == dialogue_res:
			_on_dialogo_terminado()
			return

# ==================================================
# ------------------ FINAL -------------------------
# ==================================================
func _on_dialogo_terminado() -> void:
	print("✅ Diálogo de linterna finalizado")
	_finish_and_cleanup()

func _finish_and_cleanup() -> void:
	# ✅ Guardar otra vez (por seguridad)
	if SaveManager and SaveManager.has_method("save_from_gamedata"):
		SaveManager.save_from_gamedata(GameData)

	# Limpiar anim 2D
	if linterna_anim_instance and linterna_anim_instance.is_inside_tree():
		linterna_anim_instance.queue_free()
		linterna_anim_instance = null

	# Eliminar pickup
	queue_free()
