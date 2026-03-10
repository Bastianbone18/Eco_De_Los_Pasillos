extends Node3D
class_name Mundo2IntroController

@onready var black_rect: ColorRect = $CanvasLayer/ColorRect
@onready var anim: AnimationPlayer = $CanvasLayer/IntroAnim
@onready var breath_audio: AudioStreamPlayer = $BreathAudio

@export var fade_anim_name: String = "FadeTrans"

@export var intro_dialogue_path: String = "res://Dialogos/Intro_Mundo2.dialogue"
@export var intro_dialogue_key: String = "intro_mundo2"

@export var world2_music_stream: AudioStream = preload("res://Musica y sonidos/Cold.ogg")
@export var world2_music_fade_in: float = 1.5

var _running := false

func _ready() -> void:
	print("========== [Mundo2Intro] _ready() ==========")
	print("[Mundo2Intro] Node path:", get_path())
	print("[Mundo2Intro] Scene:", get_tree().current_scene.scene_file_path)
	print("[Mundo2Intro] GameData.intro_mundo2_done =", GameData.intro_mundo2_done)

	# DEBUG: confirma que los nodos existen
	print("[Mundo2Intro] black_rect =", black_rect)
	print("[Mundo2Intro] anim =", anim, " has FadeTrans? ->", (anim != null and anim.has_animation(fade_anim_name)))
	print("[Mundo2Intro] breath_audio =", breath_audio)

	# ✅ Overlay off por defecto (para loads/retries)
	_force_overlay_off()

	# ⚠️ Si esto sale TRUE aquí, NUNCA verás fade/dialogo
	if bool(GameData.intro_mundo2_done):
		print("[Mundo2Intro] SALTANDO INTRO porque intro_mundo2_done=true")
		_start_world2_music(true)
		return

	if _running:
		print("[Mundo2Intro] Ya estaba corriendo, evitando reentrar.")
		return

	_running = true

	# IMPORTANTE: arrancar en deferred para asegurar que el árbol/UI ya está listo
	call_deferred("_start_intro_deferred")

func _start_intro_deferred() -> void:
	print("[Mundo2Intro] _start_intro_deferred() ejecutando...")
	await _run_intro_once()

func _force_overlay_off() -> void:
	if black_rect == null:
		print("[Mundo2Intro] ❌ black_rect is null (ruta CanvasLayer/ColorRect mal)")
		return
	black_rect.visible = false
	var c: Color = black_rect.modulate
	c.a = 0.0
	black_rect.modulate = c
	print("[Mundo2Intro] Overlay OFF")

func _force_overlay_on() -> void:
	if black_rect == null:
		print("[Mundo2Intro] ❌ black_rect is null (ruta CanvasLayer/ColorRect mal)")
		return
	black_rect.visible = true
	var c: Color = black_rect.modulate
	c.a = 1.0
	black_rect.modulate = c
	print("[Mundo2Intro] Overlay ON")

func _run_intro_once() -> void:
	print("[Mundo2Intro] >>> INICIANDO INTRO ONCE")

	# 0) Negro al inicio
	_force_overlay_on()

	# 1) Respiración
	if breath_audio:
		print("[Mundo2Intro] breath_audio.play()")
		breath_audio.play()
	else:
		print("[Mundo2Intro] ⚠️ No breath_audio")

	# 2) Anim Fade
	if anim == null:
		print("[Mundo2Intro] ❌ anim is null (ruta CanvasLayer/IntroAnim mal)")
		await get_tree().create_timer(1.0).timeout
	else:
		print("[Mundo2Intro] Animations disponibles:", anim.get_animation_list())
		if anim.has_animation(fade_anim_name):
			print("[Mundo2Intro] anim.play(", fade_anim_name, ")")
			anim.play(fade_anim_name)
			await anim.animation_finished
			print("[Mundo2Intro] anim.animation_finished OK")
		else:
			print("[Mundo2Intro] ❌ NO existe anim '" + fade_anim_name + "' en IntroAnim")
			await get_tree().create_timer(2.5).timeout

	# 3) Apagar overlay sí o sí
	_force_overlay_off()

	# 4) Diálogo
	var dialogue_res: Resource = _load_intro_dialogue()
	print("[Mundo2Intro] dialogue_res =", dialogue_res)

	if dialogue_res != null:
		_show_intro_dialogue(dialogue_res)
		await _wait_dialogue_ended(dialogue_res)
	else:
		print("[Mundo2Intro] ⚠️ No dialogue resource, skip")
		await get_tree().create_timer(0.2).timeout

	# 5) Flag + autosave opcional
	GameData.intro_mundo2_done = true
	print("[Mundo2Intro] intro_mundo2_done = true (marcado)")

	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		print("[Mundo2Intro] Guardando SaveManager.save_from_gamedata()")
		sm.save_from_gamedata(GameData)
	else:
		print("[Mundo2Intro] ⚠️ No SaveManager o no save_from_gamedata()")

	# 6) Música
	_start_world2_music(true)

	print("[Mundo2Intro] >>> FIN INTRO ONCE")

func _load_intro_dialogue() -> Resource:
	if intro_dialogue_path.strip_edges() == "":
		print("[Mundo2Intro] ❌ intro_dialogue_path vacío")
		return null

	if not ResourceLoader.exists(intro_dialogue_path):
		print("[Mundo2Intro] ❌ No existe:", intro_dialogue_path)
		return null

	var res: Resource = load(intro_dialogue_path)
	if res == null:
		print("[Mundo2Intro] ❌ load() devolvió null:", intro_dialogue_path)
		return null

	return res

func _show_intro_dialogue(dialogue_res: Resource) -> void:
	print("[Mundo2Intro] _show_intro_dialogue key =", intro_dialogue_key)

	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		print("[Mundo2Intro] Engine DialogueManager =", dm)
		if dm != null and dm.has_method("show_dialogue_balloon"):
			print("[Mundo2Intro] dm.show_dialogue_balloon()")
			dm.call("show_dialogue_balloon", dialogue_res, intro_dialogue_key)
			return
		else:
			print("[Mundo2Intro] ❌ Singleton DialogueManager sin show_dialogue_balloon()")

	var dm_node := get_node_or_null("/root/DialogueManager")
	print("[Mundo2Intro] /root/DialogueManager =", dm_node)
	if dm_node != null and dm_node.has_method("show_dialogue_balloon"):
		print("[Mundo2Intro] /root DialogueManager show_dialogue_balloon()")
		dm_node.call("show_dialogue_balloon", dialogue_res, intro_dialogue_key)
		return

	print("[Mundo2Intro] ❌ DialogueManager NO encontrado o sin método show_dialogue_balloon")

func _wait_dialogue_ended(dialogue_res: Resource) -> void:
	print("[Mundo2Intro] Esperando DialogueManager.dialogue_ended ...")

	# Si el nodo ya no está en escena, aborta
	if not is_inside_tree():
		print("[Mundo2Intro] Abort wait: no estoy dentro del árbol.")
		return

	# Si no existe el autoload real, no esperamos
	var dm_node := get_node_or_null("/root/DialogueManager")
	if dm_node == null and not Engine.has_singleton("DialogueManager"):
		print("[Mundo2Intro] ⚠️ No hay DialogueManager accesible, no espero.")
		return

	# ✅ Espera por señal real (como en tu ChaseManager)
	var max_wait := 45.0
	var timer := get_tree().create_timer(max_wait)
	while true:
		# Si nos sacaron del árbol por cambio de escena, abortar limpio
		if not is_inside_tree():
			print("[Mundo2Intro] Abort wait: salí del árbol durante la espera.")
			return

		# Espera a cualquiera de estas dos cosas:
		# 1) que termine el diálogo (señal)
		# 2) timeout
		var ended_res: Resource = null

		# Espera “dialogue_ended” si existe la clase DialogueManager global
		if typeof(DialogueManager) != TYPE_NIL:
			ended_res = await DialogueManager.dialogue_ended
			print("[Mundo2Intro] dialogue_ended recibido:", ended_res)
			return

		# Si no, solo evita crash y sal por timeout (no nos inventamos estado)
		await timer.timeout
		print("[Mundo2Intro] ⚠️ Timeout esperando diálogo.")
		return


	# Intento real de esperar señal (bloque corto)
	# Si el autoload existe como clase, esto funcionará:
	if typeof(DialogueManager) != TYPE_NIL:
		var ended_res: Resource = await DialogueManager.dialogue_ended
		print("[Mundo2Intro] dialogue_ended recibido:", ended_res)
		# (si quieres validar que sea el mismo)
		return

	print("[Mundo2Intro] ⚠️ Timeout esperando diálogo.")

func _start_world2_music(restart: bool) -> void:
	print("[Mundo2Intro] _start_world2_music restart=", restart)

	if world2_music_stream == null:
		print("[Mundo2Intro] ❌ world2_music_stream null")
		return

	if MusicManager != null and MusicManager.has_method("play_stream"):
		MusicManager.play_stream(world2_music_stream, world2_music_fade_in, restart)
		print("[Mundo2Intro] MusicManager.play_stream OK")
	else:
		print("[Mundo2Intro] ❌ MusicManager null o sin play_stream()")
