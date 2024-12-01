extends CharacterBody3D

# Variables configurables
@export var detection_range: float = 10.0  # Rango de detección del jugador
@export var speed: float = 3.0  # Velocidad de movimiento

# Referencias de nodos
@onready var player: CharacterBody3D = null  # Referencia al jugador

# Variables internas
var chasing_player: bool = false

func _ready():
	# Asegurarse de que la referencia al jugador esté configurada
	if not player:
		# Buscar al jugador en la escena por su nombre
		player = get_tree().current_scene.get_node("Player") as CharacterBody3D
		if player == null:
			print("Error: No se pudo encontrar el nodo 'Player' en la escena.")

func _physics_process(delta):
	# Verificar si el jugador está en rango de detección
	_check_player_detection()

	# Si el enemigo está persiguiendo al jugador
	if chasing_player and player:
		# Calcular la dirección hacia el jugador
		var direction = (player.global_transform.origin - global_transform.origin).normalized()

		# Mover al enemigo hacia el jugador
		velocity = direction * speed

		# Mover al enemigo usando move_and_slide()
		move_and_slide()

func _check_player_detection():
	# Verificar si el jugador está dentro del rango de detección
	if player:
		var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
		chasing_player = distance_to_player <= detection_range
