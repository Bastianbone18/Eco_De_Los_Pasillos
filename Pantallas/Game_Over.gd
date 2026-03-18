extends Control

var messages: Array[String] = [
	"Tu historia termina aquí.",
	"La oscuridad ya te alcanzó.",
	"No todos logran salir de este lugar."
]

@onready var exit_button: Button = $VBoxContainer2/ExitButton
@onready var menu_button: Button = $VBoxContainer2/MenuButton
@onready var message_label: Label = $VBoxContainer/LabelMessage
@onready var score_label: Label = $VBoxContainer/LabelScore

@onready var click_audio: AudioStreamPlayer = $AudioStreamPlayerClick
@onready var game_over_audio: AudioStreamPlayer = $AudioStreamPlayerGameOver

@onready var animation_player: AnimationPlayer = $'GAME OVER/AnimationPlayer'
@onready var botones_anim: AnimationPlayer = $VBoxContainer2/AnimationPlayer
@onready var desvanecer_anim: AnimationPlayer = $Rojo/Desvanecer1

@onready var power_off_rect: CanvasItem = $Flash_off
@onready var power_off_anim: AnimationPlayer = $Flash_off/Flashapagar
@onready var tv_off_audio: AudioStreamPlayer = $Flash_off/TV_OFF

var message_complete: bool = false
var score_complete: bool = false
var _transitioning: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reason_text: String = ""

# ✅ Rutas reales
const SCENE_MUNDO1 := "res://Modelos_Blender/Terrerno_de_mundo1/Mundo1.tscn"
const SCENE_MUNDO2 := "res://Modelos_Blender/TerrenoMundo2/Mundo2.tscn"

func set_reason(reason: String) -> void:
	_reason_text = reason

func _ready() -> void:
	MusicManager.stop(false) # fade out
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_reset_power_off_overlay()
	_set_buttons_enabled(false)

	if desvanecer_anim and desvanecer_anim.has_animation("Desvanecer"):
		desvanecer_anim.play("Desvanecer")
		await desvanecer_anim.animation_finished

	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")
		await animation_player.animation_finished

	if game_over_audio and not game_over_audio.playing:
		game_over_audio.play()

	exit_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	exit_button.text = "Reintentar"
	menu_button.text = "Menú"

	if message_label:
		var random_message: String = messages[rng.randi_range(0, messages.size() - 1)]
		var final_msg: String = random_message
		if GameData.player_name != "":
			final_msg += " " + GameData.player_name
		if _reason_text != "":
			final_msg += "\n" + _reason_text
		await type_message(final_msg)

	await _update_survival_time_label()

	while not (message_complete and score_complete):
		await get_tree().process_frame

	if botones_anim and botones_anim.has_animation("DsBotones"):
		botones_anim.play("DsBotones")
		await botones_anim.animation_finished

	_set_buttons_enabled(true)

func _set_buttons_enabled(v: bool) -> void:
	exit_button.disabled = not v
	menu_button.disabled = not v

func type_message(texto: String, velocidad: float = 0.05) -> void:
	message_label.text = ""
	for i in texto.length():
		message_label.text += texto[i]
		await get_tree().create_timer(velocidad).timeout
	message_complete = true

func type_score(texto: String, velocidad: float = 0.05) -> void:
	score_label.text = ""
	for i in texto.length():
		score_label.text += texto[i]
		await get_tree().create_timer(velocidad).timeout
	score_complete = true

func _update_survival_time_label() -> void:
	if score_label:
		var t: float = GameData.survival_time
		if t > 0.0:
			var minutos: int = int(t) / 60
			var segundos: int = int(t) % 60
			var texto: String = "Tiempo sobrevivido: %02d:%02d" % [minutos, segundos]
			await type_score(texto)
		else:
			await type_score("Sin registro de tiempo")

func _on_retry_pressed() -> void:
	if _transitioning: return
	_transitioning = true
	_kill_game_over_audio_immediate()
	_play_click_sound()
	_set_buttons_enabled(false)
	await _play_power_off()
	_retry_load_slot()

func _on_menu_pressed() -> void:
	if _transitioning: return
	_transitioning = true
	_kill_game_over_audio_immediate()
	_play_click_sound()
	_set_buttons_enabled(false)
	await _play_power_off()

	if GameData.has_method("reset_survival_time"):
		GameData.reset_survival_time()

	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

# ==================================================
# ✅ FIX REAL: reintentar debe cargar TODO desde SaveManager (gamedata)
# ==================================================
func _retry_load_slot() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[GameOver] No existe /root/SaveManager")
		_transitioning = false
		_set_buttons_enabled(true)
		return

	var slot_id: int = int(GameData.current_slot_id)
	if slot_id <= 0:
		push_error("[GameOver] Slot inválido: " + str(slot_id))
		_transitioning = false
		_set_buttons_enabled(true)
		return

	var slot: Dictionary = sm.get_slot(slot_id)
	if not slot.get("used", false):
		push_error("[GameOver] Slot vacío: " + str(slot_id))
		_transitioning = false
		_set_buttons_enabled(true)
		return

	# ✅ CARGA COMPLETA
	if sm.has_method("load_into_gamedata"):
		sm.load_into_gamedata(slot_id, GameData)
	else:
		GameData.current_slot_id = slot_id
		GameData.current_scene_path = str(slot.get("scene_path", ""))
		GameData.current_checkpoint_id = str(slot.get("checkpoint_id", "start"))

		GameData.intro_done = bool(slot.get("intro_done", false))
		GameData.has_flashlight = bool(slot.get("has_flashlight", false))
		GameData.buscar_linterna_done = bool(slot.get("buscar_linterna_done", false))
		GameData.flashlight_on = bool(slot.get("flashlight_on", false))
		GameData.hoja_encontrada_done = bool(slot.get("hoja_encontrada_done", false))

	if not bool(GameData.has_flashlight):
		GameData.flashlight_on = false

	if "is_loading" in GameData:
		GameData.is_loading = true

	var scene_path := str(GameData.current_scene_path)
	var key := "retry"
	if scene_path == SCENE_MUNDO1:
		key = "mundo1"
	elif scene_path == SCENE_MUNDO2:
		key = "mundo2"

	if "current_world_key" in GameData:
		GameData.current_world_key = key

	get_tree().change_scene_to_file("res://Pantallas/PantallaCarga.tscn")

func _play_click_sound() -> void:
	if click_audio and not click_audio.playing:
		click_audio.play()

func _kill_game_over_audio_immediate() -> void:
	if game_over_audio:
		game_over_audio.stop()
		game_over_audio.volume_db = 0.0

func _reset_power_off_overlay() -> void:
	if power_off_anim:
		power_off_anim.stop()
	if power_off_rect:
		power_off_rect.visible = false
		var c: Color = power_off_rect.modulate
		c.a = 0.0
		power_off_rect.modulate = c

func _show_power_off_overlay() -> void:
	if power_off_rect:
		var c: Color = power_off_rect.modulate
		c.a = 1.0
		power_off_rect.modulate = c
		power_off_rect.visible = true

func _play_power_off() -> void:
	if Engine.has_singleton("MusicManager"):
		MusicManager.stop(false)

	_show_power_off_overlay()
	if tv_off_audio:
		tv_off_audio.play()

	if power_off_anim and power_off_anim.has_animation("OFF"):
		power_off_anim.play("OFF")
		await power_off_anim.animation_finished

	_reset_power_off_overlay()
