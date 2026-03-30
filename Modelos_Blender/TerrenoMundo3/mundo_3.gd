extends Node

@export var first_checkpoint_id: String = "world3_start"

@export var fake_shadow_scene: PackedScene
@export var test_fake_spawn_enabled: bool = false

@export var max_infestation_level: int = 3
@export var infestation_visual_bonus: float = 0.18

@export var fake_spawn_radius_min: float = 2.8
@export var fake_spawn_radius_max: float = 5.0
@export var fake_spawn_height_offset: float = -0.6

@export var debug_enabled: bool = true
@export var debug_print_once_only: bool = true

# =========================
# INTRO MUNDO 3
# =========================
@export var intro_anim_name: String = "DespertarSusto"
@export var intro_dialogue_path: String = "res://Dialogos/Intro_Mundo3.dialogue"
@export var intro_dialogue_key: String = "intro_mundo3"

# Presión por pedestal
@export var pedestal_pressure_duration: float = 8.0
@export var pedestal_spawn_min: float = 4.0
@export var pedestal_spawn_max: float = 7.0
@export var normal_spawn_min: float = 12.0
@export var normal_spawn_max: float = 20.0
@export var infestation_spawn_factor: float = 0.6
@export var absolute_spawn_min: float = 1.5
@export var absolute_spawn_max_floor: float = 2.5

# Tramo final más pesado por progreso
@export var final_phase_wait_bonus_step: float = 0.7
@export var final_phase_close_bonus_step: float = 0.35
@export var final_phase_visual_bonus_step: float = 0.06

# Distancias del Padre
@export var padre_normal_spawn_min_distance: float = 5.5
@export var padre_normal_spawn_max_distance: float = 7.0
@export var padre_pressure_spawn_min_distance: float = 4.8
@export var padre_pressure_spawn_max_distance: float = 6.0
@export var padre_absolute_min_distance: float = 3.0
@export var padre_absolute_max_floor: float = 4.0

# Ajuste vertical actual del Padre
@export var padre_spawn_y_offset: float = -1.15

@onready var padre: PadreEntity = $PadreEntity
@onready var mental_alert: MentalAlert = $CanvasLayer/AlertRect
@onready var player: Node3D = $Player
@onready var player_camera: Camera3D = $Player/Head/Camera3D
@onready var fake_container: Node3D = $FakeContainer
@onready var despertar_anim_player: AnimationPlayer = $DespiertaAnim/AnimationPlayer
@onready var despierta_anim_root: CanvasLayer = $DespiertaAnim

var padre_habilitado: bool = false
var loop_padre_activo: bool = false

var pedestal_activo: bool = false
var pedestal_en_interaccion: bool = false
var pedestal_intensidad_timer: float = 0.0

var infestation_level: int = 0
var current_punishment_amount: float = 0.0

var padre_spawn_countdown: float = -1.0

# progreso real del nivel
var pedestales_completados: int = 0
var pedestales_completados_ids: Dictionary = {}

var _debug_printed_keys: Dictionary = {}
var _intro_running: bool = false


func _dbg(message: String) -> void:
	if not debug_enabled:
		return
	print("[Mundo3] ", message)


func _dbg_once(key: String, message: String) -> void:
	if not debug_enabled:
		return
	if debug_print_once_only and _debug_printed_keys.has(key):
		return
	_debug_printed_keys[key] = true
	print("[Mundo3] ", message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	if padre and not padre.punishment_changed.is_connected(_on_padre_punishment_changed):
		padre.punishment_changed.connect(_on_padre_punishment_changed)
		_dbg_once("connect_punishment", "conectado punishment_changed")

	if padre and not padre.apparition_finished.is_connected(_on_padre_apparition_finished):
		padre.apparition_finished.connect(_on_padre_apparition_finished)
		_dbg_once("connect_finished", "conectado apparition_finished")

	if padre and not padre.apparition_resolved.is_connected(_on_padre_apparition_resolved):
		padre.apparition_resolved.connect(_on_padre_apparition_resolved)
		_dbg_once("connect_resolved", "conectado apparition_resolved")

	MusicManager.play_world3(2.0)

	var scene_path: String = get_tree().current_scene.scene_file_path
	_dbg_once("ready", "READY")
	_dbg_once("scene", "scene_path = %s" % scene_path)
	_dbg_once("fake_scene", "fake_shadow_scene = %s" % str(fake_shadow_scene))
	_dbg_once("fake_container", "fake_container = %s" % str(fake_container))
	_dbg_once("player_camera", "player_camera = %s" % str(player_camera))
	_dbg_once("intro_flag", "GameData.intro_mundo3_done = %s" % str(GameData.intro_mundo3_done))

	if GameData.current_scene_path != scene_path or GameData.current_checkpoint_id == "":
		GameData.set_checkpoint(scene_path, first_checkpoint_id)

		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("save_from_gamedata"):
			sm.save_from_gamedata(GameData)

		_dbg("Checkpoint inicial registrado -> %s" % first_checkpoint_id)
	else:
		_dbg("Manteniendo checkpoint actual -> %s" % GameData.current_checkpoint_id)

	_refresh_total_visual_corruption()
	_conectar_pedestales()

	# Intro de Mundo 3: solo la primera vez
	if bool(GameData.intro_mundo3_done):
		_force_despierta_overlay_off()
		_dbg("Intro Mundo3 omitida porque intro_mundo3_done = true")
	else:
		if _intro_running:
			_dbg("Intro Mundo3 ya estaba corriendo, evitando reentrada")
			return

		_intro_running = true
		call_deferred("_start_intro_mundo3_deferred")


func _exit_tree() -> void:
	loop_padre_activo = false
	padre_habilitado = false
	pedestal_activo = false
	pedestal_en_interaccion = false
	padre_spawn_countdown = -1.0
	clear_fake_shadows()


func _start_intro_mundo3_deferred() -> void:
	_dbg("Iniciando intro Mundo3 deferred")
	await _run_intro_once()
	_intro_running = false


func _force_despierta_overlay_off() -> void:
	if despierta_anim_root == null:
		_dbg("⚠ DespiertaAnim no encontrado")
		return

	despierta_anim_root.visible = false

	if despertar_anim_player:
		despertar_anim_player.stop()


func _force_despierta_overlay_on() -> void:
	if despierta_anim_root == null:
		_dbg("⚠ DespiertaAnim no encontrado")
		return

	despierta_anim_root.visible = true


func _run_intro_once() -> void:
	_dbg(">>> INICIANDO INTRO MUNDO3 ONCE")

	# 1) mostrar overlay y reproducir animación
	_force_despierta_overlay_on()

	if despertar_anim_player == null:
		_dbg("❌ No se encontró $DespiertaAnim/AnimationPlayer")
		await get_tree().create_timer(1.5).timeout
	else:
		if despertar_anim_player.has_animation(intro_anim_name):
			_dbg("play anim -> %s" % intro_anim_name)
			despertar_anim_player.stop()
			despertar_anim_player.play(intro_anim_name)
			await despertar_anim_player.animation_finished
			_dbg("animation_finished -> %s" % intro_anim_name)
		else:
			_dbg("❌ No existe animación '%s'" % intro_anim_name)
			await get_tree().create_timer(1.5).timeout

	# 2) ocultar overlay al terminar
	_force_despierta_overlay_off()

	# 3) mostrar diálogo justo después de la animación
	var dialogue_res: Resource = _load_intro_dialogue()
	if dialogue_res != null:
		_show_intro_dialogue(dialogue_res)
		await _wait_dialogue_ended(dialogue_res)
	else:
		_dbg("⚠ No se pudo cargar el diálogo de intro Mundo3")
		await get_tree().create_timer(0.2).timeout

	# 4) marcar flag para que NO vuelva a salir
	GameData.intro_mundo3_done = true
	_dbg("GameData.intro_mundo3_done = true")

	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		_dbg("SaveManager.save_from_gamedata(GameData) OK")
	else:
		_dbg("⚠ No SaveManager o no tiene save_from_gamedata()")

	_dbg(">>> FIN INTRO MUNDO3 ONCE")


func _load_intro_dialogue() -> Resource:
	if intro_dialogue_path.strip_edges() == "":
		_dbg("❌ intro_dialogue_path vacío")
		return null

	if not ResourceLoader.exists(intro_dialogue_path):
		_dbg("❌ No existe diálogo: %s" % intro_dialogue_path)
		return null

	var res: Resource = load(intro_dialogue_path)
	if res == null:
		_dbg("❌ load() devolvió null: %s" % intro_dialogue_path)
		return null

	return res


func _show_intro_dialogue(dialogue_res: Resource) -> void:
	_dbg("_show_intro_dialogue key = %s" % intro_dialogue_key)

	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		if dm != null and dm.has_method("show_dialogue_balloon"):
			dm.call("show_dialogue_balloon", dialogue_res, intro_dialogue_key)
			_dbg("Dialogue mostrado por Engine singleton")
			return

	var dm_node := get_node_or_null("/root/DialogueManager")
	if dm_node != null and dm_node.has_method("show_dialogue_balloon"):
		dm_node.call("show_dialogue_balloon", dialogue_res, intro_dialogue_key)
		_dbg("Dialogue mostrado por /root/DialogueManager")
		return

	_dbg("❌ DialogueManager no encontrado o sin show_dialogue_balloon()")


func _wait_dialogue_ended(dialogue_res: Resource) -> void:
	_dbg("Esperando DialogueManager.dialogue_ended ...")

	if not is_inside_tree():
		_dbg("Abort wait: node fuera del árbol")
		return

	var dm_node := get_node_or_null("/root/DialogueManager")
	if dm_node == null and not Engine.has_singleton("DialogueManager"):
		_dbg("⚠ No hay DialogueManager accesible, no espero")
		return

	var max_wait := 45.0
	var timer := get_tree().create_timer(max_wait)

	while true:
		if not is_inside_tree():
			_dbg("Abort wait: salí del árbol durante la espera")
			return

		if typeof(DialogueManager) != TYPE_NIL:
			var ended_res: Resource = await DialogueManager.dialogue_ended
			_dbg("dialogue_ended recibido: %s" % str(ended_res))
			return

		await timer.timeout
		_dbg("⚠ Timeout esperando diálogo")
		return


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return

	if pedestal_activo and not pedestal_en_interaccion and not tree.paused:
		pedestal_intensidad_timer -= delta

		if pedestal_intensidad_timer <= 0.0:
			pedestal_activo = false
			pedestal_intensidad_timer = 0.0
			_dbg("pedestal_activo expiró -> vuelve ritmo normal")


func _conectar_pedestales() -> void:
	var pedestales := get_tree().get_nodes_in_group("pedestal_item")
	_dbg("Conectando pedestales -> encontrados: %d" % pedestales.size())

	for node in pedestales:
		var pedestal := node as PedestalItemInteract
		if pedestal == null:
			_dbg("⚠ Nodo en grupo pedestal_item no es PedestalItemInteract: %s" % str(node))
			continue

		if not pedestal.pedestal_started.is_connected(_on_pedestal_started):
			pedestal.pedestal_started.connect(_on_pedestal_started)
			_dbg("Conectado pedestal_started -> %s" % pedestal.pentagram_id)

		if not pedestal.pedestal_completed.is_connected(_on_pedestal_completed):
			pedestal.pedestal_completed.connect(_on_pedestal_completed)
			_dbg("Conectado pedestal_completed -> %s" % pedestal.pentagram_id)


func _unhandled_input(event: InputEvent) -> void:
	if not test_fake_spawn_enabled:
		return

	if event.is_action_pressed("ui_accept"):
		_dbg("TEST -> spawn_fake_shadows(3)")
		spawn_fake_shadows(3)

	if event.is_action_pressed("ui_cancel"):
		_dbg("TEST -> clear_fake_shadows()")
		clear_fake_shadows()


func activar_padre_por_objeto() -> void:
	if padre_habilitado:
		_dbg("activar_padre_por_objeto() ignorado, ya habilitado")
		return

	padre_habilitado = true
	_dbg("Padre habilitado por foto familiar")

	_primera_aparicion_padre()
	iniciar_loop_padre()


func _on_pedestal_started(pedestal_id: String) -> void:
	_dbg("pedestal_started -> %s" % pedestal_id)

	activar_padre_por_objeto()

	pedestal_en_interaccion = true
	pedestal_activo = true
	pedestal_intensidad_timer = pedestal_pressure_duration

	_dbg("pedestal_en_interaccion = true")
	_dbg("pedestal_activo = true por %.2f segundos" % pedestal_pressure_duration)

	infestation_level = min(infestation_level + 1, max_infestation_level)
	_dbg("Sube infestación por iniciar pedestal -> %d" % infestation_level)

	_refresh_total_visual_corruption()


func _on_pedestal_completed(pedestal_id: String) -> void:
	_dbg("pedestal_completed -> %s" % pedestal_id)

	pedestal_en_interaccion = false
	_dbg("pedestal_en_interaccion = false")

	if not pedestales_completados_ids.has(pedestal_id):
		pedestales_completados_ids[pedestal_id] = true
		pedestales_completados += 1
		_dbg("pedestales_completados = %d" % pedestales_completados)

	_refresh_total_visual_corruption()


func _primera_aparicion_padre() -> void:
	_dbg("esperando primera aparición...")
	await get_tree().create_timer(1.5).timeout

	var tree := get_tree()
	if tree == null:
		return

	if not padre_habilitado:
		_dbg("primera aparición cancelada: padre_habilitado=false")
		return

	if padre and not padre.active and not pedestal_en_interaccion and not tree.paused:
		_dbg("lanzando primera aparición")
		spawn_padre_en_punto_ciego()


func iniciar_loop_padre() -> void:
	if loop_padre_activo:
		_dbg("loop padre ya estaba activo")
		return

	loop_padre_activo = true
	_dbg("loop padre iniciado")
	_loop_padre()


func detener_loop_padre() -> void:
	loop_padre_activo = false
	_dbg("loop padre detenido")


func _get_final_phase_intensity() -> int:
	return clamp(pedestales_completados, 0, 3)


func _calculate_padre_wait_time() -> float:
	var espera: float
	var final_phase: int = _get_final_phase_intensity()
	var final_bonus: float = float(final_phase) * final_phase_wait_bonus_step

	if pedestal_activo:
		var factor: float = float(infestation_level) * infestation_spawn_factor
		var min_wait: float = max(absolute_spawn_min, pedestal_spawn_min - factor - final_bonus)
		var max_wait: float = max(absolute_spawn_max_floor, pedestal_spawn_max - factor - final_bonus)

		if max_wait < min_wait:
			max_wait = min_wait + 0.25

		espera = randf_range(min_wait, max_wait)

		_dbg(
			"wait pedestal_activo=true | infestación=%d | completados=%d | espera=%.2f (%.2f - %.2f)"
			% [infestation_level, pedestales_completados, espera, min_wait, max_wait]
		)
	else:
		var min_wait_normal: float = max(absolute_spawn_min, normal_spawn_min - final_bonus)
		var max_wait_normal: float = max(absolute_spawn_max_floor, normal_spawn_max - final_bonus)

		if max_wait_normal < min_wait_normal:
			max_wait_normal = min_wait_normal + 0.25

		espera = randf_range(min_wait_normal, max_wait_normal)
		_dbg(
			"wait pedestal_activo=false | completados=%d | espera normal=%.2f (%.2f - %.2f)"
			% [pedestales_completados, espera, min_wait_normal, max_wait_normal]
		)

	return espera


func _loop_padre() -> void:
	padre_spawn_countdown = _calculate_padre_wait_time()

	while loop_padre_activo:
		await get_tree().process_frame

		if not is_inside_tree():
			_dbg("loop cancelado: node fuera del tree")
			return

		var tree := get_tree()
		if tree == null:
			_dbg("loop cancelado: tree null")
			return

		if not loop_padre_activo:
			_dbg("loop cancelado")
			return

		if not padre_habilitado:
			continue

		if tree.paused:
			continue

		if pedestal_en_interaccion:
			continue

		if padre and padre.active:
			continue

		var delta: float = get_process_delta_time()
		padre_spawn_countdown -= delta

		if padre_spawn_countdown > 0.0:
			continue

		_dbg("loop -> spawn_padre_en_punto_ciego()")
		spawn_padre_en_punto_ciego()

		padre_spawn_countdown = _calculate_padre_wait_time()


func spawn_padre_en_punto_ciego() -> void:
	if pedestal_en_interaccion:
		_dbg("spawn cancelado: pedestal_en_interaccion=true")
		return

	var tree := get_tree()
	if tree == null:
		_dbg("spawn cancelado: tree null")
		return

	if tree.paused:
		_dbg("spawn cancelado: juego en pausa")
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_dbg("❌ No se encontró la cámara 3D")
		return

	var cam_pos: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_transform.basis.z.normalized()
	var right: Vector3 = cam.global_transform.basis.x.normalized()

	var roll: float = randf()
	var dir: Vector3

	if roll < 0.45:
		dir = (-forward + right).normalized()
	elif roll < 0.90:
		dir = (-forward - right).normalized()
	elif roll < 0.97:
		dir = -forward
	else:
		dir = [right, -right][randi() % 2]

	var final_phase: int = _get_final_phase_intensity()
	var final_close_bonus: float = float(final_phase) * final_phase_close_bonus_step

	var distancia: float

	if pedestal_activo and not pedestal_en_interaccion:
		var extra_close_factor: float = float(infestation_level) * 0.35
		var min_dist: float = max(
			padre_absolute_min_distance,
			padre_pressure_spawn_min_distance - extra_close_factor - final_close_bonus
		)
		var max_dist: float = max(
			padre_absolute_max_floor,
			padre_pressure_spawn_max_distance - extra_close_factor - final_close_bonus
		)

		if max_dist < min_dist:
			max_dist = min_dist + 0.25

		distancia = randf_range(min_dist, max_dist)

		_dbg(
			"spawn cercano por pedestal_activo | infestación=%d | completados=%d | distancia=%.2f (%.2f - %.2f)"
			% [infestation_level, pedestales_completados, distancia, min_dist, max_dist]
		)
	else:
		var min_dist_normal: float = max(
			padre_absolute_min_distance,
			padre_normal_spawn_min_distance - final_close_bonus
		)
		var max_dist_normal: float = max(
			padre_absolute_max_floor,
			padre_normal_spawn_max_distance - final_close_bonus
		)

		if max_dist_normal < min_dist_normal:
			max_dist_normal = min_dist_normal + 0.25

		distancia = randf_range(min_dist_normal, max_dist_normal)

	var spawn_pos: Vector3 = cam_pos + dir * distancia
	spawn_pos.y = cam_pos.y + padre_spawn_y_offset

	_dbg("Padre spawn en: %s" % str(spawn_pos))
	_dbg("infestation_level actual = %d" % infestation_level)

	padre.aparecer(spawn_pos)

	if infestation_level > 0:
		var fake_amount: int = infestation_level

		if pedestal_activo and not pedestal_en_interaccion:
			fake_amount = min(fake_amount + 1, max_infestation_level)

		if pedestales_completados >= 2:
			fake_amount = min(fake_amount + 1, max_infestation_level)

		_dbg("fake_amount final = %d" % fake_amount)
		spawn_fake_shadows(fake_amount)
	else:
		_dbg("infestación 0 -> limpiando fake shadows")
		clear_fake_shadows()

	if mental_alert:
		mental_alert.trigger_alert(0.85, 0.45)

	_refresh_total_visual_corruption()


func _on_padre_punishment_changed(amount: float) -> void:
	current_punishment_amount = clamp(amount, 0.0, 1.0)
	_refresh_total_visual_corruption()


func _on_padre_apparition_resolved(found_by_player: bool) -> void:
	_dbg("apparition_resolved -> found_by_player = %s" % str(found_by_player))

	if found_by_player:
		infestation_level = max(infestation_level - 1, 0)
		_dbg("Padre encontrado -> infestación baja a: %d" % infestation_level)
	else:
		infestation_level = min(infestation_level + 1, max_infestation_level)
		_dbg("Padre NO encontrado -> infestación sube a: %d" % infestation_level)

	_refresh_total_visual_corruption()


func _on_padre_apparition_finished() -> void:
	_dbg("apparition_finished -> limpiando fake shadows")
	current_punishment_amount = 0.0
	clear_fake_shadows()

	if mental_alert:
		mental_alert.clear_corruption()

	if player and player.has_method("set_mind_corruption"):
		player.set_mind_corruption(0.0)

	_refresh_total_visual_corruption()


func _refresh_total_visual_corruption() -> void:
	var final_phase_bonus: float = float(_get_final_phase_intensity()) * final_phase_visual_bonus_step
	var infestation_visual: float = float(infestation_level) * infestation_visual_bonus
	var visual_amount: float = clamp(current_punishment_amount + infestation_visual + final_phase_bonus, 0.0, 1.0)

	if mental_alert:
		mental_alert.set_corruption(visual_amount)

	if player and player.has_method("set_mind_corruption"):
		player.set_mind_corruption(visual_amount)


func spawn_fake_shadows(amount: int) -> void:
	_dbg("spawn_fake_shadows() llamado con amount = %d" % amount)

	if fake_shadow_scene == null:
		_dbg("❌ FakeShadow scene no asignada")
		return

	if fake_container == null:
		_dbg("❌ FakeContainer no encontrado")
		return

	if player_camera == null:
		_dbg("❌ Player camera no encontrada")
		return

	clear_fake_shadows()

	var spawn_count: int = clamp(amount, 0, max_infestation_level)
	_dbg("spawn_count final = %d" % spawn_count)

	for i in range(spawn_count):
		var fake = fake_shadow_scene.instantiate()
		if fake == null:
			_dbg("❌ no se pudo instanciar fake #%d" % i)
			continue

		fake_container.add_child(fake)

		var spawn_pos: Vector3 = _get_fake_shadow_spawn_position(i, spawn_count)
		fake.global_position = spawn_pos

		_dbg("FakeShadow #%d creada en posición: %s" % [i, str(spawn_pos)])

		if fake.has_method("setup"):
			fake.setup(player_camera)
		else:
			_dbg("❌ FakeShadow #%d no tiene setup()" % i)

	_dbg("fake_container child_count = %d" % fake_container.get_child_count())


func clear_fake_shadows() -> void:
	if fake_container == null:
		_dbg("clear_fake_shadows() -> fake_container null")
		return

	var count: int = fake_container.get_child_count()
	if count > 0:
		_dbg("clear_fake_shadows() -> eliminando %d fake shadows" % count)

	for child in fake_container.get_children():
		child.queue_free()


func _get_fake_shadow_spawn_position(index: int, total: int) -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return player.global_position + Vector3(0.0, 0.2, -3.0)

	var cam_pos: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_transform.basis.z.normalized()
	var right: Vector3 = cam.global_transform.basis.x.normalized()

	var dir_candidates: Array[Vector3] = []
	dir_candidates.append((-forward + right).normalized())
	dir_candidates.append((-forward - right).normalized())
	dir_candidates.append(right.normalized())
	dir_candidates.append((-right).normalized())
	dir_candidates.append((-forward).normalized())

	dir_candidates.shuffle()

	var chosen_dir: Vector3 = dir_candidates[index % dir_candidates.size()]
	var radius: float = randf_range(fake_spawn_radius_min, fake_spawn_radius_max)

	var spawn_pos: Vector3 = cam_pos + chosen_dir * radius
	spawn_pos.y = cam_pos.y + fake_spawn_height_offset + randf_range(-0.15, 0.15)

	return spawn_pos
