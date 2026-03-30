extends Control
class_name PantallaCarga

@onready var bg: TextureRect = $TextureRect
@onready var label: Label = $Label
@onready var timer: Timer = $Timer

@onready var text_anim: AnimationPlayer = $AnimationPlayer
@onready var fade_anim: AnimationPlayer = $AnimationPlayerRect
@onready var immersion_label: Label = $Texto_de_inmersion

@export var text_anim_name: String = "carga"
@export var fade_in_anim_name: String = "fade_in"
@export var fade_out_anim_name: String = "fade_out"

@export var default_text: String = "Cargando..."
@export var default_wait: float = 1.3

@export var textures_by_key: Dictionary = {
	"mundo1": preload("res://Imagenes_pantallas/Carga.png"),
	"mundo2": preload("res://Imagenes_pantallas/Pantallamundo2.Png"),
	"mundo3": preload("res://Imagenes_pantallas/Fondo3.png"),
	"retry": preload("res://Imagenes_pantallas/Editable.png"),
}

@export var key_by_scene_path: Dictionary = {
	"res://Modelos_Blender/Terrerno_de_mundo1/Mundo1.tscn": "mundo1",
	"res://Modelos_Blender/TerrenoMundo2/Mundo2.tscn": "mundo2",
	"res://Modelos_Blender/TerrenoMundo3/Mundo3.tscn": "mundo3",
	"res://Cinematicas/Mundo3Intro.tscn": "mundo3",
}

# =========================
# TEXTO DE INMERSIÓN
# =========================
@export var immersion_full_text: String = "Para una mayor inmersión, lee los textos en voz alta."
@export var immersion_start_delay: float = 0.15
@export var immersion_extra_end_margin: float = 0.20
@export var immersion_chars_per_second: float = 28.0

@export var wave_amplitude: float = 2.0
@export var wave_speed: float = 2.8
@export var shake_amplitude: float = 0.6

@export var talk_sound_path: String = "res://Musica y sonidos/Sonidos/talk.ogg"
@export var talk_volume_db: float = -18.0
@export var talk_pitch_scale: float = 1.0

var _next_scene_path: String = ""
var _key: String = ""
var _text: String = ""
var _wait: float = -1.0

var _timer_done: bool = false
var _fade_in_done: bool = false
var _changing: bool = false

# Typewriter
var _immersion_base_pos: Vector2 = Vector2.ZERO
var _immersion_elapsed: float = 0.0
var _immersion_started: bool = false
var _immersion_finished: bool = false
var _immersion_visible_chars: int = 0
var _immersion_type_duration: float = 0.0

var _talk_player: AudioStreamPlayer = null

func setup(next_scene_path: String, key: String = "", text: String = "", wait_time: float = -1.0) -> void:
	_next_scene_path = next_scene_path
	_key = key
	_text = text
	_wait = wait_time

func _ready() -> void:
	MusicManager.stop(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	var si := get_node_or_null("/root/SaveIndicator")
	if si:
		si.show_for_load()

	get_tree().paused = true

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	if _next_scene_path == "" and "current_scene_path" in GameData:
		_next_scene_path = str(GameData.current_scene_path)

	print("[PantallaCarga] _next_scene_path = ", _next_scene_path)

	label.text = (_text if _text != "" else default_text)

	if _key == "":
		if key_by_scene_path.has(_next_scene_path):
			_key = str(key_by_scene_path[_next_scene_path])
		else:
			_key = "retry"

	if textures_by_key.has(_key):
		var tex: Texture2D = textures_by_key[_key]
		if tex != null:
			bg.texture = tex

	var t: float = default_wait
	if _wait >= 0.0:
		t = _wait
	timer.wait_time = max(0.1, t)

	_setup_immersion_text()
	_setup_talk_audio()

	_play_start_anims()
	timer.start()

func _setup_immersion_text() -> void:
	if immersion_label == null:
		return

	_immersion_base_pos = immersion_label.position
	_immersion_elapsed = 0.0
	_immersion_started = false
	_immersion_finished = false
	_immersion_visible_chars = 0

	immersion_label.text = ""
	immersion_label.visible = true

	var total_available: float = max(
		0.2,
		timer.wait_time - immersion_start_delay - immersion_extra_end_margin
	)

	var estimated_duration: float = 0.0
	if immersion_chars_per_second > 0.0:
		estimated_duration = float(immersion_full_text.length()) / immersion_chars_per_second

	_immersion_type_duration = min(total_available, estimated_duration)

	if _immersion_type_duration <= 0.05:
		_immersion_type_duration = total_available

func _setup_talk_audio() -> void:
	_talk_player = AudioStreamPlayer.new()
	_talk_player.name = "TalkPlayer"
	_talk_player.bus = "SFX"
	_talk_player.volume_db = talk_volume_db
	_talk_player.pitch_scale = talk_pitch_scale
	_talk_player.stream = load(talk_sound_path)
	_talk_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_talk_player)

func _play_start_anims() -> void:
	if text_anim and text_anim.has_animation(text_anim_name):
		text_anim.play(text_anim_name)

	if fade_anim and fade_anim.has_animation(fade_in_anim_name):
		fade_anim.play(fade_in_anim_name)
		fade_anim.animation_finished.connect(_on_fade_anim_finished, CONNECT_ONE_SHOT)
	else:
		_fade_in_done = true

func _process(delta: float) -> void:
	_update_immersion_typewriter(delta)
	_update_immersion_motion()

func _update_immersion_typewriter(delta: float) -> void:
	if immersion_label == null:
		return

	if _immersion_finished:
		return

	_immersion_elapsed += delta

	if not _immersion_started:
		if _immersion_elapsed >= immersion_start_delay:
			_immersion_started = true
			_immersion_elapsed = 0.0
		else:
			return

	if _immersion_type_duration <= 0.0:
		immersion_label.text = immersion_full_text
		_finish_immersion_text()
		return

	var total_chars: int = immersion_full_text.length()
	var progress: float = clamp(_immersion_elapsed / _immersion_type_duration, 0.0, 1.0)
	var target_chars: int = int(floor(progress * float(total_chars)))

	if progress >= 1.0:
		target_chars = total_chars

	if target_chars != _immersion_visible_chars:
		_immersion_visible_chars = target_chars
		immersion_label.text = immersion_full_text.substr(0, _immersion_visible_chars)

		if _immersion_visible_chars < total_chars:
			_play_talk_sound()
		else:
			_finish_immersion_text()

func _update_immersion_motion() -> void:
	if immersion_label == null:
		return

	var t: float = Time.get_ticks_msec() / 1000.0
	var wave_y: float = sin(t * wave_speed) * wave_amplitude
	var shake_x: float = sin(t * (wave_speed * 2.7)) * shake_amplitude

	immersion_label.position = _immersion_base_pos + Vector2(shake_x, wave_y)

func _play_talk_sound() -> void:
	if _talk_player == null:
		return
	if _talk_player.stream == null:
		return

	if not _talk_player.playing:
		_talk_player.play()

func _stop_talk_sound() -> void:
	if _talk_player == null:
		return
	if _talk_player.playing:
		_talk_player.stop()

func _finish_immersion_text() -> void:
	_immersion_finished = true
	immersion_label.text = immersion_full_text
	_stop_talk_sound()

func _on_fade_anim_finished(anim_name: StringName) -> void:
	if String(anim_name) == fade_in_anim_name:
		_fade_in_done = true
		_try_change_scene()

func _on_timer_timeout() -> void:
	_timer_done = true
	_try_change_scene()

func _try_change_scene() -> void:
	if _changing:
		return
	if not (_timer_done and _fade_in_done):
		return

	_changing = true
	_stop_talk_sound()

	if fade_anim and fade_anim.has_animation(fade_out_anim_name):
		fade_anim.play(fade_out_anim_name)
		await fade_anim.animation_finished

	get_tree().paused = false

	if _next_scene_path == "":
		push_error("[PantallaCarga] next_scene_path vacío.")
		return

	print("[PantallaCarga] cambiando a -> ", _next_scene_path)
	get_tree().change_scene_to_file(_next_scene_path)
