extends CharacterBody3D

signal died(cause)

# ==================================================
# ------------------ MOVIMIENTO --------------------
# ==================================================
const WALK_SPEED := 3.2
const SPRINT_SPEED := 6.4
const SENSITIVITY := 0.005
var gravity := 9.8
var speed: float

var sprint_toggled := false

# =========================
# ---- MUD UI FEEDBACK ----
# =========================
@export var stamina_normal_color: Color = Color("#F2D38A")
@export var stamina_mud_color: Color = Color("#3A332C")
@export var mud_threshold: float = 1.05 # >1.05 = en barro

var _stamina_fill_style_left: StyleBoxFlat
var _stamina_fill_style_right: StyleBoxFlat

func _set_stamina_bars_color(c: Color) -> void:
	if _stamina_fill_style_left:
		_stamina_fill_style_left.bg_color = c
	if _stamina_fill_style_right:
		_stamina_fill_style_right.bg_color = c

# =========================
# ---- BUFF TEMPORAL ------
# =========================
var _speed_buff_mult: float = 1.0
var _speed_buff_timer: float = 0.0

# =========================
# -------- DEBUFF ---------
# =========================
var external_speed_mult: float = 1.0
var _slow_timer: float = 0.0

var stamina_drain_mult: float = 1.0

var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

var _light_shake_timer: float = 0.0
var _light_base_energy: float = 0.0

# =========================
# ---- SACRED FX (1.2s) ---
# =========================
@export var sacred_fov_kick: float = 2.2
@export var sacred_fov_in_speed: float = 16.0
@export var sacred_fov_out_speed: float = 10.0

@export var sacred_vhs_boost: float = 0.18
@export var sacred_vhs_in_speed: float = 14.0
@export var sacred_vhs_out_speed: float = 10.0

@export var sacred_warm_boost: float = 0.18

@export var sacred_sfx: AudioStream
@export var sacred_sfx_volume_db: float = -6.0

var _sacred_fx_timer: float = 0.0
var _sacred_fov_add: float = 0.0

var _sacred_vhs_add: float = 0.0
var _sacred_warm_add: float = 0.0
var _sacred_sacred_add: float = 0.0
var _sacred_soft_add: float = 0.0

var _sacred_base_vhs_brightness: float = 0.0
var _sacred_base_vhs_warm: float = 0.0
var _sacred_base_sacred: float = 0.0
var _sacred_base_soft: float = 0.0

@onready var _sacred_audio: AudioStreamPlayer = AudioStreamPlayer.new()

# ==================================================
# ------------------ HEADBOB -----------------------
# ==================================================
const BOB_FREQ := 1.5
const BOB_AMP := 0.08
var t_bob := 0.0

# ==================================================
# -------------------- FOV -------------------------
# ==================================================
const BASE_FOV := 75.0
const FOV_CHANGE := 3.0

# ==================================================
# ------------------ STAMINA -----------------------
# ==================================================
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 30.0
const STAMINA_RECOVERY := 12.0
const STAMINA_BOOST_RECOVERY := STAMINA_RECOVERY * 1.15

var stamina := MAX_STAMINA
var prev_stamina := MAX_STAMINA
var can_sprint := true
var exhausted := false

const UI_FADE_IN_SPEED := 12.0
const UI_FADE_OUT_SPEED := 5.0
const STAMINA_EPS := 0.001

# ==================================================
# ------------------- LINTERNA ---------------------
# ==================================================
var has_flashlight := false

const FLASHLIGHT_NORMAL_ROTATION := Vector3(-0.2, 0, 0)
const FLASHLIGHT_RUN_ROTATION := Vector3(-1.6, 0.2, 0)
const FLASHLIGHT_SMOOTHNESS := 5.0

# ==================================================
# ------------------ ESTADO ------------------------
# ==================================================
var _is_dead := false

# ==================================================
# ------------- FORCED CAMERA LOOK -----------------
# ==================================================
var _force_look := false
var _force_target: Node3D = null
var _force_speed := 6.0
var _camera_locked := false

const PITCH_MIN := deg_to_rad(-40)
const PITCH_MAX := deg_to_rad(60)

# ==================================================
# ------------------ REFERENCIAS -------------------
# ==================================================
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var flashlight = $Head/Camera3D/SpotLight3D

@onready var stamina_ui = $Head/Camera3D/CanvasLayer/Control
@onready var left_stamina_bar = $Head/Camera3D/CanvasLayer/Control/LeftProgressBar
@onready var right_stamina_bar = $Head/Camera3D/CanvasLayer/Control/RightProgressBar
@onready var flashlight_click_sound: AudioStreamPlayer = $FlashlightClickSound

@onready var stamina_exhaust_audio = $StaminaExhaustAudio
@onready var post_fx_material := $CanvasLayer2/vHS.material as ShaderMaterial

@onready var puntero_ui := get_tree().current_scene.find_child("CenterContainer", true, false)

@export var dialogue_resource: DialogueResource
@export var start_title := "start"

# ==================================================
# -------------------- READY -----------------------
# ==================================================
func _ready() -> void:
	print("[Player] LOAD STATE -> intro_done:", GameData.intro_done, "has_flashlight:", GameData.has_flashlight, "flashlight_on:", GameData.flashlight_on)
	print("[Player] instance id:", get_instance_id(), "path:", get_path())

	_light_base_energy = flashlight.light_energy

	# ---- Sacred audio (opcional) ----
	_sacred_audio.bus = "SFX"
	_sacred_audio.volume_db = sacred_sfx_volume_db
	add_child(_sacred_audio)

	# ---- Preparar estilos para cambiar color de stamina (fill) ----
	_setup_stamina_bar_styles()

	# ---- Guardar base del VHS (si existe parámetro) ----
	if post_fx_material:
		if post_fx_material.get_shader_parameter("brightness") != null:
			_sacred_base_vhs_brightness = float(post_fx_material.get_shader_parameter("brightness"))
		else:
			_sacred_base_vhs_brightness = 0.0

		if post_fx_material.get_shader_parameter("warm") != null:
			_sacred_base_vhs_warm = float(post_fx_material.get_shader_parameter("warm"))
		else:
			_sacred_base_vhs_warm = 0.0

		if post_fx_material.get_shader_parameter("sacred") != null:
			_sacred_base_sacred = float(post_fx_material.get_shader_parameter("sacred"))
		else:
			_sacred_base_sacred = 0.0

		if post_fx_material.get_shader_parameter("sacred_soft") != null:
			_sacred_base_soft = float(post_fx_material.get_shader_parameter("sacred_soft"))
		else:
			_sacred_base_soft = 0.0
	else:
		_sacred_base_vhs_brightness = 0.0
		_sacred_base_vhs_warm = 0.0
		_sacred_base_sacred = 0.0
		_sacred_base_soft = 0.0

	var crash_fx := get_tree().current_scene.get_node_or_null("CrashFX")
	if crash_fx and crash_fx.has_signal("crash_finished"):
		await crash_fx.crash_finished

	# ==================================================
	# ✅ DETECTAR MUNDO ACTUAL (por nombre de archivo)
	# ==================================================
	var scene_path: String = get_tree().current_scene.scene_file_path
	var scene_file: String = scene_path.get_file()
	var is_world1: bool = (scene_file == "Mundo1.tscn")
	var is_world2: bool = (scene_file == "Mundo2.tscn")

	# ==================================================
	# ✅ FAILSAFE LINTERNA EN MUNDO 2
	# ==================================================
	if is_world2 and GameData.intro_done and not GameData.has_flashlight:
		print("⚠️ [Player] FAILSAFE: restaurando linterna en Mundo2 (has_flashlight=true)")
		GameData.has_flashlight = true

	# ==================================================
	# ✅ INTRO / DIÁLOGOS POR MUNDO (NO GLOBAL)
	# ==================================================
	if is_world1:
		if not GameData.intro_done:
			print("▶ WORLD1: iniciando Primer_Dialogo")

			var balloon := get_tree().current_scene.get_node_or_null("DialogueBalloon")
			if balloon and balloon.has_method("start"):
				balloon.start(dialogue_resource, start_title)

			await get_tree().create_timer(1.0).timeout

			var balloon_scene := preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
			var balloon_instance := balloon_scene.instantiate()
			get_tree().current_scene.add_child(balloon_instance)

			var dialogue_resource_local: DialogueResource = load("res://Dialogos/Primer_Dialogo.dialogue")
			if balloon_instance and balloon_instance.has_method("start") and dialogue_resource_local:
				balloon_instance.start(dialogue_resource_local, "start")

			GameData.intro_done = true
		else:
			print("⏩ WORLD1: intro_done=true, saltando Primer_Dialogo")

	elif is_world2:
		if not GameData.intro_mundo2_done:
			print("▶ WORLD2: intro pendiente -> la hace Mundo2IntroController")
		else:
			print("⏩ WORLD2: intro ya vista")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ==================================================
	# ✅ SINCRONIZAR LINTERNA DESDE GAMEDATA SIEMPRE
	# ==================================================
	sync_flashlight_from_gamedata()
	await get_tree().process_frame
	sync_flashlight_from_gamedata()

	if stamina_ui:
		stamina_ui.modulate.a = 0.0
	update_stamina_bars()

	# Color normal al iniciar
	_set_stamina_bars_color(stamina_normal_color)

	if puntero_ui:
		if "raycast" in puntero_ui:
			puntero_ui.raycast = raycast
		print("🎯 Raycast asignado al puntero")
	else:
		print("❌ No se encontró CenterContainer")

	GameData.start_survival_timer()
	add_to_group("Player")

# ------------------ Setup UI styleboxes ------------------
func _setup_stamina_bar_styles() -> void:
	_stamina_fill_style_left = null
	_stamina_fill_style_right = null

	if left_stamina_bar:
		var sb = left_stamina_bar.get_theme_stylebox("fill")
		if sb:
			var dup = sb.duplicate()
			if dup is StyleBoxFlat:
				_stamina_fill_style_left = dup
			else:
				_stamina_fill_style_left = StyleBoxFlat.new()
				_stamina_fill_style_left.bg_color = stamina_normal_color
			left_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style_left)

	if right_stamina_bar:
		var sb2 = right_stamina_bar.get_theme_stylebox("fill")
		if sb2:
			var dup2 = sb2.duplicate()
			if dup2 is StyleBoxFlat:
				_stamina_fill_style_right = dup2
			else:
				_stamina_fill_style_right = StyleBoxFlat.new()
				_stamina_fill_style_right.bg_color = stamina_normal_color
			right_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style_right)

# ==================================================
# ----------------- PUBLIC API ----------------------
# ==================================================
func apply_stamina_drain(mult: float) -> void:
	stamina_drain_mult = mult

	# Feedback visual: barro vs normal
	if stamina_drain_mult > mud_threshold:
		_set_stamina_bars_color(stamina_mud_color)
	else:
		_set_stamina_bars_color(stamina_normal_color)

func trigger_camera_shake(duration: float, intensity: float) -> void:
	_shake_timer = duration
	_shake_intensity = intensity

func trigger_light_flicker(duration: float) -> void:
	_light_shake_timer = duration

func apply_external_slow(mult: float, duration: float) -> void:
	external_speed_mult = min(external_speed_mult, mult)
	_slow_timer = max(_slow_timer, duration)
	print("SLOW:", mult, " DUR:", duration)

	# impacto inmediato
	velocity.x *= 0.65
	velocity.z *= 0.65

# ==================================================
# --------- SINCRONIZAR LINTERNA DESDE GAMEDATA -----
# ==================================================
func sync_flashlight_from_gamedata() -> void:
	has_flashlight = bool(GameData.has_flashlight)

	if not has_flashlight:
		GameData.flashlight_on = false

	var on: bool = has_flashlight and bool(GameData.flashlight_on)
	flashlight.visible = on
	flashlight.light_energy = 10.0 if on else 0.0

# ==================================================
# ---------------- FORCED LOOK API ------------------
# ==================================================
func lock_camera_control(lock: bool) -> void:
	_camera_locked = lock

func start_forced_look(target: Node3D, speed_in: float = 6.0) -> void:
	if not target:
		return
	_force_target = target
	_force_speed = speed_in
	_force_look = true

func stop_forced_look() -> void:
	_force_look = false
	_force_target = null

# ==================================================
# ------------------ INPUT -------------------------
# ==================================================
func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		if _camera_locked or _force_look:
			return

		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, PITCH_MIN, PITCH_MAX)

	elif event.is_action_pressed("sprint"):
		sprint_toggled = not sprint_toggled

	elif event.is_action_pressed("toggle_flashlight"):
		toggle_flashlight()
		print("[Player] toggle called by:", get_instance_id(), "GameData.has_flashlight:", GameData.has_flashlight)

	elif event.is_action_pressed("action_use"):
		process_raycast()

# ==================================================
# ------------------ FÍSICAS -----------------------
# ==================================================
func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# =========================
	# SLOW EXTERNO (TELARAÑAS)
	# =========================
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			external_speed_mult = 1.0

	# =========================
	# BUFF DE VELOCIDAD (MEDALLÓN)
	# =========================
	if _speed_buff_timer > 0.0:
		_speed_buff_timer -= delta
		if _speed_buff_timer <= 0.0:
			_speed_buff_timer = 0.0
			_speed_buff_mult = 1.0

	# =========================
	# GRAVEDAD
	# =========================
	if not is_on_floor():
		velocity.y -= gravity * delta

	prev_stamina = stamina
	var wants_sprint := Input.is_action_pressed("sprint") or sprint_toggled

	# Multiplicador final (buff + slow)
	var total_mult := _speed_buff_mult * external_speed_mult

	# =========================
	# STAMINA + SPEED
	# =========================
	if wants_sprint and stamina > 0.0 and can_sprint:
		speed = SPRINT_SPEED * total_mult
		stamina -= (STAMINA_DRAIN * stamina_drain_mult) * delta

		if stamina <= 0.0:
			stamina = 0.0
			can_sprint = false
			exhausted = true
			sprint_toggled = false
			if stamina_exhaust_audio and not stamina_exhaust_audio.is_playing():
				stamina_exhaust_audio.play()

		flashlight.rotation = flashlight.rotation.lerp(
			FLASHLIGHT_RUN_ROTATION, FLASHLIGHT_SMOOTHNESS * delta
		)
	else:
		speed = WALK_SPEED * total_mult

		stamina += (STAMINA_BOOST_RECOVERY if exhausted else STAMINA_RECOVERY) * delta
		stamina = clamp(stamina, 0.0, MAX_STAMINA)

		if stamina > 60.0:
			can_sprint = true
		if stamina >= MAX_STAMINA:
			exhausted = false

		flashlight.rotation = flashlight.rotation.lerp(
			FLASHLIGHT_NORMAL_ROTATION, FLASHLIGHT_SMOOTHNESS * delta
		)

	# =========================
	# UI STAMINA (fade)
	# =========================
	if stamina_ui:
		var ui_active := absf(stamina - prev_stamina) > STAMINA_EPS
		stamina_ui.modulate.a = lerp(
			stamina_ui.modulate.a,
			1.0 if ui_active else 0.0,
			delta * (UI_FADE_IN_SPEED if ui_active else UI_FADE_OUT_SPEED)
		)

	update_stamina_bars()

	# =========================
	# MOVIMIENTO
	# =========================
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	var direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if is_on_floor():
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# =========================
	# HEADBOB
	# =========================
	if is_on_floor():
		t_bob += delta * velocity.length()
		camera.transform.origin = _headbob(t_bob)

	# =========================
	# FOV
	# =========================
	var target_fov: float = BASE_FOV + FOV_CHANGE * float(clamp(velocity.length(), 0.5, float(SPRINT_SPEED) * 2.0))
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	# =========================
	# CAMERA SHAKE
	# =========================
	if _shake_timer > 0.0:
		_shake_timer -= delta

		var offset := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * _shake_intensity

		camera.transform.origin += offset

		if _shake_timer <= 0.0:
			_shake_timer = 0.0

	# =========================
	# LIGHT FLICKER (telaraña)
	# =========================
	if _light_shake_timer > 0.0:
		_light_shake_timer -= delta

		var flicker := randf_range(0.90, 1.0)
		flashlight.light_energy = _light_base_energy * flicker

		if _light_shake_timer <= 0.0:
			_light_shake_timer = 0.0
			flashlight.light_energy = _light_base_energy

	move_and_slide()

# ==================================================
# ------------------ PROCESO -----------------------
# ==================================================
func _process(delta: float) -> void:
	# ===== Sacred FX timer =====
	if _sacred_fx_timer > 0.0:
		_sacred_fx_timer -= delta
		if _sacred_fx_timer < 0.0:
			_sacred_fx_timer = 0.0

	var sacred_on: bool = _sacred_fx_timer > 0.0

	# ===== FOV kick =====
	var target_fov_add: float = sacred_fov_kick if sacred_on else 0.0
	_sacred_fov_add = lerp(
		_sacred_fov_add,
		target_fov_add,
		delta * (sacred_fov_in_speed if target_fov_add > _sacred_fov_add else sacred_fov_out_speed)
	)
	camera.fov += _sacred_fov_add

	# ===== Shader FX =====
	if post_fx_material:
		var screen_size := get_viewport().get_visible_rect().size
		post_fx_material.set_shader_parameter("mouse_pos", get_viewport().get_mouse_position() / screen_size)

		# 1) brightness
		if post_fx_material.get_shader_parameter("brightness") != null:
			var target_brightness_add: float = sacred_vhs_boost if sacred_on else 0.0
			_sacred_vhs_add = lerp(
				_sacred_vhs_add,
				target_brightness_add,
				delta * (sacred_vhs_in_speed if target_brightness_add > _sacred_vhs_add else sacred_vhs_out_speed)
			)
			post_fx_material.set_shader_parameter("brightness", _sacred_base_vhs_brightness + _sacred_vhs_add)

		# 2) warm
		if post_fx_material.get_shader_parameter("warm") != null:
			var target_warm_add: float = sacred_warm_boost if sacred_on else 0.0
			_sacred_warm_add = lerp(
				_sacred_warm_add,
				target_warm_add,
				delta * (sacred_vhs_in_speed if target_warm_add > _sacred_warm_add else sacred_vhs_out_speed)
			)
			post_fx_material.set_shader_parameter("warm", _sacred_base_vhs_warm + _sacred_warm_add)

		# 3) sacred
		if post_fx_material.get_shader_parameter("sacred") != null:
			var target_sacred_add: float = 1.0 if sacred_on else 0.0
			_sacred_sacred_add = lerp(_sacred_sacred_add, target_sacred_add, delta * 10.0)
			post_fx_material.set_shader_parameter("sacred", _sacred_base_sacred + _sacred_sacred_add)

		# 4) sacred_soft
		if post_fx_material.get_shader_parameter("sacred_soft") != null:
			var target_soft_add: float = 1.0 if sacred_on else 0.0
			_sacred_soft_add = lerp(_sacred_soft_add, target_soft_add, delta * 10.0)
			post_fx_material.set_shader_parameter("sacred_soft", _sacred_base_soft + _sacred_soft_add)

	# ===== Forced look =====
	if _force_look and _force_target and _force_target.is_inside_tree():
		var from_pos: Vector3 = head.global_transform.origin
		var to_pos: Vector3 = _force_target.global_transform.origin
		var dir: Vector3 = (to_pos - from_pos)

		var yaw_dir := Vector3(dir.x, 0.0, dir.z)
		if yaw_dir.length() > 0.001:
			yaw_dir = yaw_dir.normalized()
			var target_yaw := atan2(-yaw_dir.x, -yaw_dir.z)
			head.rotation.y = lerp_angle(head.rotation.y, target_yaw, delta * _force_speed)

		var horiz := sqrt(dir.x * dir.x + dir.z * dir.z)
		var target_pitch := -atan2(dir.y, max(horiz, 0.001))
		target_pitch = clamp(target_pitch, PITCH_MIN, PITCH_MAX)
		camera.rotation.x = lerp(camera.rotation.x, target_pitch, delta * _force_speed)

# ==================================================
# ------------------ UTILIDADES --------------------
# ==================================================
func toggle_flashlight() -> void:
	has_flashlight = bool(GameData.has_flashlight)

	if not has_flashlight:
		print("🚫 No tienes linterna aún.")
		return

	if flashlight_click_sound:
		flashlight_click_sound.stop()
		flashlight_click_sound.play()

	var turning_on: bool = not flashlight.visible
	GameData.flashlight_on = turning_on

	if turning_on:
		flashlight.visible = true
		await flashlight_blink()
	else:
		await flashlight_fade_out()

func flashlight_blink() -> void:
	for i in range(3):
		flashlight.light_energy = randf_range(0.3, 3.0)
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout
	flashlight.light_energy = 10.0

func flashlight_fade_out() -> void:
	for i in range(4):
		flashlight.light_energy = randf_range(1.0, 9.0)
		if has_node("FlashlightSparkSound"):
			$FlashlightSparkSound.play()
		await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	flashlight.light_energy = 0.0
	flashlight.visible = false

func _headbob(time: float) -> Vector3:
	return Vector3(
		cos(time * BOB_FREQ / 2.0) * BOB_AMP,
		sin(time * BOB_FREQ) * BOB_AMP,
		0
	)

# ===== API para pickups =====
func add_stamina(amount: float) -> void:
	stamina = clamp(stamina + amount, 0.0, MAX_STAMINA)
	update_stamina_bars()

func apply_speed_buff(multiplier: float, duration: float) -> void:
	_speed_buff_mult = maxf(1.0, multiplier)
	_speed_buff_timer = maxf(0.0, duration)

# ===== Sacred feedback =====
func play_sacred_feedback(duration: float = 1.2) -> void:
	_sacred_fx_timer = maxf(_sacred_fx_timer, duration)

	if post_fx_material:
		var b = post_fx_material.get_shader_parameter("brightness")
		var w = post_fx_material.get_shader_parameter("warm")
		var sc = post_fx_material.get_shader_parameter("sacred")
		var ss = post_fx_material.get_shader_parameter("sacred_soft")
		print("SACRED ON | brightness:", b, " warm:", w, " sacred:", sc, " soft:", ss)
	else:
		print("SACRED ON | post_fx_material = null")

	if sacred_sfx:
		_sacred_audio.stream = sacred_sfx
		_sacred_audio.stop()
		_sacred_audio.play()

func process_raycast() -> void:
	if not raycast or not raycast.is_colliding():
		return

	var collider = raycast.get_collider()

	if collider and collider.has_method("action_use"):
		collider.action_use()
	elif collider and collider.has_meta("interactable_owner"):
		var owner = collider.get_meta("interactable_owner")
		if owner and owner.has_method("action_use"):
			owner.action_use()

	

func update_stamina_bars() -> void:
	if left_stamina_bar:
		left_stamina_bar.value = stamina
	if right_stamina_bar:
		right_stamina_bar.value = stamina

func tiene_linterna() -> bool:
	return has_flashlight

# ==================================================
# -------------------- MUERTE ----------------------
# ==================================================
func die(cause := "") -> void:
	if _is_dead:
		return

	_is_dead = true
	GameData.stop_survival_timer()
	emit_signal("died", cause)
	get_tree().change_scene_to_file("res://Pantallas/Game_over.tscn")
