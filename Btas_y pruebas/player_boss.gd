extends CharacterBody3D
# class_name PlayerBoss  # opcional

signal died(cause)

# --- MOVIMIENTO (buff del boss) ---
var speed: float
const WALK_SPEED := 3.8
const SPRINT_SPEED := 6.5
const SENSITIVITY := 0.005
var gravity: float = 9.8

# --- HEADBOB ---
const BOB_FREQ := 1.5
const BOB_AMP := 0.08
var t_bob: float = 0.0

# --- FOV ---
const BASE_FOV := 75.0
const FOV_CHANGE := 3.0

# --- STAMINA (más dura y recarga más rápido) ---
var stamina: float = 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 35.0
const STAMINA_RECOVERY := 20.0
const STAMINA_BOOST_RECOVERY := STAMINA_RECOVERY * 1.3
var can_sprint: bool = true
var exhausted: bool = false

# --- STAMINA UI (visible cuando cambia) ---
const UI_FADE_IN_SPEED := 10.0
const UI_FADE_OUT_SPEED := 5.0
const STAMINA_EPS := 0.001
var prev_stamina: float = MAX_STAMINA

# --- REFS (tipadas para evitar Variant) ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/SpotLight3D
@onready var stamina_ui: Control = $Head/Camera3D/CanvasLayer/Control
@onready var left_stamina_bar: Range = $Head/Camera3D/CanvasLayer/Control/LeftProgressBar
@onready var right_stamina_bar: Range = $Head/Camera3D/CanvasLayer/Control/RightProgressBar
@onready var stamina_exhaust_audio: AudioStreamPlayer = $StaminaExhaustAudio

# Estas dos se asignan en _ready() para evitar evaluar rutas inexistentes en onready
var post_fx_material: ShaderMaterial = null
var interact_sound: AudioStreamPlayer = null

var puntero_ui: Node = null
var has_flashlight: bool = true

const FLASHLIGHT_NORMAL_ROTATION := Vector3(-0.2, 0, 0)
const FLASHLIGHT_RUN_ROTATION := Vector3(-1.6, 0.2, 0)
const FLASHLIGHT_SMOOTHNESS := 5.0

# --- VIDA ---
var _is_dead: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Linterna SIEMPRE encendida
	has_flashlight = true
	flashlight.visible = true
	flashlight.light_energy = 10.0
	flashlight.set_deferred("visible", true)

	# UI oculta al inicio (aparecerá cuando cambie la stamina)
	stamina_ui.modulate.a = 0.0
	update_stamina_bars()

	# Asignaciones seguras de nodos opcionales
	if has_node("CanvasLayer2/vHS"):
		post_fx_material = ($CanvasLayer2/vHS.material) as ShaderMaterial
	if has_node("InteractSound"):
		interact_sound = $InteractSound

	# Asignar raycast al puntero (si existe)
	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if puntero_ui != null:
		# Si tu Control expone la propiedad 'raycast', usar set es lo más seguro:
		if puntero_ui.has_method("set"):
			puntero_ui.set("raycast", raycast)

	GameData.start_survival_timer()
	add_to_group("Player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		head.rotate_y(-mm.relative.x * SENSITIVITY)
		camera.rotate_x(-mm.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

	elif event.is_action_pressed("toggle_flashlight"):
		# El boss no apaga la linterna; la reafirmamos encendida
		toggle_flashlight()

	elif event.is_action_pressed("action_use"):
		process_raycast()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- detectar cambio de stamina
	prev_stamina = stamina

	# Sprint / Stamina
	if Input.is_action_pressed("sprint") and stamina > 0.0 and can_sprint:
		speed = SPRINT_SPEED
		stamina = max(stamina - STAMINA_DRAIN * delta, 0.0)

		if stamina == 0.0:
			can_sprint = false
			exhausted = true
			if not stamina_exhaust_audio.is_playing():
				stamina_exhaust_audio.play()

		flashlight.rotation = flashlight.rotation.lerp(FLASHLIGHT_RUN_ROTATION, FLASHLIGHT_SMOOTHNESS * delta)

	else:
		speed = WALK_SPEED

		var rec: float = STAMINA_BOOST_RECOVERY if exhausted else STAMINA_RECOVERY * (0.5 if stamina < 60.0 else 1.0)
		stamina = min(stamina + rec * delta, MAX_STAMINA)

		if stamina > 60.0:
			can_sprint = true
		if stamina >= MAX_STAMINA:
			exhausted = false

		flashlight.rotation = flashlight.rotation.lerp(FLASHLIGHT_NORMAL_ROTATION, FLASHLIGHT_SMOOTHNESS * delta)

	# --- UI de stamina
	var d_stamina: float = stamina - prev_stamina
	var ui_active: bool = absf(d_stamina) > STAMINA_EPS
	if ui_active:
		stamina_ui.modulate.a = lerp(stamina_ui.modulate.a, 1.0, delta * UI_FADE_IN_SPEED)
	else:
		stamina_ui.modulate.a = lerp(stamina_ui.modulate.a, 0.0, delta * UI_FADE_OUT_SPEED)

	update_stamina_bars()

	# Movimiento (tipado explícito para evitar Variant)
	var input_dir: Vector2 = Vector2(
		float(Input.get_action_strength("move_right")) - float(Input.get_action_strength("move_left")),
		float(Input.get_action_strength("move_down")) - float(Input.get_action_strength("move_up"))
	)
	var direction: Vector3 = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if is_on_floor():
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 7.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# Headbob + FOV (tipado explícito)
	if is_on_floor():
		t_bob += delta * velocity.length()
		camera.transform.origin = _headbob(t_bob)
	else:
		camera.transform.origin = Vector3.ZERO

	var velocity_clamped: float = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2.0)
	var target_fov: float = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()


func _process(delta: float) -> void:
	if post_fx_material != null:
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		var mouse_pos: Vector2 = get_viewport().get_mouse_position() / screen_size
		post_fx_material.set_shader_parameter("mouse_pos", mouse_pos)


# ----------------- UTILIDADES -----------------

func toggle_flashlight() -> void:
	flashlight.visible = true
	flashlight.light_energy = max(flashlight.light_energy, 10.0)

func flashlight_blink() -> void:
	flashlight.light_energy = 10.0

func flashlight_fade_out() -> void:
	# No se apaga en el boss
	flashlight.visible = true
	flashlight.light_energy = 10.0

func _headbob(time: float) -> Vector3:
	var pos: Vector3 = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return pos

func process_raycast() -> void:
	if not raycast:
		return
	if raycast.is_colliding():
		var collider: Object = raycast.get_collider()
		if collider and collider.has_method("action_use"):
			if interact_sound:
				interact_sound.play()
			collider.action_use()
			return

		# ⚠️ Aquí estaba el Variant: tipa 'owner' explícitamente
		var owner: Object = collider.get_meta("interactable_owner") as Object
		if owner and owner.has_method("action_use"):
			if interact_sound:
				interact_sound.play()
			owner.action_use()


func update_stamina_bars() -> void:
	if left_stamina_bar:
		left_stamina_bar.value = stamina
	if right_stamina_bar:
		right_stamina_bar.value = stamina

func tiene_linterna() -> bool:
	return true

# -------- Muerte centralizada ----------
func die(cause: String = "") -> void:
	if _is_dead:
		return
	_is_dead = true
	GameData.stop_survival_timer()
	emit_signal("died", cause)
	get_tree().change_scene_to_file("res://Pantallas/Game_over.tscn")
