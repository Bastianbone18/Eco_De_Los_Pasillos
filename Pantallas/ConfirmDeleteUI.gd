extends Control

signal confirmed(slot_id: int)

@onready var fondo: ColorRect = $ColorRect
@onready var panel: Panel = $Panel
@onready var texto: Label = $Panel/texto
@onready var btn_confirmar: Button = $Panel/HBoxContainer/Confirmar
@onready var btn_cancelar: Button = $Panel/HBoxContainer/Cancelar

var current_slot_id: int = 0
var is_open: bool = false
var animating: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	if btn_confirmar and not btn_confirmar.pressed.is_connected(_on_confirmar_pressed):
		btn_confirmar.pressed.connect(_on_confirmar_pressed)

	if btn_cancelar and not btn_cancelar.pressed.is_connected(_on_cancelar_pressed):
		btn_cancelar.pressed.connect(_on_cancelar_pressed)

	_prepare_hidden_state()

func _prepare_hidden_state() -> void:
	if fondo:
		var c := fondo.color
		c.a = 0.0
		fondo.color = c

	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.92, 0.92)
		panel.pivot_offset = panel.size * 0.5

func show_popup(slot_id: int) -> void:
	if animating:
		return

	current_slot_id = slot_id
	is_open = true
	animating = true
	visible = true

	if texto:
		texto.text = "¿Seguro que deseas borrar este slot?\nEsta acción no se puede deshacer."

	_prepare_hidden_state()

	var tween := create_tween()
	tween.set_parallel(true)

	if fondo:
		tween.tween_property(fondo, "color:a", 0.60, 0.18)

	if panel:
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished

	animating = false

	if btn_cancelar:
		btn_cancelar.grab_focus()

func hide_popup() -> void:
	if animating or not is_open:
		return

	animating = true
	is_open = false

	var tween := create_tween()
	tween.set_parallel(true)

	if fondo:
		tween.tween_property(fondo, "color:a", 0.0, 0.14)

	if panel:
		tween.tween_property(panel, "modulate:a", 0.0, 0.14)
		tween.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	current_slot_id = 0
	visible = false
	animating = false

func _on_confirmar_pressed() -> void:
	if animating:
		return

	var slot_to_delete := current_slot_id
	emit_signal("confirmed", slot_to_delete)
	hide_popup()

func _on_cancelar_pressed() -> void:
	if animating:
		return

	hide_popup()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_popup()
		get_viewport().set_input_as_handled()
