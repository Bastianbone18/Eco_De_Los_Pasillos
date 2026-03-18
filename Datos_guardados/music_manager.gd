extends Node

const BUS_NAME: String = "Musica"          # Bus para la música del juego (mundos, puzzles)
const MENU_BUS: String = "Menu"            # Bus para la música del menú

# =========================
# STREAMS (ASIGNAR EN EDITOR)
# =========================
@export var menu_stream: AudioStream = preload("res://Musica y sonidos/Menu.ogg")
@export var world1_stream: AudioStream
@export var world1_puzzle_stream: AudioStream
@export var world3_stream: AudioStream = preload("res://Musica y sonidos/Mundo3.ogg")

# =========================
# VOLUMENES BASE
# =========================
@export var menu_db: float = -6.0
@export var world1_db: float = -12.0
@export var world1_puzzle_db: float = -14.0
@export var world3_db: float = -8.0

# =========================
# PRESIÓN DEL PUZZLE (Mundo1)
# =========================
@export var puzzle_base_volume_db: float = -14.0
@export var puzzle_danger_volume_db: float = -10.0
@export var puzzle_base_pitch: float = 1.0
@export var puzzle_danger_pitch: float = 1.08

# =========================
# RUNTIME
# =========================
var _player: AudioStreamPlayer = null
var _fade_tween: Tween = null
var did_menu_flash: bool = false

# ==================================================
# MUNDO 2 – SISTEMA DE PRESIÓN MUSICAL
# ==================================================
var world2_stage: int = 0                 # 0..3
var world2_intensity: float = 0.0         # 0..10

var _bus_idx: int = -1
var _fx_lowpass: AudioEffectLowPassFilter = null
var _fx_dist: AudioEffectDistortion = null
var _fx_chorus: AudioEffectChorus = null
var _fx_tween: Tween = null

# RAMP por diálogo
var _dialogue_ramp_tween: Tween = null
var _base_intensity_for_stage: float = 0.0

# Pitch wobble (WORLD2) - orgánico, pesado, incómodo
var _wobble_base_pitch: float = 1.0
var _wobble_time: float = 0.0
var _wobble_amp: float = 0.0
var _wobble_speed: float = 0.0
var _wobble_jitter_amp: float = 0.0
var _wobble_enabled: bool = false

# ==================================================
# READY
# ==================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	add_child(_player)
	# El bus se asignará dinámicamente según el stream; por defecto lo dejamos en "Musica"
	_player.bus = BUS_NAME
	_player.autoplay = false

	_player.stream = menu_stream
	_player.volume_db = menu_db

	_cache_world2_fx()
	reset_world2_fx(true)

func _process(delta: float) -> void:
	# ✅ SOLO WORLD2: wobble orgánico (no toca World1)
	if not _wobble_enabled or _player == null:
		return

	_wobble_time += delta

	# Drift lento + jitter irregular
	var drift: float = sin(_wobble_time * TAU * _wobble_speed) * _wobble_amp
	var jitter: float = sin(_wobble_time * TAU * (_wobble_speed * 7.0 + 1.3)) * _wobble_jitter_amp

	# Asimetría: más caída que subida (pesado / nauseabundo)
	var asym: float = -abs(drift) * 0.55

	_player.pitch_scale = _wobble_base_pitch + drift + jitter + asym

# ==================================================
# SELECCIÓN DE BUS SEGÚN EL STREAM
# ==================================================
func _set_bus_for_stream(stream: AudioStream) -> void:
	if stream == menu_stream:
		_player.bus = MENU_BUS
		print("[MusicManager] Cambiando a bus: ", MENU_BUS)
	else:
		_player.bus = BUS_NAME
		print("[MusicManager] Cambiando a bus: ", BUS_NAME)

# ==================================================
# PLAYERS (MENU / WORLD1 / PUZZLE)
# ==================================================
func play_menu(fade: float = 0.5) -> void:
	_set_bus_for_stream(menu_stream)
	_switch_stream(menu_stream)
	await fade_to(menu_db, fade)

func play_world1(fade: float = 1.5) -> void:
	if world1_stream == null:
		push_warning("MusicManager: world1_stream no asignado")
		return

	_set_bus_for_stream(world1_stream)
	_switch_stream(world1_stream)
	_reset_pressure_to_world1()
	await fade_to(world1_db, fade)

func play_world1_puzzle(fade: float = 0.3) -> void:
	if world1_puzzle_stream == null:
		push_warning("MusicManager: world1_puzzle_stream no asignado")
		return

	_set_bus_for_stream(world1_puzzle_stream)

	if _player.stream == world1_puzzle_stream and _player.playing:
		set_puzzle_pressure(0.0)
		await fade_to(world1_puzzle_db, fade)
		return

	_switch_stream(world1_puzzle_stream)
	set_puzzle_pressure(0.0)
	await fade_to(world1_puzzle_db, fade)

func play_world3(fade: float = 1.5) -> void:
	if world3_stream == null:
		push_warning("MusicManager: world3_stream no asignado")
		return

	_set_bus_for_stream(world3_stream)
	_switch_stream(world3_stream)
	await fade_to(world3_db, fade)

func play_stream(stream: AudioStream, fade: float = 1.0, restart: bool = true, target_db: float = -12.0) -> void:
	if stream == null:
		push_warning("MusicManager: play_stream recibió stream null")
		return

	_set_bus_for_stream(stream)
	_kill_fade()

	var changed: bool = false
	if _player.stream != stream:
		_player.stream = stream
		_player.pitch_scale = 1.0
		changed = true

	if restart or changed:
		_player.stop()
		_player.volume_db = -60.0
		_player.play(0.0)
	elif not _player.playing:
		_player.volume_db = -60.0
		_player.play(0.0)

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_db, max(0.01, fade))
	await _fade_tween.finished

func stop(immediate: bool = true) -> void:
	if immediate:
		_kill_fade()
		if _player:
			_player.stop()
	else:
		await fade_to(-60.0, 0.5)
		if _player:
			_player.stop()

# ==================================================
# FADES
# ==================================================
func fade_to(target_db: float, duration: float = 0.5) -> void:
	_kill_fade()

	if not _player.playing:
		_player.play()

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_db, max(0.01, duration))
	await _fade_tween.finished

func fade_in(duration: float = 0.5) -> void:
	var target_db: float = -10.0
	if _player.stream == menu_stream:
		target_db = menu_db
	elif _player.stream == world1_puzzle_stream:
		target_db = world1_puzzle_db
	elif _player.stream == world1_stream:
		target_db = world1_db

	_player.volume_db = -60.0
	if not _player.playing:
		_player.play()

	await fade_to(target_db, duration)

func fade_out(duration: float = 0.5) -> void:
	await fade_to(-60.0, duration)

func fade_out_and_stop(fade_time: float = 0.7) -> void:
	await fade_out(fade_time)
	stop(true)

# ==================================================
# INTERNALS
# ==================================================
func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

func _switch_stream(stream: AudioStream) -> void:
	if _player.stream != stream:
		_player.stream = stream
		_player.pitch_scale = 1.0

func _reset_pressure_to_world1() -> void:
	_player.pitch_scale = 1.0

# ==================================================
# PUZZLE PRESSURE (Mundo1)
# ==================================================
func set_puzzle_pressure(danger_ratio: float) -> void:
	danger_ratio = clamp(danger_ratio, 0.0, 1.0)
	if _player.stream != world1_puzzle_stream:
		return

	_player.pitch_scale = lerp(puzzle_base_pitch, puzzle_danger_pitch, danger_ratio)
	_player.volume_db = lerp(puzzle_base_volume_db, puzzle_danger_volume_db, danger_ratio)

func reset_puzzle_pressure() -> void:
	if _player.stream != world1_puzzle_stream:
		return

	_player.pitch_scale = puzzle_base_pitch
	_player.volume_db = puzzle_base_volume_db

# ==================================================
# MUNDO 2 – FX CACHE (TIPADO FUERTE)
# ==================================================
func _cache_world2_fx() -> void:
	_bus_idx = AudioServer.get_bus_index(BUS_NAME)
	if _bus_idx < 0:
		push_warning("MusicManager: bus '", BUS_NAME, "' no existe")
		return

	_fx_lowpass = null
	_fx_dist = null
	_fx_chorus = null

	var count: int = AudioServer.get_bus_effect_count(_bus_idx)
	for i in range(count):
		var fx: AudioEffect = AudioServer.get_bus_effect(_bus_idx, i) as AudioEffect

		var lp := fx as AudioEffectLowPassFilter
		if lp != null:
			_fx_lowpass = lp
			continue

		var dist := fx as AudioEffectDistortion
		if dist != null:
			_fx_dist = dist
			continue

		var cho := fx as AudioEffectChorus
		if cho != null:
			_fx_chorus = cho
			continue

	if _fx_lowpass == null:
		push_warning("MusicManager: No encontré LowPassFilter en el bus ", BUS_NAME)
	if _fx_dist == null:
		push_warning("MusicManager: No encontré Distortion en el bus ", BUS_NAME)
	if _fx_chorus == null:
		push_warning("MusicManager: No encontré Chorus en el bus ", BUS_NAME)

func _kill_fx_tween() -> void:
	if _fx_tween != null and _fx_tween.is_running():
		_fx_tween.kill()
	_fx_tween = null

func _kill_dialogue_ramp() -> void:
	if _dialogue_ramp_tween != null and _dialogue_ramp_tween.is_running():
		_dialogue_ramp_tween.kill()
	_dialogue_ramp_tween = null

# ==================================================
# MUNDO 2 – API
# ==================================================
func reset_world2_fx(immediate: bool = false) -> void:
	world2_stage = 0
	world2_intensity = 0.0
	_base_intensity_for_stage = 0.0

	_kill_dialogue_ramp()
	_stop_pitch_wobble()

	if _bus_idx == -1 or _fx_lowpass == null or _fx_dist == null or _fx_chorus == null:
		_cache_world2_fx()

	_apply_world2_fx(0.0, immediate, 0.35)
	print("[MusicManager] reset_world2_fx -> intensity=0")

func set_world2_stage(stage: int, smooth: float = 0.45) -> void:
	var new_stage: int = clamp(stage, 0, 3)
	if new_stage <= world2_stage:
		print("[MusicManager] set_world2_stage ignorado (no bajar). actual=", world2_stage, " nuevo=", new_stage)
		return

	world2_stage = new_stage

	var target_intensity: float = 0.0
	match world2_stage:
		0: target_intensity = 0.0
		1: target_intensity = 3.0
		2: target_intensity = 6.0
		3: target_intensity = 10.0

	print("[MusicManager] WORLD2 STAGE -> ", world2_stage, " (intensity=", target_intensity, ")")
	set_world2_intensity(target_intensity, smooth)

func set_world2_intensity(intensity: float, smooth: float = 0.6) -> void:
	var clamped_intensity: float = clamp(intensity, 0.0, 10.0)
	world2_intensity = clamped_intensity
	print("[MusicManager] set_world2_intensity -> ", world2_intensity)
	_apply_world2_fx(world2_intensity, false, smooth)

# ==================================================
# MUNDO 2 – RAMP DURANTE DIÁLOGO
# ==================================================
func on_world2_dialogue_start(stage: int, ramp_time: float = 0.7) -> void:
	set_world2_stage(stage, 0.25)
	_base_intensity_for_stage = world2_intensity

	var peak: float = _base_intensity_for_stage
	match stage:
		1: peak = 5.6
		2: peak = 8.2
		3: peak = 10.0

	_kill_dialogue_ramp()
	print("[MusicManager] DIALOGUE START -> stage=", stage, " ramp_to_peak=", peak)

	_dialogue_ramp_tween = create_tween()
	_dialogue_ramp_tween.tween_method(
		Callable(self, "set_world2_intensity"),
		world2_intensity,
		peak,
		max(0.01, ramp_time)
	)

	if stage >= 2:
		_start_pitch_wobble(stage)

func on_world2_dialogue_end(hold_time: float = 2.2, settle_time: float = 1.2) -> void:
	print("[MusicManager] DIALOGUE END -> hold=", hold_time, " settle=", settle_time)

	var stage: int = world2_stage
	var settle: float = _base_intensity_for_stage
	if settle <= 0.0:
		match stage:
			1: settle = 3.0
			2: settle = 6.0
			3: settle = 10.0

	_kill_dialogue_ramp()

	_dialogue_ramp_tween = create_tween()
	_dialogue_ramp_tween.tween_interval(max(0.0, hold_time))
	_dialogue_ramp_tween.tween_method(
		Callable(self, "set_world2_intensity"),
		world2_intensity,
		settle,
		max(0.01, settle_time)
	)

	_stop_pitch_wobble()

# ==================================================
# MUNDO 2 – “APAGÓN” TIPO CINTA / VHS
# ==================================================
func world2_kill_music_like_tape(fade_time: float = 1.2) -> void:
	if _player == null:
		return

	set_world2_intensity(10.0, 0.12)
	await fade_out(max(0.01, fade_time))
	stop(true)
	reset_world2_fx(true)

# ==================================================
# MUNDO 2 – APLICAR FX (MÁS PESADO / TÉTRICO / LENTO)
# ==================================================
func _apply_world2_fx(intensity: float, immediate: bool = false, smooth: float = 0.75) -> void:
	if _bus_idx == -1 or _fx_lowpass == null or _fx_dist == null or _fx_chorus == null:
		_cache_world2_fx()

	if _fx_lowpass == null or _fx_dist == null or _fx_chorus == null:
		push_warning("MusicManager: faltan FX para aplicar intensidad")
		return

	var t01: float = clamp(intensity / 10.0, 0.0, 1.0)

	# Curva no-lineal: el “feo” entra antes
	var k: float = ease(t01, 1.55)

	# LowPass: oscuro / pesado
	var cutoff: float = lerp(18000.0, 1700.0, k)

	# Distortion: grano/suciedad
	var drive: float = lerp(0.02, 0.34, k)

	# HF: cae para incomodidad
	var keep_hf: float = lerp(16000.0, 5200.0, k)

	# Chorus: mareo
	var chorus_wet: float = lerp(0.0, 0.18, k)

	# Pitch: más pesado
	var pitch: float = lerp(1.0, 0.94, k)

	# Volumen: casi estable
	var volume: float = lerp(-12.0, -13.6, k)

	_kill_fx_tween()

	_fx_dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	_fx_dist.pre_gain = 0.0
	_fx_dist.post_gain = 0.0
	_fx_dist.keep_hf_hz = keep_hf

	if _fx_chorus != null:
		if _fx_chorus.voice_count >= 2 and _fx_chorus.has_method("set_voice_rate_hz") and _fx_chorus.has_method("set_voice_depth_ms"):
			_fx_chorus.set_voice_rate_hz(0, lerp(0.8, 0.35, k))
			_fx_chorus.set_voice_rate_hz(1, lerp(1.1, 0.45, k))
			_fx_chorus.set_voice_depth_ms(0, lerp(2.5, 7.0, k))
			_fx_chorus.set_voice_depth_ms(1, lerp(3.0, 8.0, k))

	if immediate:
		_player.pitch_scale = pitch
		_player.volume_db = volume
		_fx_lowpass.cutoff_hz = cutoff
		_fx_dist.drive = drive
		_fx_chorus.wet = chorus_wet
		return

	_fx_tween = create_tween()
	_fx_tween.set_parallel(true)
	_fx_tween.tween_property(_player, "pitch_scale", pitch, smooth)
	_fx_tween.tween_property(_player, "volume_db", volume, smooth)
	_fx_tween.tween_property(_fx_lowpass, "cutoff_hz", cutoff, smooth)
	_fx_tween.tween_property(_fx_dist, "drive", drive, smooth)
	_fx_tween.tween_property(_fx_chorus, "wet", chorus_wet, smooth)

# ==================================================
# Pitch wobble (WORLD2) – orgánico, lento, pesado
# ==================================================
func _start_pitch_wobble(stage: int) -> void:
	_stop_pitch_wobble()
	if _player == null:
		return

	_wobble_base_pitch = _player.pitch_scale
	_wobble_time = 0.0
	_wobble_enabled = true

	match stage:
		2:
			_wobble_amp = 0.006
			_wobble_speed = 0.18
			_wobble_jitter_amp = 0.0018
		3:
			_wobble_amp = 0.010
			_wobble_speed = 0.14
			_wobble_jitter_amp = 0.0026
		_:
			_wobble_amp = 0.004
			_wobble_speed = 0.22
			_wobble_jitter_amp = 0.0012

func _stop_pitch_wobble() -> void:
	_wobble_enabled = false
	if _player != null:
		_player.pitch_scale = _wobble_base_pitch
