extends Node3D
class_name ChaseManager

# ==================================================
# ChaseManager:
# - Arranca secuencia (look + susurro + diálogo)
# - Enemigo grita -> chase
# - Cuando captura, resuelve según GameData.chase_capture_mode
#
# ✅ Arquitectura respetada:
# - GameData es la única verdad
# - SaveManager solo save_from_gamedata/load_into_gamedata
# - En death: set_checkpoint + save_from_gamedata
# - Luego JUMPSCARE -> GameOver
#
# 🔥 FIX: Captura -> JUMPSCARE INMEDIATO (sin esperar fade de música)
# - No await en _on_enemy_captured
# - Stop music en paralelo (sin await) y con fade 0 para death
# ==================================================

# ===== MISSION HUD =====
@export var mission_hud_scene: PackedScene = preload("res://Pantallas/SobreviveMision.tscn")
@export var mission_duration_sec: float = 90.0
@export var mission_objective_text: String = "OBJETIVO: SOBREVIVE"
@export var world3_scene: PackedScene

@export var tunnel_trigger_path: NodePath
@export var entrance_look_target_path: NodePath
@export var enemy_spawn_path: NodePath
@export var enemy_path: NodePath

@export var danger_far_distance: float = 12.0
@export var danger_near_distance: float = 3.2
@export var danger_update_hz: float = 12.0

# ===== CHASE MUSIC =====
@export var chase_music_stream: AudioStream = preload("res://Musica y sonidos/PersecucionTunel.ogg")
@export var chase_music_fade_in: float = 0.35
@export var chase_music_fade_out: float = 0.70
@export var chase_music_volume_db: float = -10.0

# ===== AUDIO =====
@export var whisper_stream: AudioStream = preload("res://Musica y sonidos/Sonidos/susurro.ogg")
@export var whisper_volume_db: float = 3.0
@export var whisper_extra_silence: float = 0.25

# ===== DIÁLOGO =====
@export var dialogue_path: String = "res://Dialogos/Enemigo_tunel.dialogue"
@export var dialogue_title: StringName = &"enemigo_tunel"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

# ===== Cámara / transición =====
@export var forced_look_speed: float = 10.0

# 🔥 Separado por modo:
@export var capture_freeze_time_death: float = 0.0
@export var capture_freeze_time_knockout: float = 0.6

# ===== Retry settings =====
@export var retry_checkpoint_id: String = "before_mission2"
@export var autosave_on_retry: bool = true

# ===== DEATH flow: jumpscare + game over =====
@export var jumpscare_scene: PackedScene = preload("res://Cinematicas/jumpscare.tscn")
@export var jumpscare_fallback_duration: float = 1.6
@export var gameover_scene_path: String = "res://Pantallas/Game_Over.tscn"
@export var knockout_overlay_scene: PackedScene = preload("res://UI/KnockoutOverlay.tscn")

# ✅ Pantalla de carga (nuevo flujo knockout -> carga -> mundo 3)
@export var loading_screen_scene_path: String = "res://Pantallas/PantallaCarga.tscn"
@export var world3_intro_scene_path: String = "res://Cinematicas/Mundo3Intro.tscn"

# Debug opcional
@export var debug_print: bool = false

var _danger_accum: float = 0.0
var _mission_hud: Node = null
var _trigger: Area3D
var _look_target: Node3D
var _enemy_spawn: Node3D
var _enemy: Node = null
var _player: CharacterBody3D = null

var _active: bool = false
var _captured: bool = false


func _ready() -> void:
	# ==================================================
	# Obtener referencias principales
	# ==================================================
	_trigger = get_node_or_null(tunnel_trigger_path) as Area3D
	_look_target = get_node_or_null(entrance_look_target_path) as Node3D
	_enemy_spawn = get_node_or_null(enemy_spawn_path) as Node3D
	_enemy = get_node_or_null(enemy_path)

	# Fallback por nombre si no se asignó enemy_path
	if _enemy == null:
		_enemy = get_parent().get_node_or_null("Enemigo")

	# ==================================================
	# Validaciones
	# ==================================================
	if _trigger == null:
		push_error("[ChaseManager] TunnelTrigger no encontrado.")
		return

	if _look_target == null:
		push_error("[ChaseManager] EntranceLookTarget no encontrado.")
		return

	if _enemy_spawn == null:
		push_error("[ChaseManager] EnemySpawn no encontrado.")
		return

	if _enemy == null:
		push_error("[ChaseManager] Enemigo no encontrado (enemy_path o nombre 'Enemigo').")
		return

	print("[ChaseManager] READY ✅ node=", get_path())
	print("[ChaseManager] trigger=", _trigger, " enemy=", _enemy, " enemy_spawn=", _enemy_spawn)

	# ==================================================
	# Configuración inicial del enemigo
	# ==================================================
	if "visible" in _enemy:
		_enemy.visible = false

	if _enemy.has_method("stop_all"):
		_enemy.call("stop_all")

	# ==================================================
	# Conectar señales
	# ==================================================
	if _enemy.has_signal("captured"):
		if not _enemy.captured.is_connected(_on_enemy_captured):
			_enemy.captured.connect(_on_enemy_captured)

	if not _trigger.body_entered.is_connected(_on_trigger_body_entered):
		_trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node) -> void:
	if _active:
		return

	if debug_print:
		print("[ChaseManager] TRIGGER -> body=", body, " groups Player?=", body.is_in_group("Player"))

	if not body.is_in_group("Player"):
		return

	_player = body as CharacterBody3D
	if _player == null:
		return

	_active = true
	_trigger.set_deferred("monitoring", false)

	await _start_sequence()


func _start_sequence() -> void:
	# ==================================================
	# Defaults para evitar valores viejos en GameData.
	# Las zonas (Death/Knockout) los pueden sobreescribir.
	# ==================================================
	GameData.chase_capture_mode = "knockout"
	GameData.chase_retry_checkpoint_id = retry_checkpoint_id

	if debug_print:
		print("[ChaseManager] Defaults -> mode=knockout retry_cp=", retry_checkpoint_id)

	# 1) Spawn enemigo + target (pero quieto)
	if _enemy.has_method("prepare_and_show"):
		_enemy.call("prepare_and_show", _enemy_spawn.global_transform)
	else:
		_enemy.global_transform = _enemy_spawn.global_transform
		if "visible" in _enemy:
			_enemy.visible = true

	if _enemy.has_method("set_target"):
		_enemy.call("set_target", _player)

	if _enemy.has_method("hold_idle"):
		_enemy.call("hold_idle")

	# 2) Conectar captura
	if _enemy.has_signal("captured"):
		if not _enemy.captured.is_connected(_on_enemy_captured):
			_enemy.captured.connect(_on_enemy_captured)

	# 3) Forzar cámara a la entrada
	if _player.has_method("lock_camera_control"):
		_player.call("lock_camera_control", true)
	if _player.has_method("start_forced_look"):
		_player.call("start_forced_look", _look_target, forced_look_speed)

	# 4) Susurro 3D
	await _play_whisper_at(_enemy_spawn.global_position)
	await get_tree().create_timer(whisper_extra_silence).timeout

	# 5) Diálogo
	var dialogue_res: Resource = load(dialogue_path)
	if dialogue_res == null:
		push_error("[ChaseManager] No se pudo cargar dialogue: " + dialogue_path)
	else:
		var balloon: Node = balloon_scene.instantiate()
		get_tree().current_scene.add_child(balloon)

		if balloon.has_method("start"):
			balloon.start(dialogue_res, dialogue_title)
		else:
			push_error("[ChaseManager] balloon no tiene método start().")

		await _wait_dialogue_ended(dialogue_res)

		if is_instance_valid(balloon):
			balloon.queue_free()

	# 6) Termina diálogo -> arranca música de persecución
	_start_chase_music()

	# ✅ HUD misión aparece aquí
	_show_mission_hud()

	# 7) Enemigo grita -> empieza persecución
	if _enemy.has_method("scream_then_chase"):
		_enemy.call_deferred("scream_then_chase")

	# 8) Devolver control al jugador
	if _player.has_method("stop_forced_look"):
		_player.call("stop_forced_look")
	if _player.has_method("lock_camera_control"):
		_player.call("lock_camera_control", false)


func _play_whisper_at(pos: Vector3) -> void:
	if whisper_stream == null:
		return

	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = whisper_stream
	p.volume_db = whisper_volume_db
	p.unit_size = 6.0
	p.max_distance = 28.0
	p.attenuation_filter_cutoff_hz = 8000.0

	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.play()

	await p.finished
	if is_instance_valid(p):
		p.queue_free()


func _wait_dialogue_ended(dialogue_res: Resource) -> void:
	while true:
		var ended_res: Resource = await DialogueManager.dialogue_ended
		if ended_res == dialogue_res:
			return


# ✅ FIX: no await aquí, defer resolve fuera del callback
func _on_enemy_captured(_p: Node) -> void:
	print("[ChaseManager] ENEMY CAPTURE SIGNAL ✅")
	if _captured:
		return
	_captured = true
	call_deferred("_capture_and_resolve")


# ==================================================
# ✅ RESOLVER CAPTURA (SIN DUPLICADOS)
# ==================================================
func _capture_and_resolve() -> void:
	var mode: String = str(GameData.chase_capture_mode)
	if mode == "":
		mode = "knockout"

	var cp: String = str(GameData.chase_retry_checkpoint_id)
	if cp == "":
		cp = retry_checkpoint_id

	print("[ChaseManager] CAPTURE resolve -> mode=", mode, " cp=", cp)

	_hide_mission_hud()

	if _enemy and _enemy.has_method("stop_all"):
		_enemy.call("stop_all")

	if _player and _player.has_method("lock_camera_control"):
		_player.call("lock_camera_control", true)
	if _player and _player.has_method("set_movement_locked"):
		_player.call("set_movement_locked", true)

	# ==================================================
	# A) DEATH -> JUMPSCARE -> GAME OVER
	# ==================================================
	if mode == "death":
		_stop_chase_music_now(0.0)

		if capture_freeze_time_death > 0.0:
			await get_tree().create_timer(capture_freeze_time_death).timeout

		var scene_path: String = get_tree().current_scene.scene_file_path
		GameData.set_checkpoint(scene_path, cp)

		if autosave_on_retry:
			var sm := get_node_or_null("/root/SaveManager")
			if sm and sm.has_method("save_from_gamedata"):
				sm.save_from_gamedata(GameData)

		await _play_jumpscare_immediate()

		get_tree().call_deferred("change_scene_to_file", gameover_scene_path)
		return

	# ==================================================
	# B) KNOCKOUT -> MUNDO 3
	# ==================================================
	_stop_chase_music_now(chase_music_fade_out)

	if knockout_overlay_scene:
		var ko := knockout_overlay_scene.instantiate()
		get_tree().current_scene.add_child(ko)

		if ko.has_method("play_knockout"):
			ko.play_knockout()
			if ko.has_signal("finished"):
				await ko.finished

		if is_instance_valid(ko):
			ko.queue_free()

	if world3_scene:
		var world3_path: String = world3_scene.resource_path

		if world3_path == "":
			push_error("[ChaseManager] world3_scene sin resource_path")
			return

		GameData.clear_checkpoint()

		if GameData.intro_mundo3_done:
			GameData.current_scene_path = world3_path
			print("[ChaseManager] Mundo3 directo")
		else:
			GameData.current_scene_path = world3_intro_scene_path
			print("[ChaseManager] Mundo3Intro primero")

		get_tree().call_deferred("change_scene_to_file", loading_screen_scene_path)
	else:
		push_error("[ChaseManager] world3_scene no asignado")


# ==================================================
# ✅ JUMPSCARE inmediato:
# ==================================================
func _play_jumpscare_immediate() -> void:
	if jumpscare_scene == null:
		push_error("[ChaseManager] jumpscare_scene null.")
		await get_tree().create_timer(jumpscare_fallback_duration).timeout
		return

	var inst: Node = jumpscare_scene.instantiate()
	get_tree().current_scene.add_child(inst)

	if inst.has_method("start"):
		inst.call("start")
	elif inst.has_method("play"):
		inst.call("play")

	if inst.has_signal("finished"):
		await inst.finished
	elif inst.has_signal("jumpscare_finished"):
		await inst.jumpscare_finished
	else:
		await get_tree().create_timer(jumpscare_fallback_duration).timeout

	if is_instance_valid(inst):
		inst.queue_free()


# ==================================================
# CHASE MUSIC (usa MusicManager real)
# ==================================================
func _start_chase_music() -> void:
	if chase_music_stream == null:
		return

	var mm := get_node_or_null("/root/MusicManager")
	if mm == null:
		push_warning("[ChaseManager] MusicManager no encontrado. No puedo iniciar música de persecución.")
		return

	if mm.has_method("play_stream"):
		mm.call_deferred("play_stream", chase_music_stream, chase_music_fade_in, true, chase_music_volume_db)


func _stop_chase_music_now(fade_time: float) -> void:
	var mm := get_node_or_null("/root/MusicManager")
	if mm == null:
		return

	if mm.has_method("world2_kill_music_like_tape"):
		mm.call_deferred("world2_kill_music_like_tape", fade_time)
	else:
		if mm.has_method("fade_out_and_stop"):
			mm.call_deferred("fade_out_and_stop", fade_time)
		elif mm.has_method("fade_out"):
			mm.call_deferred("fade_out", fade_time)
			if mm.has_method("stop"):
				mm.call_deferred("stop", true)


func _show_mission_hud() -> void:
	if mission_hud_scene == null:
		push_warning("[ChaseManager] mission_hud_scene null.")
		return

	if is_instance_valid(_mission_hud):
		_mission_hud.queue_free()
		_mission_hud = null

	_mission_hud = mission_hud_scene.instantiate()
	get_tree().current_scene.add_child(_mission_hud)

	if _mission_hud.has_method("start"):
		_mission_hud.call("start", mission_duration_sec, mission_objective_text)


func _hide_mission_hud() -> void:
	if is_instance_valid(_mission_hud):
		_mission_hud.queue_free()
	_mission_hud = null


func _process(delta: float) -> void:
	if not _active:
		return
	if _player == null or _enemy == null:
		return
	if not is_instance_valid(_mission_hud):
		return

	_danger_accum += delta
	var step: float = 1.0 / max(1.0, danger_update_hz)
	if _danger_accum < step:
		return
	_danger_accum = 0.0

	var ep: Vector3 = (_enemy as Node3D).global_position
	var pp: Vector3 = (_player as Node3D).global_position
	var dist: float = ep.distance_to(pp)

	var t: float = clamp(
		(danger_far_distance - dist) / max(0.001, (danger_far_distance - danger_near_distance)),
		0.0,
		1.0
	)

	t = pow(t, 1.10)

	if _mission_hud.has_method("set_danger_ratio"):
		_mission_hud.call("set_danger_ratio", t)
