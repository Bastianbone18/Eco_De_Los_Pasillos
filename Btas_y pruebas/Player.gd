extends CharacterBody3D

# Variables de movimiento
var speed
const WALK_SPEED = 3.4# Velocidad al caminar
const SPRINT_SPEED = 6.0  # Velocidad al correr
const SENSITIVITY = 0.005  # Sensibilidad del mouse

# Variables para el efecto de bobbing
const BOB_FREQ = 1.5  # Frecuencia del efecto de movimiento de cabeza
const BOB_AMP = 0.08  # Amplitud del bobbing
var t_bob = 0.0  # Tiempo para el bobbing

# Variables para el FOV (campo de visión)
const BASE_FOV = 75.0  # FOV base
const FOV_CHANGE = 3.0  # Cambio en el FOV al correr

# Gravedad
var gravity = 9.8  # Fuerza de gravedad

# Variables para stamina
var stamina = 100.0  # Nivel actual de estamina
const MAX_STAMINA = 100.0  # Estamina máxima
const STAMINA_DRAIN = 40.0  # Drenaje por segundo al correr
const STAMINA_RECOVERY = 10.0  # Recuperación por segundo
var can_sprint = true  # Impide correr si la estamina es 0

# Variables para la inclinación de la linterna
const FLASHLIGHT_NORMAL_ROTATION = Vector3(-0.2, 0, 0)  # Rotación normal
const FLASHLIGHT_RUN_ROTATION = Vector3(-1.6, 0.2, 0)  # Rotación al correr
const FLASHLIGHT_SMOOTHNESS = 5.0  # Suavidad de la transición de rotación

# Referencias de nodos
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var raycast : RayCast3D = $Head/Camera3D/RayCast3D
@onready var flashlight = $Head/Camera3D/SpotLight3D
@onready var stamina_bar = $Head/Camera3D/CanvasLayer/Control/StaminaBar
@onready var stamina_exhaust_audio = $StaminaExhaustAudio  # Nodo de audio

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	flashlight.visible = true  # Linterna visible por defecto
	stamina_bar.value = stamina  # Actualizar la barra de estamina al iniciar

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
	elif event is InputEventKey:
		if event.is_action_pressed("toggle_flashlight"):
			toggle_flashlight()
		elif event.is_action_pressed("action_use"):
			process_raycast()

func _physics_process(delta):
	# Añadir gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Sprint y manejo de stamina
	if Input.is_action_pressed("sprint") and stamina > 0 and can_sprint:
		speed = SPRINT_SPEED
		stamina -= STAMINA_DRAIN * delta
		stamina = max(stamina, 0)
		if stamina == 0:
			can_sprint = false
			if not stamina_exhaust_audio.is_playing():
				stamina_exhaust_audio.play()

		# Suavizar la inclinación de la linterna hacia el suelo
		flashlight.rotation = flashlight.rotation.lerp(FLASHLIGHT_RUN_ROTATION, FLASHLIGHT_SMOOTHNESS * delta)
	else:
		speed = WALK_SPEED

		# Recuperación de estamina
		if stamina < 60:
			stamina += STAMINA_RECOVERY * delta * 0.5
		else:
			stamina += STAMINA_RECOVERY * delta
		stamina = min(stamina, MAX_STAMINA)
		if stamina > 60:
			can_sprint = true

		# Restaurar la rotación de la linterna a la posición normal
		flashlight.rotation = flashlight.rotation.lerp(FLASHLIGHT_NORMAL_ROTATION, FLASHLIGHT_SMOOTHNESS * delta)

	# Detener el jadeo si la estamina se recupera por encima de un umbral
	if stamina > 20 and stamina_exhaust_audio.is_playing():
		stamina_exhaust_audio.stop()

	# Actualizar la barra de stamina
	if stamina_bar:
		stamina_bar.value = stamina

	# Movimiento
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

	# Efecto de bobbing de la cabeza
	if is_on_floor():
		t_bob += delta * velocity.length()
	camera.transform.origin = _headbob(t_bob)

	# Cambiar el FOV según la velocidad
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	# Actualizar el movimiento
	move_and_slide()

func toggle_flashlight():
	flashlight.visible = not flashlight.visible  # Alterna la visibilidad de la linterna

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func process_raycast():
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.has_method("action_use"):
			collider.action_use()
			print("Interacción con:", collider)
