extends Area3D

@export var pentagram_manager_path: NodePath
@export var final_message_scene: PackedScene
@export var mission_hud_path: NodePath

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var cilindro_fuego: Node3D = $"../Cilindrodefuego"
@onready var luz_fuego_central: OmniLight3D = $"../LuzFuegoCentral"

var pentagram_manager
var triggered: bool = false
var final_event_started: bool = false
var mensaje_instancia: Node = null
var _zone_enabled: bool = false


func _ready() -> void:
	pentagram_manager = get_node_or_null(pentagram_manager_path)

	# Inicia todo apagado
	collision_shape.set_deferred("disabled", true)

	if is_instance_valid(cilindro_fuego):
		cilindro_fuego.visible = false

	if is_instance_valid(luz_fuego_central):
		luz_fuego_central.visible = false
		luz_fuego_central.light_energy = 0.0

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if pentagram_manager == null:
		return

	if _zone_enabled:
		return

	if pentagram_manager.activados["player"]:
		_enable_portal_zone()


func _enable_portal_zone() -> void:
	_zone_enabled = true

	# Activa área
	collision_shape.set_deferred("disabled", false)

	# Activa cilindro de fuego
	if is_instance_valid(cilindro_fuego):
		cilindro_fuego.visible = true

	# Activa luz central
	if is_instance_valid(luz_fuego_central):
		luz_fuego_central.visible = true
		luz_fuego_central.light_energy = 8.0


func _on_body_entered(body: Node) -> void:
	if triggered or final_event_started:
		return

	if body.name != "Player":
		return

	triggered = true
	_hide_mission_hud()
	call_deferred("start_final_event")


func _on_body_exited(body: Node) -> void:
	if body.name != "Player":
		return

	# Si el evento final ya arrancó, no lo cancelamos
	if final_event_started:
		return

	if is_instance_valid(mensaje_instancia):
		mensaje_instancia.cancelar_evento()

	mensaje_instancia = null
	triggered = false


func start_final_event() -> void:
	if final_event_started:
		return

	final_event_started = true

	print("El pentagrama ha sido completado...")

	collision_shape.set_deferred("disabled", true)

	if MusicManager:
		MusicManager.stop(true)

	var player := get_tree().get_first_node_in_group("Player")
	if player:
		player.set_physics_process(false)

	if final_message_scene:
		mensaje_instancia = final_message_scene.instantiate()

		var current_scene := get_tree().get_current_scene()
		if current_scene:
			current_scene.add_child(mensaje_instancia)
		else:
			push_warning("⚠️ No se encontró current_scene para instanciar el mensaje final")


func _hide_mission_hud() -> void:
	if mission_hud_path == NodePath():
		return

	var hud := get_node_or_null(mission_hud_path)
	if hud == null:
		return

	if hud.has_method("hide_mission"):
		hud.call("hide_mission")
