extends Control

@export var loading_scene_path: String = "res://Pantallas/PantallaCarga.tscn"

# Mundo inicial por defecto (NEW GAME)
@export var default_world_path: String = "res://Modelos_Blender/Terrerno_de_mundo1/Mundo1.tscn"
@export var default_checkpoint_id: String = "start"

@onready var slot1_panel: Panel = $HBoxContainer/Slot1
@onready var slot2_panel: Panel = $HBoxContainer/Slot2
@onready var reset_all_btn: Button = $ButtonResetAll

var _reset_armed: bool = false

func _ready() -> void:
	get_node("/root/SaveIndicator").set_enabled(false)
	print("[MenuSlots] READY. player_name =", GameData.player_name)
	
	MusicManager.play_menu()

	_setup_slot(slot1_panel, 1)
	_setup_slot(slot2_panel, 2)
	refresh_all()

	# Botón borrar todo
	if reset_all_btn == null:
		push_error("[MenuSlots] No existe ButtonResetAll en el Control raíz.")
	else:
		if not reset_all_btn.pressed.is_connected(_on_reset_all_pressed):
			reset_all_btn.pressed.connect(_on_reset_all_pressed)
		reset_all_btn.text = "BORRAR TODO"

func _setup_slot(panel: Panel, slot_id: int) -> void:
	if panel == null:
		push_error("[MenuSlots] Slot%d panel es null. Revisa la ruta $HBoxContainer/Slot%d" % [slot_id, slot_id])
		return

	var btn: Button = panel.get_node_or_null("BoxContainer/ButtonAction")
	if btn == null:
		push_error("[MenuSlots] Slot%d: NO existe BoxContainer/ButtonAction" % slot_id)
		return

	btn.set_meta("slot_id", slot_id)

	if not btn.pressed.is_connected(_on_slot_button_pressed):
		btn.pressed.connect(_on_slot_button_pressed)

func refresh_all() -> void:
	_refresh_slot(slot1_panel, 1)
	_refresh_slot(slot2_panel, 2)

func _refresh_slot(panel: Panel, slot_id: int) -> void:
	var owner_label: Label = panel.get_node_or_null("BoxContainer/LabelOwner")
	var time_label: Label = panel.get_node_or_null("BoxContainer/LabelTime")
	var button: Button = panel.get_node_or_null("BoxContainer/ButtonAction")

	if owner_label == null:
		push_error("[MenuSlots] Slot%d: NO existe BoxContainer/LabelOwner" % slot_id)
		return
	if time_label == null:
		push_error("[MenuSlots] Slot%d: NO existe BoxContainer/LabelTime" % slot_id)
		return
	if button == null:
		push_error("[MenuSlots] Slot%d: NO existe BoxContainer/ButtonAction" % slot_id)
		return

	var data: Dictionary = SaveManager.get_slot(slot_id)

	if data.get("used", false):
		owner_label.text = "OWNER: " + str(data.get("owner_name", ""))
		time_label.text = "TIME: " + _format_time(float(data.get("play_time", 0.0)))
		button.text = "LOAD"
	else:
		owner_label.text = "OWNER: " + GameData.player_name
		time_label.text = "TIME: --:--:--"
		button.text = "CREATE"

func _on_slot_button_pressed() -> void:
	# Detecta qué botón se presionó revisando hover, si no, focus
	var b1: Button = slot1_panel.get_node_or_null("BoxContainer/ButtonAction")
	var b2: Button = slot2_panel.get_node_or_null("BoxContainer/ButtonAction")

	var btn: Button = null
	if b1 != null and b1.is_hovered():
		btn = b1
	elif b2 != null and b2.is_hovered():
		btn = b2
	else:
		btn = get_viewport().gui_get_focus_owner() as Button

	if btn == null or not btn.has_meta("slot_id"):
		push_error("[MenuSlots] No pude identificar qué slot se presionó (hover/focus falló).")
		return

	var slot_id: int = int(btn.get_meta("slot_id"))
	print("[MenuSlots] pressed slot:", slot_id)

	var data := SaveManager.get_slot(slot_id)
	if data.get("used", false):
		_load_slot(slot_id)
	else:
		
		_create_slot(slot_id)

# -------------------------
# CREATE (NEW GAME REAL)
# -------------------------
func _create_slot(slot_id: int) -> void:
	if GameData.player_name.strip_edges() == "":
		push_error("[MenuSlots] GameData.player_name vacío. Asegúrate de venir de Register.")
		return

	GameData.current_slot_id = slot_id

	# ✅ NEW GAME: resetea flags y progreso (mantén aquí TODOS tus flags importantes)
	GameData.intro_done = false
	GameData.has_flashlight = false
	GameData.buscar_linterna_done = false
	GameData.flashlight_on = false
	GameData.hoja_encontrada_done = false
	GameData.intro_mundo2_done = false


	# si existen en tu GameData (no crashea si no existen)
	if "intro_mundo2_done" in GameData: GameData.intro_mundo2_done = false
	if "muneco_antiguo_done" in GameData: GameData.muneco_antiguo_done = false
	if "angel_statua_done" in GameData: GameData.angel_statua_done = false
	if "letrero_viejo_done" in GameData: GameData.letrero_viejo_done = false
	if "roca_accidente_done" in GameData: GameData.roca_accidente_done = false
	if "arbol_caido_done" in GameData: GameData.arbol_caido_done = false

	# Atmosphere stage guardado (si lo tienes)
	if "atmosphere_stage" in GameData: GameData.atmosphere_stage = 0
	if "music_intensity" in GameData: GameData.music_intensity = 0

	GameData.current_scene_path = default_world_path
	GameData.current_checkpoint_id = default_checkpoint_id

	# Tiempo en cero
	GameData.reset_survival_time()

	# ✅ crea slot y guarda progreso (universal)
	SaveManager.save_slot(slot_id, GameData.player_name, 0.0)
	SaveManager.save_from_gamedata(GameData)

	GameData.start_survival_timer()

	print("[MenuSlots] CREATE OK ->", loading_scene_path, "world:", GameData.current_scene_path, "cp:", GameData.current_checkpoint_id)
	refresh_all()
	_go_to_loading()

# -------------------------
# LOAD (FIX REAL)
# -------------------------
func _load_slot(slot_id: int) -> void:
	# ✅ ESTE ES EL FIX: aplicar gamedata dict (o fallback legacy) al GameData
	SaveManager.load_into_gamedata(slot_id, GameData)

	# ✅ marca load para que Player/Intro no repitan cosas
	if "is_loading" in GameData:
		GameData.is_loading = true

	# por seguridad: si no tiene linterna, no puede estar encendida
	if not bool(GameData.has_flashlight):
		GameData.flashlight_on = false

	GameData.start_survival_timer()

	print("[MenuSlots] LOAD OK ->", loading_scene_path,
		"world:", GameData.current_scene_path,
		"cp:", GameData.current_checkpoint_id,
		"has_flashlight:", GameData.has_flashlight,
		"flash_on:", GameData.flashlight_on
	)

	_go_to_loading()

func _go_to_loading() -> void:
	if ResourceLoader.exists(loading_scene_path):
		get_tree().change_scene_to_file(loading_scene_path)
	else:
		push_error("[MenuSlots] No existe loading_scene_path: " + loading_scene_path)

# -------------------------------
# BOTÓN BORRAR TODO (CONFIRMACIÓN)
# -------------------------------
func _on_reset_all_pressed() -> void:
	if reset_all_btn == null:
		return

	if not _reset_armed:
		_reset_armed = true
		reset_all_btn.text = "CONFIRMAR"
		print("[MenuSlots] Reset armado. Pulsa otra vez para confirmar.")

		await get_tree().create_timer(2.0).timeout

		if _reset_armed:
			_reset_armed = false
			reset_all_btn.text = "BORRAR TODO"
			print("[MenuSlots] Reset cancelado por tiempo.")
		return

	_reset_armed = false
	reset_all_btn.text = "BORRAR TODO"

	if not SaveManager.has_method("reset_all"):
		push_error("[MenuSlots] SaveManager no tiene reset_all().")
		return

	SaveManager.reset_all()
	print("[MenuSlots] All slots reset (file).")

	# resetear GameData también
	GameData.current_slot_id = 0
	GameData.reset_survival_time()

	GameData.intro_done = false
	GameData.has_flashlight = false
	GameData.buscar_linterna_done = false
	GameData.flashlight_on = false
	GameData.hoja_encontrada_done = false

	if "intro_mundo2_done" in GameData: GameData.intro_mundo2_done = false
	if "muneco_antiguo_done" in GameData: GameData.muneco_antiguo_done = false
	if "angel_statua_done" in GameData: GameData.angel_statua_done = false
	if "letrero_viejo_done" in GameData: GameData.letrero_viejo_done = false
	if "roca_accidente_done" in GameData: GameData.roca_accidente_done = false
	if "arbol_caido_done" in GameData: GameData.arbol_caido_done = false

	GameData.current_scene_path = ""
	GameData.current_checkpoint_id = ""

	refresh_all()

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	return "%02d:%02d:%02d" % [h, m, s]
