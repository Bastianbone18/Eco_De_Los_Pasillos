extends Node3D
class_name PedestalItemInteract

@onready var area: Area3D = $Area3D
@onready var collision: CollisionShape3D = $Area3D/CollisionShape3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var item_holder: Node3D = $ItemHolder
@export var suelo_corrupto_controller_path: NodePath
@export var corruption_amount: float = 0.33

var puntero_ui: Node = null
var player_inside: bool = false
var used: bool = false
var busy: bool = false

var item_revealed: bool = false
var float_time: float = 0.0

var _item_base_position: Vector3
var _item_base_scale: Vector3

var item_popup_instance: Node = null
var balloon_instance: Node = null

@export var reveal_delay: float = 0.58
@export var float_height: float = 0.035
@export var float_speed: float = 1.8
@export var rotate_speed: float = 45.0

@export var item_popup_scene: PackedScene
@export var dialogue_path: String = ""
@export var dialogue_title: String = ""

@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

@export var flash_light_path: NodePath
@export var flash_energy: float = 2.8
@export var flash_time: float = 0.16
@export var remove_item_delay: float = 3.0

@export var pentagram_manager_path: NodePath
@export_enum("anillo", "campana", "vela") var pentagram_id: String = "anillo"

func _ready() -> void:
	add_to_group("pedestal_item")

	visible = true

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)

	if not area.body_entered.is_connected(_on_area_entered):
		area.body_entered.connect(_on_area_entered)

	if not area.body_exited.is_connected(_on_area_exited):
		area.body_exited.connect(_on_area_exited)

	area.monitoring = true
	area.monitorable = true

	if collision:
		collision.disabled = false

	_item_base_position = item_holder.position
	_item_base_scale = item_holder.scale

	item_revealed = false
	item_holder.visible = false

	var flash_light := get_node_or_null(flash_light_path) as Light3D
	if flash_light:
		flash_light.visible = false
		flash_light.light_energy = 0.0

	if anim.has_animation("loop_idle"):
		anim.play("loop_idle")
	else:
		push_warning("[Pedestal] No existe la animación 'loop_idle'")

func _process(delta: float) -> void:
	if item_revealed and is_instance_valid(item_holder) and item_holder.visible:
		float_time += delta
		item_holder.rotation_degrees.y += rotate_speed * delta

		var pos := _item_base_position
		pos.y += sin(float_time * float_speed) * float_height
		item_holder.position = pos

	if used or busy or not player_inside:
		return

	if Input.is_action_just_pressed("action_use"):
		if _is_closest_pedestal_to_player():
			_interactuar()

func _on_area_entered(body: Node) -> void:
	if used or busy:
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

func _is_closest_pedestal_to_player() -> bool:
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player == null:
		return false

	var closest: PedestalItemInteract = null
	var closest_dist := INF

	for node in get_tree().get_nodes_in_group("pedestal_item"):
		var pedestal := node as PedestalItemInteract
		if pedestal == null:
			continue

		if pedestal.used or pedestal.busy or not pedestal.player_inside:
			continue

		var d := player.global_position.distance_squared_to(pedestal.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = pedestal

	return closest == self

func _interactuar() -> void:
	if used or busy:
		return

	busy = true
	used = true

	_disable_interaction()

	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	if anim.has_animation("Abrir"):
		anim.play("Abrir")
		await get_tree().create_timer(reveal_delay).timeout
		await _reveal_item()
		await anim.animation_finished
	else:
		push_warning("[Pedestal] No existe la animación 'Abrir'")

	await get_tree().create_timer(0.15).timeout

	_mostrar_animacion_item()
	_iniciar_dialogo()

func _reveal_item() -> void:
	if not is_instance_valid(item_holder):
		return

	item_holder.visible = true
	item_revealed = false

	item_holder.position = _item_base_position + Vector3(0, -0.08, 0)
	item_holder.scale = _item_base_scale * 0.75

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(item_holder, "position", _item_base_position, 0.28)
	tween.tween_property(item_holder, "scale", _item_base_scale, 0.28)

	await tween.finished

	item_revealed = true
	float_time = 0.0

func _mostrar_animacion_item() -> void:
	if not item_popup_scene:
		push_error("❌ item_popup_scene es null")
		return

	item_popup_instance = item_popup_scene.instantiate()
	get_tree().get_current_scene().add_child(item_popup_instance)

	var anim2d := item_popup_instance.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if anim2d:
		anim2d.process_mode = Node.PROCESS_MODE_ALWAYS
		anim2d.speed_scale = 1.0
		anim2d.frame = 0

		if anim2d.sprite_frames:
			var names := anim2d.sprite_frames.get_animation_names()
			if names.size() > 0:
				anim2d.play(names[0])
			else:
				anim2d.play()

func _iniciar_dialogo() -> void:
	if dialogue_path == "" or not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_on_dialogo_item_terminado()
		return

	if dialogue_title == "":
		push_error("❌ dialogue_title está vacío")
		_on_dialogo_item_terminado()
		return

	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_on_dialogo_item_terminado()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogo_item_terminado):
			balloon_instance.dialogue_finished.connect(_on_dialogo_item_terminado)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_on_dialogo_item_terminado()
		return

	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, dialogue_title)
	else:
		push_error("❌ balloon_instance no tiene método start()")
		_on_dialogo_item_terminado()

func _on_dialogo_item_terminado() -> void:
	if item_popup_instance and item_popup_instance.is_inside_tree():
		item_popup_instance.queue_free()
		item_popup_instance = null

	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
		balloon_instance = null

	_activar_mi_pentagrama()
	_activar_corrupcion_suelo()
	_after_dialogue_cleanup()

func _after_dialogue_cleanup() -> void:
	call_deferred("_after_dialogue_cleanup_deferred")

func _after_dialogue_cleanup_deferred() -> void:
	await get_tree().create_timer(remove_item_delay).timeout
	await _flash_and_hide_item()
	busy = false

func _flash_and_hide_item() -> void:
	item_revealed = false

	var flash_light := get_node_or_null(flash_light_path) as Light3D
	if flash_light:
		flash_light.visible = true
		flash_light.light_energy = flash_energy

		var tween := create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, flash_time)
		await tween.finished

		flash_light.light_energy = 0.0
		flash_light.visible = false

	if is_instance_valid(item_holder):
		item_holder.visible = false

func _activar_mi_pentagrama() -> void:
	print("=== INTENTANDO ACTIVAR PENTAGRAMA ===")
	print("pentagram_id: ", pentagram_id)
	print("manager_path: ", pentagram_manager_path)

	var manager := get_node_or_null(pentagram_manager_path)
	print("manager encontrado?: ", manager != null)

	if manager == null:
		push_warning("[Pedestal] No se encontró pentagram_manager_path")
		return

	print("manager name: ", manager.name)
	print("tiene metodo activar_pentagrama?: ", manager.has_method("activar_pentagrama"))

	if manager.has_method("activar_pentagrama"):
		manager.activar_pentagrama(pentagram_id)
	else:
		push_warning("[Pedestal] El manager no tiene método activar_pentagrama")

func _disable_interaction() -> void:
	area.monitoring = false
	area.monitorable = false

	if collision:
		collision.disabled = true
func _activar_corrupcion_suelo() -> void:
	var controller := get_node_or_null(suelo_corrupto_controller_path)
	if controller == null:
		push_warning("[Pedestal] No se encontró suelo_corrupto_controller_path")
		return

	if controller.has_method("add_corruption_step"):
		controller.add_corruption_step(corruption_amount)
	else:
		push_warning("[Pedestal] El controller no tiene método add_corruption_step")
