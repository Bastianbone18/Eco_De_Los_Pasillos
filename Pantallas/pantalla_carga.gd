extends Control
class_name PantallaCarga

@onready var bg: TextureRect = $TextureRect
@onready var label: Label = $Label
@onready var timer: Timer = $Timer

@onready var text_anim: AnimationPlayer = $AnimationPlayer
@onready var fade_anim: AnimationPlayer = $AnimationPlayerRect

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

var _next_scene_path: String = ""
var _key: String = ""
var _text: String = ""
var _wait: float = -1.0

var _timer_done: bool = false
var _fade_in_done: bool = false
var _changing: bool = false

func setup(next_scene_path: String, key: String = "", text: String = "", wait_time: float = -1.0) -> void:
	_next_scene_path = next_scene_path
	_key = key
	_text = text
	_wait = wait_time

func _ready() -> void:
	MusicManager.stop(true)
	process_mode = Node.PROCESS_MODE_ALWAYS

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

	_play_start_anims()
	timer.start()

func _play_start_anims() -> void:
	if text_anim and text_anim.has_animation(text_anim_name):
		text_anim.play(text_anim_name)

	if fade_anim and fade_anim.has_animation(fade_in_anim_name):
		fade_anim.play(fade_in_anim_name)
		fade_anim.animation_finished.connect(_on_fade_anim_finished, CONNECT_ONE_SHOT)
	else:
		_fade_in_done = true

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

	if fade_anim and fade_anim.has_animation(fade_out_anim_name):
		fade_anim.play(fade_out_anim_name)
		await fade_anim.animation_finished

	get_tree().paused = false

	if _next_scene_path == "":
		push_error("[PantallaCarga] next_scene_path vacío.")
		return

	print("[PantallaCarga] cambiando a -> ", _next_scene_path)
	get_tree().change_scene_to_file(_next_scene_path)
