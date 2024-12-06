extends CharacterBody3D

# Variables configurables
@export var detection_range: float = 10.0  # Rango de detección del jugador
@export var speed: float = 3.0  # Velocidad de movimiento
@export var boosted_speed: float = 6.0  # Velocidad aumentada temporalmente
@export var boost_duration: float = 2.0  # Duración del aumento de velocidad en segundos

# Referencias de nodos
@onready var player: CharacterBody3D = null  # Referencia al jugador
@onready var detection_area: Area3D = $DetectionArea  # Área de detección
@onready var boost_timer: Timer = $BoostTimer  # Temporizador para la velocidad aumentada
@onready var boost_sound: AudioStreamPlayer3D = $BoostSound  # Sonido de boost

# Variables internas
var chasing_player: bool = false
var is_boosted: bool = false  # Estado de velocidad aumentada

func _ready():
	# Asegurarse de que la referencia al jugador esté configurada
	if not player:
		player = get_tree().current_scene.get_node("Player") as CharacterBody3D
		if player == null:
			print("Error: No se pudo encontrar el nodo 'Player' en la escena.")
	
	# Conectar señales
	detection_area.connect("area_entered", Callable(self, "_on_player_detected"))
	boost_timer.connect("timeout", Callable(self, "_end_boost"))

func _physics_process(delta):
	_check_player_detection()

	if chasing_player and player:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		velocity = direction * (boosted_speed if is_boosted else speed)  # Usar velocidad aumentada si está en boost
		move_and_slide()

		if global_transform.origin.distance_to(player.global_transform.origin) <= 1.0:
			_on_player_touched()

func _check_player_detection():
	if player:
		var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
		chasing_player = distance_to_player <= detection_range

		# Mensaje para depuración
		print("Distancia al jugador: %.2f, Persiguiendo: %s" % [distance_to_player, chasing_player])

func _on_player_touched():
	print("El enemigo ha tocado al jugador. Game Over!")
	get_tree().change_scene_to_file("res://Pantallas/Game_Over.tscn")  # Asegúrate de que la ruta sea correcta

func _on_player_detected(area):
	if area == player:
		print("Jugador detectado dentro del área de detección")
		chasing_player = true
		_start_boost()

# Función para iniciar el boost
func _start_boost():
	if not is_boosted:
		print("Boost activado: aumentando velocidad.")
		is_boosted = true
		boost_timer.start(boost_duration)  # Inicia el temporizador para el boost

		# Reproducir sonido del boost
		if boost_sound.playing:
			boost_sound.stop()  # Asegurar que no se solape el sonido
		boost_sound.play()
	else:
		print("El boost ya está activo.")

# Función para terminar el boost
func _end_boost():
	print("Boost finalizado: velocidad normal.")
	is_boosted = false
