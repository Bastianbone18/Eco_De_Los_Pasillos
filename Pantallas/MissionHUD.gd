extends CanvasLayer
class_name MissionHUD

@onready var root: Control = $Root
@onready var timer_label: Label = $Root/TopCenter/TimerLabel
@onready var bottom_left: HBoxContainer = $Root/BottomLeft
@onready var sigil_icon: TextureRect = $Root/BottomLeft/SigilIcon
@onready var lights_label: Label = $Root/BottomLeft/LightsCountLabel

@export var light_manager_path: NodePath
var _lm: Node = null

# ✅ TRANSICIÓN CON PANTALLA DE CARGA
@export var loading_screen_path: String = "res://Pantallas/PantallaCarga.tscn"
@export var next_world_scene_path: String = "res://Modelos_Blender/TerrenoMundo2/Mundo2.tscn"
@export var next_world_checkpoint_id: String = "InicioLv2"
@export var autosave_before_loading: bool = true

@export var next_world_loading_key: String = "mundo2"
@export var next_world_loading_text: String = "Cargando Mundo 2..."
@export var next_world_loading_wait: float = 1.3

# ✅ FIX: evita el bug 13/14 en HUD
@export var override_total_lights: int = 0 # 0 = usar lo del LightManager, >0 = forzar (ej 14)

var _active: bool = false
var _total_lights: int = 0
var _total_time: float = 1.0
var _time_left: float = 0.0
var _danger_ratio: float = 0.0
var _found: int = 0

@export var fade_in_time: float = 0.20
@export var fade_out_time: float = 0.15

@export var safe_color: Color = Color("eacf8e")
@export var warn_color: Color = Color("c89a4a")
@export var danger_color: Color = Color("8b2e2e")

@export var frenzy_start_seconds: float = 12.0
@export var panic_start_seconds: float = 6.0

@export var pulse_scale_safe: float = 1.00
@export var pulse_scale_warn: float = 1.04
@export var pulse_scale_panic: float = 1.08

@export var jitter_px_warn: float = 0.6
@export var jitter_px_panic: float = 1.4

var _pulse_tween: Tween = null
var _fade_tween: Tween = null

var _base_timer_pos: Vector2
var _base_bottom_pos: Vector2

var _closing: bool = false
var _transitioning: bool = false

func _ready() -> void:
	visible = true
	root.modulate.a = 0.0
	_active = false

	_base_timer_pos = timer_label.position
	_base_bottom_pos = bottom_left.position

	_resolve_light_manager()
	_connect_signals()

	timer_label.text = "00:00"
	lights_label.text = "0/0"
	_apply_color(safe_color)

func _resolve_light_manager() -> void:
	if light_manager_path != NodePath():
		_lm = get_node_or_null(light_manager_path)
	if _lm == null:
		_lm = get_tree().get_first_node_in_group("light_manager")

func _connect_signals() -> void:
	if _lm == null:
		push_warning("[MissionHUD] LightManager no encontrado. Asigna light_manager_path o ponlo en grupo 'light_manager'.")
		return

	if _lm.has_signal("challenge_started") and not _lm.challenge_started.is_connected(_on_challenge_started):
		_lm.challenge_started.connect(_on_challenge_started)

	if _lm.has_signal("challenge_progress") and not _lm.challenge_progress.is_connected(_on_challenge_progress):
		_lm.challenge_progress.connect(_on_challenge_progress)

	if _lm.has_signal("challenge_ended") and not _lm.challenge_ended.is_connected(_on_challenge_ended):
		_lm.challenge_ended.connect(_on_challenge_ended)

func _on_challenge_started(total_lights: int, total_time: float) -> void:
	_closing = false
	_transitioning = false

	visible = true
	root.modulate.a = 0.0

	_active = true

	# ✅ TIPADO EXPLÍCITO (evita Variant)
	var intended_total: int = maxi(1, total_lights)
	if override_total_lights > 0:
		intended_total = override_total_lights

	_total_lights = intended_total
	_total_time = maxf(0.01, total_time)

	_found = 0
	_time_left = _total_time
	_danger_ratio = 0.0

	_update_texts()
	_apply_color(safe_color)

	_fade_to(1.0, fade_in_time)
	_start_soft_pulse()

func _on_challenge_progress(time_left: float, total_time: float, found: int, total: int, danger_ratio: float) -> void:
	if not _active or _closing:
		return

	_time_left = maxf(0.0, time_left)
	_total_time = maxf(0.01, total_time)

	# ✅ TIPADO EXPLÍCITO (evita Variant)
	var reported_total: int = maxi(1, total)
	if override_total_lights > 0:
		reported_total = override_total_lights

	_total_lights = maxi(_total_lights, reported_total)

	# ✅ clamp con ints estables
	_found = clampi(found, 0, _total_lights)
	_danger_ratio = clampf(danger_ratio, 0.0, 1.0)

	_update_texts()
	_update_style()

func _on_challenge_ended(success: bool, reason: String) -> void:
	if _transitioning:
		return
	_transitioning = true

	_active = false
	_closing = true
	_stop_pulse()
	_reset_jitter_positions()

	# ✅ FIX: apagar música del puzzle al terminar (pierda o gane)
	MusicManager.reset_puzzle_pressure()
	MusicManager.stop(false)

	_close_then_transition(success)

func _close_then_transition(success: bool) -> void:
	root.modulate.a = 1.0
	_fade_to(0.0, fade_out_time)

	if _fade_tween != null:
		_fade_tween.finished.connect(func() -> void:
			visible = false
			if success:
				_transition_to_next_world()
		, CONNECT_ONE_SHOT)
	else:
		visible = false
		if success:
			_transition_to_next_world()

func _transition_to_next_world() -> void:
	MusicManager.stop(false)

	# 1) destino en GameData
	if GameData.has_method("set_checkpoint"):
		GameData.set_checkpoint(next_world_scene_path, next_world_checkpoint_id)
	else:
		GameData.current_scene_path = next_world_scene_path
		GameData.current_checkpoint_id = next_world_checkpoint_id

	# 2) autosave
	if autosave_before_loading:
		_autosave_now()

	# 3) cargar
	get_tree().change_scene_to_file(loading_screen_path)

func _autosave_now() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_warning("[MissionHUD] No existe /root/SaveManager, no se pudo autosave.")
		return

	if sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		return

	if sm.has_method("save_progress"):
		var slot_id: int = int(GameData.current_slot_id)
		var owner: String = str(GameData.player_name)
		var play_time: float = 0.0
		if GameData.has_method("get_total_survival_time"):
			play_time = float(GameData.get_total_survival_time())

		sm.save_progress(
			slot_id,
			owner,
			play_time,
			str(GameData.current_scene_path),
			str(GameData.current_checkpoint_id),
			bool(GameData.intro_done),
			bool(GameData.has_flashlight),
			bool(GameData.buscar_linterna_done),
			bool(GameData.flashlight_on),
			bool(GameData.hoja_encontrada_done),
			false,
			false
		)

func _update_texts() -> void:
	var seconds_left: int = int(_time_left)
	var mm: int = seconds_left / 60
	var ss: int = seconds_left % 60
	timer_label.text = "%02d:%02d" % [mm, ss]
	lights_label.text = "%d/%d" % [_found, _total_lights]

func _update_style() -> void:
	var c: Color = safe_color
	if _danger_ratio >= 0.66:
		c = danger_color
	elif _danger_ratio >= 0.33:
		c = warn_color

	_apply_color(c)

	var pulse_scale: float = pulse_scale_safe
	var jitter_amt: float = 0.0

	if _time_left <= panic_start_seconds:
		pulse_scale = pulse_scale_panic
		jitter_amt = jitter_px_panic
	elif _time_left <= frenzy_start_seconds:
		pulse_scale = pulse_scale_warn
		jitter_amt = jitter_px_warn

	_set_pulse_strength(pulse_scale)
	_apply_jitter(jitter_amt)

	if _time_left <= panic_start_seconds:
		var flick: float = 0.78 + randf() * 0.22
		root.modulate.a = flick
	else:
		if root.modulate.a > 0.02:
			root.modulate.a = lerpf(root.modulate.a, 1.0, 0.12)

func _apply_color(c: Color) -> void:
	timer_label.modulate = c
	lights_label.modulate = c
	sigil_icon.modulate = Color(c.r, c.g, c.b, 0.80)

func _start_soft_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE * 1.02, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE * 1.00, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_pulse_tween.tween_property(bottom_left, "scale", Vector2.ONE * 1.01, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(bottom_left, "scale", Vector2.ONE * 1.00, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _set_pulse_strength(target_scale: float) -> void:
	timer_label.scale = timer_label.scale.lerp(Vector2.ONE * target_scale, 0.25)

func _apply_jitter(amount_px: float) -> void:
	if amount_px <= 0.0:
		_reset_jitter_positions()
		return

	var jx: float = (randf() * 2.0 - 1.0) * amount_px
	var jy: float = (randf() * 2.0 - 1.0) * amount_px

	timer_label.position = _base_timer_pos + Vector2(round(jx), round(jy))
	bottom_left.position = _base_bottom_pos + Vector2(round(-jx * 0.6), round(jy * 0.6))

func _reset_jitter_positions() -> void:
	timer_label.position = _base_timer_pos
	bottom_left.position = _base_bottom_pos

func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	timer_label.scale = Vector2.ONE
	bottom_left.scale = Vector2.ONE

func _fade_to(alpha: float, t: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(root, "modulate:a", alpha, maxf(0.01, t)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
