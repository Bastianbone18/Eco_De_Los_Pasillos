extends Node3D

# ==================================================
# ------------------ REFERENCIAS -------------------
# ==================================================
@export var mesh_to_hide_path: NodePath
@export var proximity_area_path: NodePath = ^"ProximityArea3D"
@export var interact_area_path: NodePath = ^"Area3D"
@export var omni_light_path: NodePath = ^"OmniLight3D"
@export var audio_player_path: NodePath = ^"AudioStreamPlayer3D"

@onready var mesh_to_hide: Node3D = get_node_or_null(mesh_to_hide_path) as Node3D
@onready var area: Area3D = get_node_or_null(interact_area_path) as Area3D
@onready var proximity_area: Area3D = get_node_or_null(proximity_area_path) as Area3D
@onready var omni_light: OmniLight3D = get_node_or_null(omni_light_path) as OmniLight3D
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null(audio_player_path) as AudioStreamPlayer3D

# Escena 2D de la foto
@export var foto_anim_scene: PackedScene = preload("res://PNG_OBJETOS/FotoAnimacion.tscn")

# Diálogo
@export var dialogue_path: String = "res://Dialogos/FotoSueaño.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

# Nodo del mundo al que avisaremos que ya puede iniciar el padre
@export var mundo3_path: NodePath

# Delay antes de activar al padre después de terminar el diálogo
@export var padre_start_delay: float = 3.0

# Nombre del nodo de diálogo dentro del .dialogue
@export var dialogue_node_name: String = "foto_encontrada"

# Duración de la distorsión hasta llegar al máximo
@export var distortion_duration: float = 9.0

# ==================================================
# ------------- PROXIMIDAD / ATMÓSFERA -------------
# ==================================================
@export var proximity_radius: float = 32.0

@export var min_light_energy: float = 0.22
@export var max_light_energy: float = 2.6
@export var light_color: Color = Color("B89463")
@export var light_range: float = 8.0

@export var pulse_speed_far: float = 1.4
@export var pulse_speed_near: float = 5.2

@export var min_db: float = -14.0
@export var max_db: float = 2.5

@export var min_pitch: float = 0.97
@export var max_pitch: float = 1.04

# ==================================================
# ------------------ ESTADO ------------------------
# ==================================================
var player_inside: bool = false
var player_near: bool = false
var used: bool = false
var puntero_ui: Node = null

var foto_anim_instance: CanvasLayer = null
var balloon_instance: Node = null

var _busy: bool = false
var _pulse_time: float = 0.0
var _player_ref: Node3D = null

# ==================================================
# -------------------- READY -----------------------
# ==================================================
func _ready() -> void:
	# Si ya se usó la foto en este save, no aparece más
	if "foto_familiar_done" in GameData and GameData.foto_familiar_done:
		queue_free()
		return

	if area == null:
		push_error("❌ FotoFamiliar: no se encontró Area3D de interacción")
		return

	area.body_entered.connect(_on_area_entered)
	area.body_exited.connect(_on_area_exited)

	if proximity_area:
		proximity_area.body_entered.connect(_on_proximity_entered)
		proximity_area.body_exited.connect(_on_proximity_exited)

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if not puntero_ui:
		push_warning("⚠️ No se encontró CenterContainer para el puntero")

	if mesh_to_hide == null:
		push_warning("⚠️ FotoFamiliar: mesh_to_hide_path no apunta a ningún nodo visual")

	if omni_light:
		omni_light.light_energy = min_light_energy
		omni_light.light_color = light_color
		omni_light.omni_range = light_range
		omni_light.shadow_enabled = false

	if audio_player:
		audio_player.bus = "Atmosfera"
		audio_player.volume_db = min_db
		audio_player.pitch_scale = min_pitch
		audio_player.playing = false
		audio_player.max_distance = 22.0
		audio_player.unit_size = 1.0

# ==================================================
# ------------------ AREA EVENTS -------------------
# ==================================================
func _on_area_entered(body: Node) -> void:
	if used or _busy:
		return

	if body.is_in_group("Player"):
		player_inside = true
		if puntero_ui and puntero_ui.has_method("mostrar_puntero"):
			puntero_ui.mostrar_puntero()

func _on_area_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_inside = false
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()

# ==================================================
# --------------- PROXIMITY EVENTS -----------------
# ==================================================
func _on_proximity_entered(body: Node) -> void:
	if used or _busy:
		return

	if body.is_in_group("Player"):
		player_near = true
		_player_ref = body as Node3D

		if audio_player and not audio_player.playing:
			audio_player.play()

func _on_proximity_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_near = false
		_player_ref = null

# ==================================================
# ------------------ PROCESO -----------------------
# ==================================================
func _process(delta: float) -> void:
	_update_proximity_effect(delta)

	if used or _busy or not player_inside:
		return

	if Input.is_action_just_pressed("action_use"):
		_interactuar()

# ==================================================
# ----------- EFECTO VIVO DE PROXIMIDAD ------------
# ==================================================
func _update_proximity_effect(delta: float) -> void:
	if omni_light == null and audio_player == null:
		return

	var target_volume: float = min_db
	var target_energy: float = min_light_energy
	var target_pitch: float = min_pitch
	var pulse_amount: float = 0.0
	var pulse_speed: float = pulse_speed_far

	if player_near and _player_ref and not used and not _busy:
		var dist: float = global_position.distance_to(_player_ref.global_position)
		var t: float = 1.0 - clampf(dist / proximity_radius, 0.0, 1.0)

		target_volume = lerpf(min_db, max_db, t)
		target_energy = lerpf(min_light_energy, max_light_energy, t)
		target_pitch = lerpf(min_pitch, max_pitch, t)

		pulse_amount = lerpf(0.05, 0.45, t)
		pulse_speed = lerpf(pulse_speed_far, pulse_speed_near, t)

	_pulse_time += delta * pulse_speed
	var pulse: float = sin(_pulse_time) * pulse_amount

	if omni_light:
		var final_energy: float = maxf(0.0, target_energy + pulse)
		omni_light.light_energy = lerpf(omni_light.light_energy, final_energy, delta * 6.0)

	if audio_player:
		audio_player.volume_db = lerpf(audio_player.volume_db, target_volume, delta * 6.5)
		
		audio_player.pitch_scale = lerpf(audio_player.pitch_scale, target_pitch + pulse * 0.04, delta * 3.0)

		if not player_near and audio_player.playing and audio_player.volume_db <= (min_db + 0.5):
			audio_player.stop()

# ==================================================
# ------------------ INTERACT ----------------------
# ==================================================
func _interactuar() -> void:
	if used or _busy:
		return

	_busy = true
	used = true

	# Desactiva áreas sin romper flushing queries
	if area:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

	if proximity_area:
		proximity_area.set_deferred("monitoring", false)
		proximity_area.set_deferred("monitorable", false)

	player_near = false
	_player_ref = null

	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	if audio_player and audio_player.playing:
		audio_player.stop()

	if omni_light:
		omni_light.light_energy = min_light_energy

	if mesh_to_hide and "visible" in mesh_to_hide:
		mesh_to_hide.visible = false

	_mostrar_animacion_foto()
	_iniciar_dialogo()

# ==================================================
# ------------------ ANIMACIÓN 2D ------------------
# ==================================================
func _mostrar_animacion_foto() -> void:
	if not foto_anim_scene:
		push_error("❌ foto_anim_scene es null")
		return

	foto_anim_instance = foto_anim_scene.instantiate() as CanvasLayer
	get_tree().get_current_scene().add_child(foto_anim_instance)

	if foto_anim_instance.has_method("set_distortion_duration"):
		foto_anim_instance.call("set_distortion_duration", distortion_duration)

	if foto_anim_instance.has_method("start_effect"):
		foto_anim_instance.call("start_effect")

	var anim: AnimatedSprite2D = foto_anim_instance.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		anim.speed_scale = 1.0
		anim.frame = 0

		if anim.sprite_frames and anim.sprite_frames.has_animation("Mostrar"):
			anim.play("Mostrar")
		else:
			anim.play()

# ==================================================
# ------------------ DIÁLOGO -----------------------
# ==================================================
func _iniciar_dialogo() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_on_dialogo_foto_terminado()
		return

	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_on_dialogo_foto_terminado()
		return

	var dialogue_resource: Resource = load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogo_foto_terminado):
			balloon_instance.dialogue_finished.connect(_on_dialogo_foto_terminado)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_on_dialogo_foto_terminado()
		return

	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, dialogue_node_name)
	else:
		push_error("❌ balloon_instance no tiene método start()")
		_on_dialogo_foto_terminado()

# ==================================================
# ------------------ FINAL -------------------------
# ==================================================
func _on_dialogo_foto_terminado() -> void:
	if "foto_familiar_done" in GameData:
		GameData.foto_familiar_done = true

	if foto_anim_instance and foto_anim_instance.has_method("stop_effect"):
		foto_anim_instance.call("stop_effect")

	if foto_anim_instance and foto_anim_instance.is_inside_tree():
		foto_anim_instance.queue_free()
		foto_anim_instance = null

	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
		balloon_instance = null

	if audio_player and audio_player.playing:
		audio_player.stop()

	if omni_light:
		omni_light.light_energy = min_light_energy

	await get_tree().create_timer(padre_start_delay).timeout
	_activar_padre_en_mundo3()

	queue_free()

func _activar_padre_en_mundo3() -> void:
	var mundo3: Node = null

	if mundo3_path != NodePath():
		mundo3 = get_node_or_null(mundo3_path)
	else:
		var current_scene: Node = get_tree().get_current_scene()
		if current_scene and current_scene.has_method("activar_padre_por_objeto"):
			mundo3 = current_scene

	if mundo3 == null:
		push_warning("⚠️ No se encontró Mundo3 para activar al padre")
		return

	if mundo3.has_method("activar_padre_por_objeto"):
		mundo3.activar_padre_por_objeto()
	else:
		push_warning("⚠️ El nodo Mundo3 no tiene método activar_padre_por_objeto()")
