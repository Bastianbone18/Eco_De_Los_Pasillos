extends Control

@onready var fondo: ColorRect = $Fondo
@onready var texto: Label = $TextoDespierta
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var imagen_lore: TextureRect = $ImagenLore

@export var next_scene_path: String = "res://Modelos_Blender/TerrenoMundo3/Mundo3.tscn"
@export var lore_images: Array[Texture2D] = []

var shake_strength := 0.0
var base_pos := Vector2.ZERO
var shaking := false

var _preload_started := false
var _scene_ready := false
var _loaded_packed_scene: PackedScene = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# ✅ Marcar intro de Mundo 3 como vista
	GameData.intro_mundo3_done = true

	# ✅ Dejar preparado que el destino real es Mundo3
	GameData.current_scene_path = next_scene_path

	# ✅ Guardar inmediatamente para que si muere / carga no repita la intro
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[Mundo3Intro] intro_mundo3_done guardado.")

	texto.visible = true
	texto.text = "DESPIERTA"

	base_pos = texto.position

	if imagen_lore:
		imagen_lore.visible = false

	# ✅ Empezar a precargar la escena real en segundo plano
	_start_preload()

	if anim.has_animation("intro"):
		anim.play("intro")
	else:
		push_error("[Mundo3Intro] No existe la animación 'intro'.")

func _process(_delta: float) -> void:
	# Shake del texto
	if shaking:
		texto.position = base_pos + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

	# Revisar estado de la precarga
	_poll_preload()

func _start_preload() -> void:
	if _preload_started:
		return

	var err := ResourceLoader.load_threaded_request(next_scene_path)
	if err != OK:
		push_error("[Mundo3Intro] Error iniciando precarga de: %s | Código: %s" % [next_scene_path, str(err)])
		return

	_preload_started = true
	print("[Mundo3Intro] Precarga iniciada: ", next_scene_path)

func _poll_preload() -> void:
	if not _preload_started or _scene_ready:
		return

	var status := ResourceLoader.load_threaded_get_status(next_scene_path)

	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[Mundo3Intro] Recurso inválido al precargar: %s" % next_scene_path)

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[Mundo3Intro] Falló la precarga de: %s" % next_scene_path)

		ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(next_scene_path)
			if res is PackedScene:
				_loaded_packed_scene = res
				_scene_ready = true
				print("[Mundo3Intro] Escena precargada correctamente.")
			else:
				push_error("[Mundo3Intro] El recurso cargado no es PackedScene: %s" % next_scene_path)

func set_shaking(active: bool) -> void:
	shaking = active
	if not active:
		texto.position = base_pos

func set_shake_strength(value: float) -> void:
	shake_strength = value

func show_lore_image(index: int) -> void:
	if imagen_lore == null:
		return
	if index < 0 or index >= lore_images.size():
		return

	imagen_lore.texture = lore_images[index]
	imagen_lore.visible = true

func hide_lore_image() -> void:
	if imagen_lore:
		imagen_lore.visible = false

func finish_intro() -> void:
	get_tree().paused = false

	# ✅ Si ya terminó de precargar, cambio instantáneo
	if _scene_ready and _loaded_packed_scene:
		print("[Mundo3Intro] fin intro -> entrando a Mundo3 precargado.")
		get_tree().change_scene_to_packed(_loaded_packed_scene)
		return

	# ✅ Fallback: si aún no terminó, intenta carga normal
	print("[Mundo3Intro] fin intro -> la precarga aún no termina, cargando normal: ", next_scene_path)
	get_tree().change_scene_to_file(next_scene_path)
