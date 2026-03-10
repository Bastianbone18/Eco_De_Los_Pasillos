extends Node3D
class_name AngelStatuaInteract

@onready var area: Area3D = $Area3D
@onready var collision: CollisionShape3D = $Area3D/CollisionShape3D

@export var red_spot_path: NodePath
@export var red_fill_omni_path: NodePath

@export var dialogue_path: String = "res://Dialogos/Estatua.dialogue"
@export var balloon_scene: PackedScene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
const DIALOGUE_NODE := "angel_statua"

# ================= AUDIO HEARTBEAT (3D) =================
@export var heartbeat_player_path: NodePath
@onready var hb_player: AudioStreamPlayer3D = get_node_or_null(heartbeat_player_path) as AudioStreamPlayer3D

@export var hb_ramp_seconds: float = 10.0        # cuánto tarda en “ponerse intenso” durante diálogo
@export var hb_pitch_min: float = 0.90          # lento (inicio)
@export var hb_pitch_max: float = 1.35          # rápido (final)
@export var hb_vol_min_db: float = -28.0        # bajito (inicio)
@export var hb_vol_max_db: float = -7.0         # fuerte (final)

@export var hb_hold_after_end_seconds: float = 2.0  # mantener después del diálogo
@export var hb_fade_out_time: float = 1.3           # fade out suave

var _hb_audio_active: bool = false
var _hb_audio_t: float = 0.0
var _hb_audio_base: float = 0.0
var _hb_audio_fade_tween: Tween = null

# ================= GAMEPLAY =================
@export var require_doll_to_spawn: bool = true

# ============ HEARTBEAT LIGHTS (tu sistema actual) ============
var _hb_current: float = 0.0
@export var heartbeat_enabled: bool = true
@export var base_spot_energy: float = 7.5
@export var base_fill_energy: float = 1.2
@export var spot_pulse_amp: float = 1.25
@export var fill_pulse_amp: float = 0.35
@export var bpm_base: float = 48.0
@export var bpm_end: float = 92.0
@export var lub_width: float = 0.055
@export var dub_delay: float = 0.14
@export var dub_width: float = 0.040
@export var dub_strength: float = 0.55
@export var rest_factor: float = 0.45
@export var ramp_duration: float = 38.0
@export var idle_heartbeat_when_unlocked: bool = true
@export var idle_amp_mult: float = 0.35
@export var jitter_amount: float = 0.015

var _red_spot: SpotLight3D = null
var _red_fill: OmniLight3D = null

var _hb_active: bool = false
var _hb_t: float = 0.0
var _hb_phase_jitter: float = 0.0

var player_inside: bool = false
var used: bool = false
var _busy: bool = false
var _finished: bool = false

var puntero_ui: Node = null
var balloon_instance: Node = null
var anxiety_overlay: AnxietyOverlay = null

var _enabled: bool = true


func _ready() -> void:
	add_to_group("angel_statue")

	anxiety_overlay = get_tree().get_current_scene().find_child("AnxietyOverlay", true, false) as AnxietyOverlay
	used = bool(GameData.angel_statua_done)

	if not area.body_entered.is_connected(_on_area_entered):
		area.body_entered.connect(_on_area_entered)
	if not area.body_exited.is_connected(_on_area_exited):
		area.body_exited.connect(_on_area_exited)

	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)

	if red_spot_path != NodePath(""):
		_red_spot = get_node_or_null(red_spot_path) as SpotLight3D
	if red_fill_omni_path != NodePath(""):
		_red_fill = get_node_or_null(red_fill_omni_path) as OmniLight3D

	_apply_light_energy(base_spot_energy, base_fill_energy)
	_set_heartbeat(false)

	# audio heartbeat arranca apagado
	_hb_set_amount(0.0)
	if hb_player and hb_player.playing:
		hb_player.stop()

	if require_doll_to_spawn and not bool(GameData.muneco_antiguo_done) and not used:
		_set_enabled(false)
	else:
		_set_enabled(true)

	if used:
		_disable_area()
		_set_heartbeat(false)
		return

	if _enabled and idle_heartbeat_when_unlocked and heartbeat_enabled:
		_hb_t = 0.0
		_set_heartbeat(true)


func unlock_after_doll() -> void:
	if used:
		return
	_set_enabled(true)
	if idle_heartbeat_when_unlocked and heartbeat_enabled:
		_hb_t = 0.0
		_set_heartbeat(true)


func _set_enabled(v: bool) -> void:
	_enabled = v
	visible = v

	if area:
		area.monitoring = v
		area.monitorable = v
	if collision:
		collision.disabled = not v

	if not v:
		player_inside = false
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()
		_set_heartbeat(false)


func _on_area_entered(body: Node) -> void:
	if not _enabled or used or _busy:
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


func _process(delta: float) -> void:
	# tu heartbeat de luces
	if _hb_active:
		_update_heartbeat(delta)

	# audio heartbeat (subida mientras diálogo está activo)
	_update_heartbeat_audio(delta)

	if not _enabled or used or _busy or not player_inside:
		return

	if Input.is_action_just_pressed("action_use"):
		_interactuar()


func _interactuar() -> void:
	if used or _busy:
		return

	_busy = true
	used = true
	_disable_area()

	if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
		puntero_ui.ocultar_puntero()

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_start"):
		MusicManager.on_world2_dialogue_start(3, 0.35)

	if heartbeat_enabled:
		_hb_t = 0.0
		_set_heartbeat(true)

	# ✅ audio empieza aquí (igual que shader)
	_hb_audio_begin(0.0)

	_iniciar_dialogo()

	if anxiety_overlay:
		anxiety_overlay.begin_ramp(0.10)


func _disable_area() -> void:
	area.monitoring = false
	area.monitorable = false
	if collision:
		collision.disabled = true


func _iniciar_dialogo() -> void:
	if not ResourceLoader.exists(dialogue_path):
		push_error("❌ No se encontró el diálogo: " + dialogue_path)
		_on_dialogo_terminado()
		return

	if not balloon_scene:
		push_error("❌ balloon_scene es null")
		_on_dialogo_terminado()
		if anxiety_overlay:
			anxiety_overlay.end_ramp()
		return

	var dialogue_resource := load(dialogue_path)

	balloon_instance = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon_instance)

	if balloon_instance.has_signal("dialogue_finished"):
		if not balloon_instance.dialogue_finished.is_connected(_on_dialogo_terminado):
			balloon_instance.dialogue_finished.connect(_on_dialogo_terminado)
	else:
		push_error("❌ balloon.tscn no tiene señal 'dialogue_finished'")
		_on_dialogo_terminado()
		return

	if balloon_instance.has_method("start"):
		balloon_instance.start(dialogue_resource, DIALOGUE_NODE)
	else:
		push_error("❌ balloon_instance no tiene método start()")
		_on_dialogo_terminado()


func _on_dialogo_terminado() -> void:
	if _finished:
		return
	_finished = true

	GameData.angel_statua_done = true

	if MusicManager != null and MusicManager.has_method("set_world2_stage"):
		MusicManager.set_world2_stage(3, 1.0)

	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm and atm.has_method("advance_stage"):
		atm.advance_stage()
	else:
		push_warning("⚠️ No encontré AtmosphereManager en grupo 'atmosphere'")

	if anxiety_overlay:
		anxiety_overlay.end_ramp()

	# ✅ audio: mantener 2s y luego fade out (igual que overlay)
	_hb_audio_end()

	if balloon_instance and balloon_instance.is_inside_tree():
		balloon_instance.queue_free()
	balloon_instance = null

	_busy = false

	if idle_heartbeat_when_unlocked and heartbeat_enabled:
		_hb_t = 0.0
		_set_heartbeat(true)
	else:
		_set_heartbeat(false)
		_apply_light_energy(base_spot_energy, base_fill_energy)

	if MusicManager != null and MusicManager.has_method("on_world2_dialogue_end"):
		MusicManager.on_world2_dialogue_end(3.0, 1.2)

	_autosave_now()


func _autosave_now() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[AngelStatua] Autosave ✅ done=true")


# ===================== AUDIO HEARTBEAT (ramp + hold + fade) =====================
func _hb_audio_begin(start_amount: float = 0.0) -> void:
	if hb_player == null:
		return

	_hb_audio_active = true
	_hb_audio_t = 0.0
	_hb_audio_base = clampf(start_amount, 0.0, 1.0)

	# si había tween de salida, lo matamos
	if _hb_audio_fade_tween and _hb_audio_fade_tween.is_valid():
		_hb_audio_fade_tween.kill()
	_hb_audio_fade_tween = null

	_hb_set_amount(_hb_audio_base)

	if not hb_player.playing:
		hb_player.play()


func _hb_audio_end() -> void:
	# deja de “subir”
	_hb_audio_active = false

	# mantiene un rato como tu shader
	if hb_hold_after_end_seconds > 0.0:
		await get_tree().create_timer(hb_hold_after_end_seconds).timeout

	# luego fade out
	if hb_player == null:
		return

	var from_amt := _hb_get_amount()

	if _hb_audio_fade_tween and _hb_audio_fade_tween.is_valid():
		_hb_audio_fade_tween.kill()

	_hb_audio_fade_tween = create_tween()
	_hb_audio_fade_tween.tween_method(Callable(self, "_hb_set_amount"), from_amt, 0.0, hb_fade_out_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_hb_audio_fade_tween.finished.connect(func ():
		if hb_player and hb_player.playing:
			hb_player.stop()
		_hb_set_amount(0.0)
	)


func _update_heartbeat_audio(delta: float) -> void:
	# solo mientras está activo (durante diálogo)
	if not _hb_audio_active:
		return
	if hb_player == null:
		return
	if not hb_player.playing:
		hb_player.play()

	_hb_audio_t += delta

	var denom := maxf(hb_ramp_seconds, 0.001)
	var p := clampf(_hb_audio_t / denom, 0.0, 1.0)
	# curva tipo pánico (lento -> rápido)
	p = pow(p, 1.8)

	var amt := lerpf(_hb_audio_base, 1.0, p)
	_hb_set_amount(amt)


func _hb_set_amount(a: float) -> void:
	# a = 0..1
	var aa := clampf(a, 0.0, 1.0)
	_hb_current = aa

	if hb_player == null:
		return

	hb_player.pitch_scale = lerp(hb_pitch_min, hb_pitch_max, aa)
	hb_player.volume_db = lerp(hb_vol_min_db, hb_vol_max_db, aa)


func _hb_get_amount() -> float:
	return _hb_current


# ================= HEARTBEAT LIGHTS (tu código) =================
func _set_heartbeat(active: bool) -> void:
	_hb_active = active
	if not active:
		_hb_t = 0.0
		_hb_phase_jitter = 0.0


func _apply_light_energy(spot_e: float, fill_e: float) -> void:
	if _red_spot != null:
		_red_spot.light_energy = max(0.0, spot_e)
	if _red_fill != null:
		_red_fill.light_energy = max(0.0, fill_e)


func _pulse_shape(time_in_cycle: float, center: float, width: float) -> float:
	var x: float = (time_in_cycle - center) / max(0.0001, width)
	return exp(-x * x * 6.0)


func _update_heartbeat(delta: float) -> void:
	_hb_t += delta

	var p: float = 0.0
	if _busy:
		p = clamp(_hb_t / max(0.01, ramp_duration), 0.0, 1.0)

	var bpm: float = lerp(bpm_base, bpm_end, p)
	var cycle: float = 60.0 / max(1.0, bpm)

	var t_in_cycle: float = fposmod(_hb_t + _hb_phase_jitter, cycle)
	if t_in_cycle < delta:
		_hb_phase_jitter = float(randf_range(-jitter_amount, jitter_amount))

	var lub_center: float = 0.06 * cycle
	var dub_center: float = clamp(lub_center + dub_delay, 0.0, cycle)

	var lub: float = _pulse_shape(t_in_cycle, lub_center, lub_width)
	var dub: float = _pulse_shape(t_in_cycle, dub_center, dub_width) * dub_strength

	var pulse: float = clamp(lub + dub, 0.0, 1.0)

	var rest: float = lerp(1.0, 0.78, rest_factor)
	var shaped: float = lerp(rest, 1.0, pulse)

	var amp_mult: float = 1.0
	if not _busy:
		amp_mult = idle_amp_mult

	var spot_e: float = base_spot_energy + (shaped - rest) * (spot_pulse_amp * amp_mult)
	var fill_e: float = base_fill_energy + (shaped - rest) * (fill_pulse_amp * amp_mult)

	spot_e = max(base_spot_energy * 0.55, spot_e)
	fill_e = max(0.0, fill_e)

	_apply_light_energy(spot_e, fill_e)
