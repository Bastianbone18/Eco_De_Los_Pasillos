extends Node3D

# ==================================================
# ------------------ REFERENCIAS -------------------
# ==================================================
@onready var mesh: Node3D = $defaultMaterial
@onready var area: Area3D = $Area3D

# Animación 2D (CanvasLayer con AnimatedSprite2D)
@export var hoja_anim_scene: PackedScene = preload("res://PNG_OBJETOS/HojaAnimaciontscn.tscn")

# Diálogo
@export var dialogue_path: String = "res://Dialogos/hoja_encontrada.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

# ✅ INICIO DEL RETO (Luces)
@export var start_guiding_lights_on_finish: bool = true
@export var start_challenge_delay: float = 1.5

# ==================================================
# ------------------ ESTADO ------------------------
# ==================================================
var player_inside := false
var used := false
var puntero_ui: Node = null

var hoja_anim_instance: CanvasLayer = null
var balloon_instance: Node = null

var _challenge_started := false
var _busy := false

# ==================================================
# -------------------- READY -----------------------
# ==================================================
func _ready() -> void:
	# Si ya se interactuó con la hoja en ese slot, este objeto NO aparece
	if GameData.hoja_encontrada_done:
		queue_free()
		return

	area.body_entered.connect(_on_area_entered)
	area.body_exited.connect(_on_area_exited)

	# Puntero UI
	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if not puntero_ui:
		push_warning("⚠️ No se encontró CenterContainer para el puntero")

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
# ------------------ PROCESO -----------------------
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

	# ✅ Apaga el área para que no se repita
	area.monitoring = false
	area.monitorable = false

	# Ocultar puntero
	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	# Ocultar modelo 3D
	if mesh and "visible" in mesh:
		mesh.visible = false

	# Mostrar animación 2D
	_mostrar_animacion_hoja()

	# Iniciar diálogo
	_iniciar_dialogo()

# ==================================================
# ------------------ ANIMACIÓN 2D ------------------
# ==================================================
func _mostrar_animacion_hoja() -> void:
	if not hoja_anim_scene:
		push_error("❌ hoja_anim_scene es null")
		return

	hoja_anim_instance = hoja_anim_scene.instantiate()
	get_tree().get_current_scene().add_child(hoja_anim_instance)

	var anim := hoja_anim_instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not anim:
		push_error("❌ No se encontró AnimatedSprite2D dentro de HojaAnimaciontscn.tscn")
		return

	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	anim.speed_scale = 1.0
	anim.frame = 0

	if anim.sprite_frames and anim.sprite_frames.has_animation("Mostrar"):
		anim.play("Mostrar")
	else:
		anim.play()

# ==================================================
# ------------------ DIÁLOGO -----------------------
# ==================================================
func _iniciar_dialogo() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_on_dialogo_hoja_terminado()
		return

	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_on_dialogo_hoja_terminado()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	# Conectar final del diálogo
	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogo_hoja_terminado):
			balloon_instance.dialogue_finished.connect(_on_dialogo_hoja_terminado)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_on_dialogo_hoja_terminado()
		return

	# Iniciar diálogo en el nodo hoja_encontrada
	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, "hoja_encontrada")
	else:
		push_error("❌ balloon_instance no tiene método start()")
		_on_dialogo_hoja_terminado()

# ==================================================
# ------------------ FINAL -------------------------
# ==================================================
func _on_dialogo_hoja_terminado() -> void:
	# ✅ Flag definitivo
	GameData.hoja_encontrada_done = true

	# Cerrar animación 2D
	if hoja_anim_instance and hoja_anim_instance.is_inside_tree():
		hoja_anim_instance.queue_free()
		hoja_anim_instance = null

	# Cerrar balloon
	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
		balloon_instance = null

	# ✅ Iniciar reto y SOLO DESPUÉS borrar el nodo (esto arregla tu problema)
	if start_guiding_lights_on_finish:
		await _start_guiding_lights_after_delay()

	# Ahora sí, borrar hoja
	queue_free()

func _start_guiding_lights_after_delay() -> void:
	if _challenge_started:
		return
	_challenge_started = true

	print("[Hoja] Iniciando reto en ", start_challenge_delay, "s...")
	await get_tree().create_timer(start_challenge_delay).timeout

	print("[Hoja] START CHALLENGE -> call_group(light_manager, start_challenge)")
	get_tree().call_group("light_manager", "start_challenge")
