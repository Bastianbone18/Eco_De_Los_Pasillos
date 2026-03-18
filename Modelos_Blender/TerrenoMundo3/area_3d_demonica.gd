extends Area3D

@export var pentagram_manager_path: NodePath
@export var final_message_scene: PackedScene

var pentagram_manager
var triggered := false
var mensaje_instancia = null


func _ready():

	pentagram_manager = get_node_or_null(pentagram_manager_path)

	$CollisionShape3D.disabled = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta):

	if pentagram_manager == null:
		return

	if pentagram_manager.activados["player"]:
		$CollisionShape3D.disabled = false


func _on_body_entered(body):

	if triggered:
		return

	if body.name != "Player":
		return

	triggered = true

	start_final_event()


func _on_body_exited(body):

	if body.name != "Player":
		return

	if is_instance_valid(mensaje_instancia):
		mensaje_instancia.cancelar_evento()

	mensaje_instancia = null
	triggered = false


func start_final_event():

	print("El pentagrama ha sido completado...")

	$CollisionShape3D.disabled = true

	if MusicManager:
		MusicManager.stop(true)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)

	if final_message_scene:

		mensaje_instancia = final_message_scene.instantiate()

		get_tree().root.add_child(mensaje_instancia)
