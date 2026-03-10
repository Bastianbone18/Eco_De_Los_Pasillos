extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.

@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

var resource: DialogueResource
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
var locals: Dictionary = {}
var _locale: String = TranslationServer.get_locale()

signal dialogue_finished

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

# 🔊 Nodo de sonido
@onready var blip_sound: AudioStreamPlayer = $BlipSound


# ✅ NO secuestrar foco si el mouse está capturado (gameplay)
func _maybe_grab_focus() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		balloon.focus_mode = Control.FOCUS_NONE
		return

	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()


var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		is_waiting_for_input = false
		_maybe_grab_focus()

		if not next_dialogue_line:
			emit_signal("dialogue_finished")
			queue_free()
			return

		if not is_node_ready():
			await ready

		dialogue_line = next_dialogue_line

		character_label.visible = not dialogue_line.character.is_empty()
		character_label.text = tr(dialogue_line.character, "dialogue")

		dialogue_label.hide()
		dialogue_label.dialogue_line = dialogue_line

		responses_menu.hide()
		responses_menu.set_responses(dialogue_line.responses)

		balloon.show()
		will_hide_balloon = false

		dialogue_label.show()

		if not dialogue_line.text.is_empty():
			dialogue_label.type_out()
			await dialogue_label.finished_typing

		if dialogue_line.responses.size() > 0:
			# si hay respuestas, el UI manda (mouse visible)
			balloon.focus_mode = Control.FOCUS_NONE
			responses_menu.show()

		elif dialogue_line.time != "":
			var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
			await get_tree().create_timer(time).timeout
			next(dialogue_line.next_id)

		else:
			# ✅ queda esperando input pero SIN bloquear la cámara
			is_waiting_for_input = true
			_maybe_grab_focus()
	get:
		return dialogue_line


func _ready() -> void:
	# ✅ el diálogo se pausa con el juego
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# ✅ Deja pasar movimiento del mouse
	balloon.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El menú de respuestas sí debe capturar clicks
	responses_menu.mouse_filter = Control.MOUSE_FILTER_STOP

	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	dialogue_label.spoke.connect(_on_letter_spoke)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	if not is_node_ready():
		await ready
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals

func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	get_tree().create_timer(0.1).timeout.connect(func():
		if will_hide_balloon:
			will_hide_balloon = false
			balloon.hide()
	)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# ✅ Si está pausado, el diálogo NO debe avanzar ni consumir input
	if get_tree().paused:
		return

	# ✅ Nunca bloquees el movimiento de mouse (solo clicks/teclas)
	if event is InputEventMouseMotion:
		return

	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action):
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if get_tree().paused:
		return
	next(response.next_id)

#endregion


# 🔉 Sonido tipo "blip"
func _on_letter_spoke(letter: String, index: int, speed: float) -> void:
	if get_tree().paused:
		return

	if letter != " " and letter != "\n":
		if blip_sound.playing:
			blip_sound.stop()
		blip_sound.pitch_scale = randf_range(0.9, 1.1)
		blip_sound.play()
