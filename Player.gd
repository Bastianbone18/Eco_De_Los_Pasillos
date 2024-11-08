extends CharacterBody3D

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const SENSITIVITY = 0.004

# Variables para el efecto de bobbing
const BOB_FREQ = 1.5  # Reducido para un movimiento más suave
const BOB_AMP = 0.04  # Reducido para menos movimiento
var t_bob = 0.0  # Inicialización de t_bob a 0

# Variables para el FOV
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Gravedad
var gravity = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var raycast : RayCast3D = $Head/Camera3D/RayCast3D
@onready var flashlight = $Head/Camera3D/SpotLight3D  # Asegúrate de que esta ruta sea correcta

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	flashlight.visible = true  # Comienza encendida

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
	elif event is InputEventKey:
		if event.is_action_pressed("toggle_flashlight"):
			toggle_flashlight()

func _physics_process(delta):
	# Añadir gravedad.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Manejar Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Obtener la dirección de entrada y manejar el movimiento.
	var input_dir = Vector2(
		(1 if Input.is_action_pressed("move_right") else 0) - (1 if Input.is_action_pressed("move_left") else 0),
		(1 if Input.is_action_pressed("move_down") else 0) - (1 if Input.is_action_pressed("move_up") else 0)
	)

	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# Efecto de bobbing de la cabeza.
	if is_on_floor():
		t_bob += delta * velocity.length()
	camera.transform.origin = _headbob(t_bob)

	# Cambiar el FOV según la velocidad.
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func toggle_flashlight():
	flashlight.visible = not flashlight.visible

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
