extends Node3D
class_name LetreroViejoInteract

@onready var area: Area3D = $Area3D

@export var dialogue_path: String = "res://Dialogos/Letrero_viejo.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
@export var letrero_screen_scene: PackedScene = preload("res://Pantallas/Letrero_viejo.tscn")

@export var muneco_viejo_path: NodePath

const DIALOGUE_NODE := "letrero_viejo"

var player_inside: bool = false
var used: bool = false
var _busy: bool = false
var _finished: bool = false

var puntero_ui: Node = null
var balloon_instance: Node = null
var letrero_screen_instance: Control = null


func _ready() -> void:
	used = bool(GameData.letrero_viejo_done)

	if not area.body_entered.is_connected(_on_area_entered):
		area.body_entered.connect(_on_area_entered)
	if not area.body_exited.is_connected(_on_area_exited):
		area.body_exited.connect(_on_area_exited)

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)

	if used:
		_disable_area()
		_unlock_muneco() # importante para LOAD
		return


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


func _process(_delta: float) -> void:
	if used or _busy or not player_inside:
		return
	if Input.is_action_just_pressed("action_use"):
		_interactuar()


func _interactuar() -> void:
	if used or _busy:
		return

	_busy = true
	used = true
	_disable_area()

	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	_show_letrero_screen()

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_start"):
		MusicManager.on_world2_dialogue_start(1, 0.6)

	_start_dialogue()


func _disable_area() -> void:
	area.monitoring = false
	area.monitorable = false
	for c in area.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true


func _show_letrero_screen() -> void:
	if not letrero_screen_scene:
		return
	letrero_screen_instance = letrero_screen_scene.instantiate() as Control
	get_tree().get_current_scene().add_child(letrero_screen_instance)
	letrero_screen_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letrero_screen_instance.z_index = 10


func _start_dialogue() -> void:
	if not ResourceLoader.exists(dialogue_path) or not balloon_scene:
		_on_dialogue_finished()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogue_finished):
			balloon_instance.dialogue_finished.connect(_on_dialogue_finished)
	else:
		_on_dialogue_finished()
		return

	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, DIALOGUE_NODE)
	else:
		_on_dialogue_finished()


func _on_dialogue_finished() -> void:
	if _finished:
		return
	_finished = true

	# ✅ Persistencia
	GameData.letrero_viejo_done = true

	# ✅ Atmósfera stage +1
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm and atm.has_method("advance_stage"):
		atm.advance_stage()

	# ✅ Música base stage 1
	if MusicManager != null and MusicManager.has_method("set_world2_stage"):
		if int(MusicManager.world2_stage) < 1:
			MusicManager.set_world2_stage(1, 1.2)

	_unlock_muneco()

	# limpiar UI letrero
	if letrero_screen_instance and letrero_screen_instance.is_inside_tree():
		letrero_screen_instance.queue_free()
	letrero_screen_instance = null

	# cerrar balloon
	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
	balloon_instance = null

	_busy = false

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_end"):
		MusicManager.on_world2_dialogue_end(1.8, 1.0)

	# ✅ AUTOSAVE REAL (esto es lo que faltaba)
	_autosave_now()


func _autosave_now() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[LetreroViejo] Autosave ✅ done=true")


func _unlock_muneco() -> void:
	var muneco: Node = get_tree().get_first_node_in_group("muneco_viejo")

	if muneco == null and muneco_viejo_path != NodePath(""):
		muneco = get_node_or_null(muneco_viejo_path)

	if muneco and muneco.has_method("unlock_after_letrero"):
		muneco.call("unlock_after_letrero")
	else:
		push_warning("⚠️ No pude desbloquear el muñeco (grupo 'muneco_viejo' o muneco_viejo_path).")
