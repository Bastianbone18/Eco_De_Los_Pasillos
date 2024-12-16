extends CharacterBody3D

# Variables configurables
@export var detection_range: float = 12.0  # Rango de detección del jugador
@export var speed: float = 3.0  # Velocidad normal del enemigo
@export var boosted_speed: float = 6.5  # Velocidad aumentada durante el boost
@export var boost_duration: float = 1.5  # Duración del boost
@export var boost_interval: float = 10.0  # Intervalo de tiempo para activar el boost automáticamente

# Referencias de nodos
@onready var player: CharacterBody3D = null  # Referencia al jugador
@onready var boost_sound: AudioStreamPlayer3D = $BoostSound  # Nodo de sonido del boost

# Variables internas
var chasing_player: bool = false
var is_boosted: bool = false
var tiempo_para_boost = boost_interval  # Tiempo restante para el próximo boost

# Cargar la escena de Game Over
var game_over_scene = preload("res://Pantallas/Game_Over.tscn")

func _ready():
	# Buscar al jugador en la escena
	player = get_tree().current_scene.get_node("Player") as CharacterBody3D
	if player == null:
		print("Error: No se encontró el nodo 'Player' en la escena.")

func _physics_process(delta):
	tiempo_para_boost -= delta  # Reducir tiempo restante para el próximo boost

	if tiempo_para_boost <= 0.0:
		_activate_boost()
		tiempo_para_boost = boost_interval  # Reiniciar el temporizador para el próximo boost

	# Detectar al jugador y perseguirlo
	_check_player_detection()

	if chasing_player and player:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		velocity = direction * (boosted_speed if is_boosted else speed)
		move_and_slide()

		# Si el enemigo alcanza al jugador
		if global_transform.origin.distance_to(player.global_transform.origin) <= 1.0:
			_on_player_touched()

func _check_player_detection():
	if player:
		var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
		chasing_player = distance_to_player <= detection_range

		# Depuración
		print("Distancia al jugador: %.2f, Persiguiendo: %s" % [distance_to_player, chasing_player])

func _on_player_touched():
	print("El enemigo ha tocado al jugador. Cambiando a pantalla de Game Over...")
	
	# Cambiar a la escena de Game Over usando el método correcto
	get_tree().change_scene_to_file("res://Pantallas/Game_Over.tscn")

func _activate_boost():
	print("Boost activado.")
	is_boosted = true

	# Reproducir sonido del boost
	if boost_sound:
		if boost_sound.playing:
			boost_sound.stop()  # Detener sonido previo
		boost_sound.play()
		print("Reproduciendo sonido de boost.")
	else:
		print("Advertencia: nodo 'BoostSound' no encontrado o no tiene audio configurado.")

	# Desactivar el boost después de un tiempo
	_deactivate_boost_after_time()

func _deactivate_boost_after_time():
	# Usar un temporizador para desactivar el boost
	await get_tree().create_timer(boost_duration).timeout
	is_boosted = false
	print("Boost desactivado.")
