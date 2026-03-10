extends Node3D
class_name MunecoViejoInteract

@onready var area: Area3D = $Area3D
@onready var collision: CollisionShape3D = $Area3D/CollisionShape3D

var puntero_ui: Node = null

@export var muneco_anim_scene: PackedScene = preload("res://PNG_OBJETOS/Muñeco_viejo_animacion.tscn")
@export var dialogue_path: String = "res://Dialogos/Muñeco_viejo.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

@export var delay_before_statue_event: float = 3.0
@export var statue_dialogue_path: String = "res://Dialogos/Audio_estatua.dialogue"
@export var statue_dialogue_title: String = "audio_estatua"
@export var look_speed: float = 7.0

const STATUE_AUDIO: AudioStream = preload("res://Musica y sonidos/Sonidos/Audio_Estatua.ogg")
@export var statue_audio_volume_db: float = -6.0
@export var statue_dialogue_timeout: float = 12.0

var player_inside: bool = false
var used: bool = false
var _busy: bool = false
var _finished: bool = false
var _unlocked: bool = false

var muneco_anim_instance: CanvasLayer = null
var balloon_instance: Node = null


func _ready() -> void:
	add_to_group("muneco_viejo")

	used = bool(GameData.muneco_antiguo_done)

	if not area.body_entered.is_connected(_on_area_entered):
		area.body_entered.connect(_on_area_entered)
	if not area.body_exited.is_connected(_on_area_exited):
		area.body_exited.connect(_on_area_exited)

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)

	if used:
		_disable_interaction()
		return

	if bool(GameData.letrero_viejo_done):
		_unlocked = true
		_enable_and_show()
	else:
		_unlocked = false
		_hide_and_lock()


func unlock_after_letrero() -> void:
	if used:
		return
	_unlocked = true
	_enable_and_show()
	print("[MuñecoViejo] desbloqueado ✅")


func _on_area_entered(body: Node) -> void:
	if used or _busy or not _unlocked:
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


func _process(_delta: float) -> void:
	if used or _busy or not _unlocked or not player_inside:
		return

	if Input.is_action_just_pressed("action_use"):
		_interactuar()


func _interactuar() -> void:
	if used or _busy or not _unlocked:
		return

	_busy = true
	used = true
	_disable_interaction()

	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	_show_muneco_anim()

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_start"):
		MusicManager.on_world2_dialogue_start(2, 0.6)

	_start_dialogue()


func _show_muneco_anim() -> void:
	if not muneco_anim_scene:
		push_error("❌ muneco_anim_scene es null")
		return

	muneco_anim_instance = muneco_anim_scene.instantiate()
	get_tree().get_current_scene().add_child(muneco_anim_instance)

	var anim := muneco_anim_instance.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if not anim:
		push_error("❌ No se encontró AnimatedSprite2D en la animación del muñeco")
		return

	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	anim.speed_scale = 1.0
	anim.frame = 0

	if anim.sprite_frames and anim.sprite_frames.has_animation("Muñeco_rotacion"):
		anim.play("Muñeco_rotacion")
	elif anim.sprite_frames:
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			anim.play(names[0])


func _start_dialogue() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_on_dialogue_finished()
		return
	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_on_dialogue_finished()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogue_finished):
			balloon_instance.dialogue_finished.connect(_on_dialogue_finished)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_on_dialogue_finished()
		return

	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, "muneco_viejo")
	else:
		push_error("❌ balloon_instance no tiene start()")
		_on_dialogue_finished()


func _on_dialogue_finished() -> void:
	if _finished:
		return
	_finished = true

	GameData.muneco_antiguo_done = true

	# ✅ Atmósfera stage +1
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm and atm.has_method("advance_stage"):
		atm.advance_stage()

	# ✅ Música base stage 2
	if MusicManager != null and MusicManager.has_method("set_world2_stage"):
		if int(MusicManager.world2_stage) < 2:
			MusicManager.set_world2_stage(2, 1.2)

	# ✅ Desbloquear estatua
	var statue := get_tree().get_first_node_in_group("angel_statue")
	if statue != null and statue.has_method("unlock_after_doll"):
		statue.call("unlock_after_doll")

	_safe_free(muneco_anim_instance)
	muneco_anim_instance = null

	_safe_free(balloon_instance)
	balloon_instance = null

	_busy = false

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_end"):
		MusicManager.on_world2_dialogue_end(2.2, 1.1)

	# ✅ AUTOSAVE REAL
	_autosave_now()

	# ---------------- FLOW evento estatua ----------------
	if not is_inside_tree():
		queue_free()
		return

	var player := get_tree().get_first_node_in_group("Player")
	var statue2 := get_tree().get_first_node_in_group("angel_statue")

	var focus: Node3D = null
	if statue2:
		focus = statue2.get_node_or_null("FocusPoint") as Node3D
		if focus == null and statue2 is Node3D:
			focus = statue2 as Node3D

	await get_tree().create_timer(delay_before_statue_event).timeout

	if is_instance_valid(player) and is_instance_valid(focus) and player.has_method("lock_camera_control") and player.has_method("start_forced_look"):
		player.lock_camera_control(true)
		player.start_forced_look(focus, look_speed)

	await _play_statue_audio_and_wait()
	await _start_statue_dialogue_and_wait()
	_release_player_camera(player)

	queue_free()


func _autosave_now() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[MuñecoViejo] Autosave ✅ done=true")


func _play_statue_audio_and_wait() -> void:
	if STATUE_AUDIO == null:
		return
	if not is_inside_tree():
		return

	var p := AudioStreamPlayer.new()
	p.stream = STATUE_AUDIO
	p.volume_db = statue_audio_volume_db
	get_tree().current_scene.add_child(p)
	p.play()

	var len := 0.0
	if p.stream:
		len = p.stream.get_length()

	if len > 0.05:
		await get_tree().create_timer(len + 0.1).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	_safe_free(p)


func _start_statue_dialogue_and_wait() -> void:
	if not ResourceLoader.exists(statue_dialogue_path):
		push_error("❌ No se encontró el diálogo: " + statue_dialogue_path)
		return
	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		return
	if not is_inside_tree():
		return

	var dialogue_resource := load(statue_dialogue_path)

	var b = balloon_scene.instantiate()
	get_tree().current_scene.add_child(b)

	var key := statue_dialogue_title
	if key == "" or key == "start":
		key = "audio_estatua"

	var finished_signal := false
	if b.has_signal("dialogue_finished"):
		b.dialogue_finished.connect(func(): finished_signal = true)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_safe_free(b)
		return

	if b.has_method("start"):
		b.start(dialogue_resource, key)
	else:
		push_error("❌ balloon_instance no tiene start()")
		_safe_free(b)
		return

	var t := 0.0
	while not finished_signal and t < statue_dialogue_timeout:
		await get_tree().create_timer(0.05).timeout
		t += 0.05

	_safe_free(b)


func _release_player_camera(player) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("stop_forced_look"):
		player.stop_forced_look()
	if player.has_method("lock_camera_control"):
		player.lock_camera_control(false)


func _hide_and_lock() -> void:
	visible = false
	_disable_interaction()

func _enable_and_show() -> void:
	visible = true
	area.monitoring = true
	area.monitorable = true
	if collision:
		collision.disabled = false

func _disable_interaction() -> void:
	area.monitoring = false
	area.monitorable = false
	if collision:
		collision.disabled = true


func _safe_free(node) -> void:
	if not is_instance_valid(node):
		return
	if node is Node:
		node.queue_free()
