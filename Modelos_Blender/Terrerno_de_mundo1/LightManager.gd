# LightManager.gd
extends Node
class_name LightManager

# ==========================================================
# ✅ SIGNALS DEL CHALLENGE
# ==========================================================
signal challenge_started(total_lights: int, total_time: float)
signal challenge_progress(time_left: float, total_time: float, found: int, total: int, danger_ratio: float)
signal challenge_ended(success: bool, reason: String)

@export var lights_container_path: NodePath   # ForestLights
@export var time_per_light: float = 6.0
@export var total_time: float = 45.0

@export var warning_threshold: float = 0.4
@export var danger_threshold: float = 0.2

@export var overlay_intro_soft_duration: float = 1.2
@export var auto_start: bool = false
@export var start_only_after_dialogue: bool = true
@export var game_over_scene: PackedScene

# ------------------------------
# ✅ Audio de victoria
# ------------------------------
@export var victory_audio_path: NodePath = NodePath("../VictoryChoir")
@export var victory_volume_db: float = -16.0
@export var victory_pitch: float = 0.97
@export var victory_delay: float = 1.45

var _victory_audio: AudioStreamPlayer = null

var _overlay: DarknessOverlay = null

# ==========================================================
# ✅ Luces
# ==========================================================
var _lights: Array[GuidingLight] = []
var _end_light: GuidingLight = null
var _sequence: Array[GuidingLight] = []
var _collectible_total: int = 0

var _index: int = 0
var _light_timer: float = 0.0
var _global_timer: float = 0.0
var _active: bool = false
var _game_over_open: bool = false

# ==========================================================
# ✅ IMPORTANTE: TRANSICIÓN DESACTIVADA AQUÍ
# MissionHUD será el único que cambia de escena
# ==========================================================
@export var go_to_next_level_on_success: bool = false

func _ready() -> void:
	_cache_lights()
	call_deferred("_resolve_overlay")
	call_deferred("_resolve_victory_audio")

	if auto_start and not start_only_after_dialogue:
		start_challenge()

func _resolve_overlay() -> void:
	var found: Node = get_tree().get_first_node_in_group("darkness_overlay")
	_overlay = found as DarknessOverlay

	if _overlay != null and _overlay.has_signal("game_over_requested"):
		if not _overlay.game_over_requested.is_connected(_on_overlay_game_over_requested):
			_overlay.game_over_requested.connect(_on_overlay_game_over_requested)

	_set_overlay_active(false)

func _resolve_victory_audio() -> void:
	var n := get_node_or_null(victory_audio_path)
	_victory_audio = n as AudioStreamPlayer

	if _victory_audio != null:
		_victory_audio.volume_db = victory_volume_db
		_victory_audio.pitch_scale = victory_pitch
		if _victory_audio.playing:
			_victory_audio.stop()

# ==========================================================
# ✅ CACHE + ORDEN + SEPARAR Light_End
# ==========================================================
func _cache_lights() -> void:
	_lights.clear()
	_sequence.clear()
	_end_light = null
	_collectible_total = 0

	var container := get_node_or_null(lights_container_path) as Node
	if container == null:
		push_error("[LightManager] lights_container_path inválido.")
		return

	var tmp: Array[GuidingLight] = []

	for child in container.get_children():
		var gl := child as GuidingLight
		if gl == null:
			continue

		if not gl.reached.is_connected(_on_light_reached):
			gl.reached.connect(_on_light_reached)

		gl.set_active(false)
		gl.set_visual_state(0)

		if gl.name == "Light_End":
			_end_light = gl
		else:
			tmp.append(gl)

	tmp.sort_custom(func(a: GuidingLight, b: GuidingLight) -> bool:
		return _extract_light_number(a.name) < _extract_light_number(b.name)
	)

	_lights = tmp
	_collectible_total = _lights.size()

	_sequence.append_array(_lights)
	if _end_light != null:
		_sequence.append(_end_light)

	print("[LightManager] luces reales:", _collectible_total, " + end:", (_end_light != null))

func _extract_light_number(n: String) -> int:
	var parts := n.split("_")
	if parts.size() >= 2:
		var maybe := parts[parts.size() - 1]
		if maybe.is_valid_int():
			return int(maybe)
	return 9999

func on_mission_dialogue_finished() -> void:
	start_challenge()

func start_challenge() -> void:
	if _sequence.is_empty():
		push_error("[LightManager] No hay luces en la secuencia.")
		return

	if _overlay == null:
		_resolve_overlay()
	if _victory_audio == null:
		_resolve_victory_audio()

	_game_over_open = false
	_index = 0
	_light_timer = time_per_light
	_global_timer = total_time
	_active = true

	_activate_only(_index)
	_set_overlay_active(true)

	# ✅ AHORA LA MÚSICA DEL PUZZLE LA MANEJA MUSICMANAGER GLOBAL
	start_lights_puzzle_music()

	if _overlay != null:
		_overlay.time_per_light = time_per_light
		_overlay.warning_threshold = warning_threshold
		_overlay.danger_threshold = danger_threshold
		_overlay.play_intro_hint(overlay_intro_soft_duration)

	emit_signal("challenge_started", _collectible_total, total_time)
	emit_signal("challenge_progress", _global_timer, total_time, 0, _collectible_total, 0.0)

func _process(delta: float) -> void:
	if not _active:
		return

	_global_timer -= delta
	_light_timer -= delta

	if _overlay != null and _overlay.has_method("set_time_left"):
		_overlay.set_time_left(_light_timer)

	var ratio: float = 1.0
	if time_per_light > 0.0:
		ratio = _light_timer / time_per_light
	ratio = clamp(ratio, 0.0, 1.0)

	if _index >= 0 and _index < _sequence.size():
		var current := _sequence[_index]
		if ratio <= danger_threshold:
			current.set_visual_state(2)
		elif ratio <= warning_threshold:
			current.set_visual_state(1)
		else:
			current.set_visual_state(0)

	var danger_ratio := 0.0
	if ratio <= warning_threshold:
		if warning_threshold > 0.0:
			danger_ratio = clamp((warning_threshold - ratio) / warning_threshold, 0.0, 1.0)

	# ✅ Presión musical global (pitch/vol) vía MusicManager
	update_music_pressure(danger_ratio)

	var found_for_hud: int = int(clamp(_index, 0, _collectible_total))
	emit_signal("challenge_progress", _global_timer, total_time, found_for_hud, _collectible_total, danger_ratio)

	if _global_timer <= 0.0:
		_fail("Tiempo total agotado")
	elif _light_timer <= 0.0:
		_fail("Te demoraste en la luz")

func _activate_only(i: int) -> void:
	for j in range(_sequence.size()):
		var is_current := (j == i)
		_sequence[j].set_active(is_current)
		_sequence[j].set_visual_state(0)

func _activate_all(value: bool) -> void:
	for l in _sequence:
		l.set_active(value)
		l.set_visual_state(0)

func _on_light_reached(light: GuidingLight) -> void:
	if not _active:
		return
	if _index < 0 or _index >= _sequence.size():
		return
	if _sequence[_index] != light:
		return

	_index += 1

	if _index >= _sequence.size():
		_success()
		return

	_light_timer = time_per_light
	_activate_only(_index)

func _on_overlay_game_over_requested() -> void:
	_fail("La oscuridad te alcanzó")

func _fail(reason: String) -> void:
	if not _active:
		return

	_active = false
	_activate_all(false)
	_set_overlay_active(false)

	stop_lights_puzzle_music()

	emit_signal("challenge_ended", false, reason)

	if _game_over_open:
		return
	_game_over_open = true
	_show_game_over(reason)

func _success() -> void:
	if not _active:
		return

	_active = false
	_activate_all(false)
	_set_overlay_active(false)

	stop_lights_puzzle_music()
	play_victory_audio()

	emit_signal("challenge_progress", 0.0, total_time, _collectible_total, _collectible_total, 0.0)
	emit_signal("challenge_ended", true, "")

	# ✅ NO CAMBIAR ESCENA AQUÍ. MissionHUD lo hace.

func _show_game_over(reason: String) -> void:
	if not game_over_scene:
		push_error("[LightManager] game_over_scene no asignada.")
		return

	var go := game_over_scene.instantiate()
	get_tree().get_current_scene().add_child(go)

	if go.has_method("set_reason"):
		go.set_reason(reason)

func _set_overlay_active(v: bool) -> void:
	if _overlay == null:
		return
	_overlay.set_active(v)

# ==========================================================
# MÚSICA (AHORA GLOBAL)
# ==========================================================
func start_lights_puzzle_music() -> void:
	# Reproduce el track del puzzle desde el Autoload
	MusicManager.play_world1_puzzle(0.15)

func stop_lights_puzzle_music() -> void:
	# Resetea presión y apaga la música del puzzle
	MusicManager.reset_puzzle_pressure()
	MusicManager.stop(false) # fade out

func update_music_pressure(danger_ratio: float) -> void:
	MusicManager.set_puzzle_pressure(danger_ratio)


# ==========================================================
# ✅ AUDIO VICTORIA
# ==========================================================
func play_victory_audio() -> void:
	if _victory_audio == null:
		return

	_victory_audio.stop()

	if victory_delay > 0.0:
		var t := get_tree().create_timer(victory_delay)
		t.timeout.connect(func():
			if _victory_audio != null:
				_victory_audio.play(0.0)
		)
	else:
		_victory_audio.play(0.0)
