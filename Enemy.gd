extends CharacterBody3D

# Variables configurables
@export var detection_range: float = 12.0
@export var speed: float = 3.0
@export var boosted_speed: float = 6.5
@export var boost_duration: float = 1.5
@export var boost_interval: float = 10.0

# Referencias de nodos
@onready var player: CharacterBody3D = null
@onready var boost_sound: AudioStreamPlayer3D = $BoostSound

# Variables internas
var chasing_player: bool = false
var is_boosted: bool = false
var tiempo_para_boost: float = boost_interval
var has_touched_player: bool = false

func _ready():
	player = get_tree().current_scene.get_node("Player") as CharacterBody3D
	if player == null:
		print("Error: No se encontró el nodo 'Player' en la escena.")

func _physics_process(delta):
	if has_touched_player:
		return  # Si ya tocó al jugador, no hacer nada más

	tiempo_para_boost -= delta

	if chasing_player and tiempo_para_boost <= 0.0:
		_activate_boost()
		tiempo_para_boost = boost_interval

	_check_player_detection()

	if chasing_player and player:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		velocity = direction * (boosted_speed if is_boosted else speed)
		move_and_slide()

		if global_transform.origin.distance_to(player.global_transform.origin) <= 1.0:
			_on_player_touched()

func _check_player_detection():
	if player:
		var distance = global_transform.origin.distance_to(player.global_transform.origin)
		chasing_player = distance <= detection_range

		if not chasing_player and boost_sound and boost_sound.playing:
			boost_sound.stop()

		print("Distancia al jugador: %.2f, Persiguiendo: %s" % [distance, chasing_player])

func _on_player_touched():
	if has_touched_player:
		return

	has_touched_player = true  # Detener al enemigo en el siguiente frame
	velocity = Vector3.ZERO  # Frenar movimiento inmediato
	print("El enemigo ha tocado al jugador. Mostrando jumpscare...")

	if GameData.has_method("stop_survival_timer"):
		GameData.stop_survival_timer()
	else:
		print("Advertencia: GameData no tiene el método 'stop_survival_timer'.")

	var jumpscare_scene_resource = preload("res://Cinematicas/jumpscare.tscn")
	var jumpscare_scene = jumpscare_scene_resource.instantiate()
	get_tree().current_scene.add_child(jumpscare_scene)

	if jumpscare_scene.has_method("play_jumpscare"):
		jumpscare_scene.play_jumpscare()
	else:
		print("Advertencia: La escena de jumpscare no tiene el método 'play_jumpscare'.")

func _activate_boost():
	print("Boost activado.")
	is_boosted = true

	if boost_sound and chasing_player:
		if boost_sound.playing:
			boost_sound.stop()
		boost_sound.play()
	else:
		print("Advertencia: Nodo 'BoostSound' no encontrado o no se está persiguiendo al jugador.")

	_deactivate_boost_after_time()

func _deactivate_boost_after_time():
	await get_tree().create_timer(boost_duration).timeout
	is_boosted = false

	if boost_sound and boost_sound.playing:
		boost_sound.stop()

	print("Boost desactivado.")
