# Godot 4.3
extends CanvasLayer

const NEXT_SCENE := "res://Btas_y pruebas/Mapa_beta.tscn"
const DIALOGUE_INTRO := "res://Dialogos/Intro.dialogue"
const BALLOON_SCENE := preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_btn: Button = $Skip

var _ended := false
var _balloon: Node = null

func _ready() -> void:
	# Reproduce el video en paralelo (opcional)
	if video.stream and not video.is_playing():
		video.play()
	video.finished.connect(_on_video_finished)

	skip_btn.pressed.connect(_on_skip_pressed)

	# Lanza el único diálogo
	_start_intro_dialogue()


func _start_intro_dialogue() -> void:
	# Instancia el balloon
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	_balloon = BALLOON_SCENE.instantiate()
	add_child(_balloon)

	# Conecta una señal de finalización (ajusta el nombre si tu balloon usa otra)
	if _balloon.has_signal("dialogue_finished"):
		if not _balloon.is_connected("dialogue_finished", Callable(self, "_on_dialogue_done")):
			_balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_done"))
	elif _balloon.has_signal("finished"):
		if not _balloon.is_connected("finished", Callable(self, "_on_dialogue_done")):
			_balloon.connect("finished", Callable(self, "_on_dialogue_done"))
	else:
		push_warning("Balloon no tiene señal de fin conocida (dialogue_finished/finished).")

	# Carga y arranca desde 'intro_luna'
	var res: Resource = load(DIALOGUE_INTRO)
	if res and _balloon.has_method("start"):
		_balloon.start(res, "intro_luna")  # <-- clave: 2 argumentos (recurso, start_id)
	else:
		push_warning("No se pudo iniciar Intro.dialogue. Revisa ruta o método start().")


func _on_dialogue_done(varargs) -> void:
	_go_next_scene()


func _on_skip_pressed() -> void:
	_end_now()


func _on_video_finished() -> void:
	# El flujo lo define el diálogo; no hacemos nada aquí.
	pass


func _end_now() -> void:
	if _ended:
		return
	_ended = true

	skip_btn.disabled = true

	if video.is_playing():
		video.stop()
	if video.finished.is_connected(_on_video_finished):
		video.finished.disconnect(_on_video_finished)

	if is_instance_valid(_balloon):
		_balloon.queue_free()
		_balloon = null

	_go_next_scene()


func _go_next_scene() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
