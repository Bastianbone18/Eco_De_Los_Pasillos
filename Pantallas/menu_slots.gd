extends Control

# ----------------------
# EXPORTS
# ----------------------
@export var loading_scene_path: String = "res://Pantallas/PantallaCarga.tscn"
@export var default_world_path: String = "res://Modelos_Blender/Terrerno_de_mundo1/Mundo1.tscn"
@export var default_checkpoint_id: String = "start"

# ----------------------
# NODOS
# ----------------------
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick
@onready var slot1_panel: Panel = $HBoxContainer/Slot1
@onready var slot2_panel: Panel = $HBoxContainer/Slot2
@onready var confirm_delete_ui = $ConfirmDeleteUI

# ----------------------
# SONIDOS
# ----------------------
var hover_sound = preload("res://Musica y sonidos/Sonidos/Click_linterna.ogg")
var click_sound = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")

const BUS_NAME: String = "Menu"

# ----------------------
# READY
# ----------------------
func _ready() -> void:
	get_node("/root/SaveIndicator").set_enabled(false)
	print("[MenuSlots] READY. player_name =", GameData.player_name)

	MusicManager.play_menu()

	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	_connect_hover_to_buttons()

	_setup_slot(slot1_panel, 1)
	_setup_slot(slot2_panel, 2)

	if confirm_delete_ui:
		confirm_delete_ui.visible = false
		if confirm_delete_ui.has_signal("confirmed"):
			if not confirm_delete_ui.confirmed.is_connected(_on_confirm_delete):
				confirm_delete_ui.confirmed.connect(_on_confirm_delete)

	refresh_all()

# ----------------------
# HOVER
# ----------------------
func _connect_hover_to_buttons() -> void:
	var botones = get_tree().get_nodes_in_group("botones")
	for button in botones:
		if not button.is_connected("mouse_entered", Callable(self, "_on_button_hover")):
			button.mouse_entered.connect(_on_button_hover)

func _on_button_hover() -> void:
	if hover_player:
		hover_player.stop()
		hover_player.stream = hover_sound
		hover_player.pitch_scale = randf_range(0.95, 1.05)
		hover_player.play()

# ----------------------
# CLICK
# ----------------------
func play_click_sound() -> void:
	if click_player:
		click_player.stop()
		click_player.stream = click_sound
		click_player.pitch_scale = randf_range(0.95, 1.05)
		click_player.play()

# ----------------------
# SETUP SLOT
# ----------------------
func _setup_slot(panel: Panel, slot_id: int) -> void:
	if panel == null:
		push_error("[MenuSlots] Slot%d panel es null." % slot_id)
		return

	var btn: Button = panel.get_node_or_null("BoxContainer/ButtonAction")
	var delete_btn: Button = panel.get_node_or_null("BoxContainer/ButtonDelete")

	if btn:
		btn.set_meta("slot_id", slot_id)
		if not btn.pressed.is_connected(_on_slot_button_pressed):
			btn.pressed.connect(_on_slot_button_pressed)
	else:
		push_error("[MenuSlots] Slot%d sin ButtonAction" % slot_id)

	if delete_btn:
		delete_btn.set_meta("slot_id", slot_id)
		if not delete_btn.pressed.is_connected(_on_delete_slot_pressed):
			delete_btn.pressed.connect(_on_delete_slot_pressed)
	else:
		push_error("[MenuSlots] Slot%d sin ButtonDelete" % slot_id)

# ----------------------
# REFRESH
# ----------------------
func refresh_all() -> void:
	_refresh_slot(slot1_panel, 1)
	_refresh_slot(slot2_panel, 2)

func _refresh_slot(panel: Panel, slot_id: int) -> void:
	if panel == null:
		return

	var owner_label: Label = panel.get_node_or_null("BoxContainer/LabelOwner")
	var time_label: Label = panel.get_node_or_null("BoxContainer/LabelTime")
	var button: Button = panel.get_node_or_null("BoxContainer/ButtonAction")
	var delete_btn: Button = panel.get_node_or_null("BoxContainer/ButtonDelete")

	var data: Dictionary = SaveManager.get_slot(slot_id)

	if data.get("used", false):
		if owner_label:
			owner_label.text = "Nombre: " + str(data.get("owner_name", ""))
		if time_label:
			time_label.text = "Tiempo: " + _format_time(float(data.get("play_time", 0.0)))
		if button:
			button.text = "Cargar"
		if delete_btn:
			delete_btn.visible = true
	else:
		if owner_label:
			owner_label.text = "Nombre: " + GameData.player_name
		if time_label:
			time_label.text = "Tiempo: --:--:--"
		if button:
			button.text = "Crear"
		if delete_btn:
			delete_btn.visible = false

# ----------------------
# BOTÓN SLOT (CREAR / CARGAR)
# ----------------------
func _on_slot_button_pressed() -> void:
	if confirm_delete_ui and confirm_delete_ui.visible:
		return

	play_click_sound()
	await get_tree().create_timer(0.05).timeout

	var btn := get_viewport().gui_get_focus_owner() as Button

	if btn == null or not btn.has_meta("slot_id"):
		push_error("[MenuSlots] No se pudo detectar slot.")
		return

	var slot_id: int = int(btn.get_meta("slot_id"))
	var data := SaveManager.get_slot(slot_id)

	if data.get("used", false):
		_load_slot(slot_id)
	else:
		_create_slot(slot_id)

# ----------------------
# BORRAR SLOT (ABRE CONFIRMACIÓN)
# ----------------------
func _on_delete_slot_pressed() -> void:
	if confirm_delete_ui and confirm_delete_ui.visible:
		return

	play_click_sound()
	await get_tree().create_timer(0.05).timeout

	var btn := get_viewport().gui_get_focus_owner() as Button

	if btn == null or not btn.has_meta("slot_id"):
		push_error("[MenuSlots] No se pudo detectar slot a borrar.")
		return

	var slot_id: int = int(btn.get_meta("slot_id"))
	print("[MenuSlots] Solicitud de borrado slot:", slot_id)

	if confirm_delete_ui and confirm_delete_ui.has_method("show_popup"):
		confirm_delete_ui.show_popup(slot_id)
	else:
		push_error("[MenuSlots] ConfirmDeleteUI no encontrado o sin método show_popup().")

# ----------------------
# CONFIRM DELETE
# ----------------------
func _on_confirm_delete(slot_id: int) -> void:
	print("[MenuSlots] DELETE CONFIRMADO slot:", slot_id)

	SaveManager.delete_slot(slot_id)

	if GameData.current_slot_id == slot_id:
		GameData.current_slot_id = 0
		GameData.reset_survival_time()

	refresh_all()

# ----------------------
# CREATE
# ----------------------
func _create_slot(slot_id: int) -> void:
	if GameData.player_name.strip_edges() == "":
		push_error("Nombre vacío.")
		return

	GameData.current_slot_id = slot_id

	GameData.intro_done = false
	GameData.has_flashlight = false
	GameData.flashlight_on = false

	GameData.current_scene_path = default_world_path
	GameData.current_checkpoint_id = default_checkpoint_id

	GameData.reset_survival_time()

	SaveManager.save_slot(slot_id, GameData.player_name, 0.0)
	SaveManager.save_from_gamedata(GameData)

	GameData.start_survival_timer()

	refresh_all()
	_go_to_loading()

# ----------------------
# LOAD
# ----------------------
func _load_slot(slot_id: int) -> void:
	SaveManager.load_into_gamedata(slot_id, GameData)
	GameData.start_survival_timer()
	_go_to_loading()

func _go_to_loading() -> void:
	if ResourceLoader.exists(loading_scene_path):
		get_tree().change_scene_to_file(loading_scene_path)

# ----------------------
# TIME FORMAT
# ----------------------
func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	return "%02d:%02d:%02d" % [h, m, s]
