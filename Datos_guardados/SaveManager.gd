extends Node

signal save_started
signal save_finished
signal save_failed(err_msg: String)

const SAVE_PATH: String = "user://saves.json"

func reset_all() -> void:
	_write(_default_data(), false)

func _default_data() -> Dictionary:
	return {
		"slots": {
			"1": _default_slot(),
			"2": _default_slot(),
		}
	}

func _default_slot() -> Dictionary:
	return {
		"used": false,
		"owner_name": "",
		"play_time": 0.0,
		"last_played": 0,

		# legacy
		"scene_path": "",
		"checkpoint_id": "",
		"intro_done": false,
		"has_flashlight": false,
		"buscar_linterna_done": false,
		"flashlight_on": false,
		"hoja_encontrada_done": false,

		# legacy nuevos
		"roca_accidente_done": false,
		"arbol_caido_done": false,

		# universal
		"gamedata": {}
	}

func load_all() -> Dictionary:
	# Si no existe, crea archivo con default
	if not FileAccess.file_exists(SAVE_PATH):
		var d: Dictionary = _default_data()
		_write(d, false)
		return d

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		var d2: Dictionary = _default_data()
		_write(d2, false)
		return d2

	var text: String = f.get_as_text()
	f.close()

	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		var d3: Dictionary = _default_data()
		_write(d3, false)
		return d3

	var raw: Variant = json.get_data()
	if typeof(raw) != TYPE_DICTIONARY:
		var d4: Dictionary = _default_data()
		_write(d4, false)
		return d4

	var data: Dictionary = raw as Dictionary

	# Asegurar estructura
	if not data.has("slots"):
		data["slots"] = {}

	var def: Dictionary = _default_data()
	for id in ["1","2"]:
		var slots: Dictionary = data["slots"] as Dictionary
		if not slots.has(id):
			slots[id] = def["slots"][id]
		else:
			_ensure_slot_keys(slots[id] as Dictionary, def["slots"][id] as Dictionary)
		data["slots"] = slots

	return data

func _ensure_slot_keys(slot: Dictionary, def_slot: Dictionary) -> void:
	for k in def_slot.keys():
		if not slot.has(k):
			slot[k] = def_slot[k]

	# tipos básicos
	slot["used"] = bool(slot.get("used", false))
	slot["owner_name"] = str(slot.get("owner_name", ""))
	slot["play_time"] = float(slot.get("play_time", 0.0))
	slot["last_played"] = int(slot.get("last_played", 0))

	# gamedata dict
	var gdv_raw: Variant = slot.get("gamedata", {})
	var gdv: Dictionary = {}
	if typeof(gdv_raw) == TYPE_DICTIONARY:
		gdv = gdv_raw as Dictionary
	slot["gamedata"] = gdv

func get_slot(slot_id: int) -> Dictionary:
	var data: Dictionary = load_all()
	var slots: Dictionary = data["slots"] as Dictionary
	return slots[str(slot_id)] as Dictionary

func save_slot(slot_id: int, owner_name: String, play_time: float) -> void:
	# Guardado de MENU (NO mostrar indicador)
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	var slot: Dictionary = slots[id] as Dictionary

	slot["used"] = true
	slot["owner_name"] = owner_name
	slot["play_time"] = max(play_time, 0.0)
	slot["last_played"] = Time.get_unix_time_from_system()

	slots[id] = slot
	data["slots"] = slots

	_write(data, false)

# -------------------------------------------------------
# ✅ Guardar dict universal EN saves.json
# -------------------------------------------------------
func save_dict(slot_id: int, player_name: String, gd_dict: Dictionary, notify: bool = true) -> void:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	if not slots.has(id):
		push_warning("[SaveManager] Slot no existe: " + id)
		return

	var slot: Dictionary = slots[id] as Dictionary

	slot["used"] = true
	slot["owner_name"] = player_name
	slot["last_played"] = Time.get_unix_time_from_system()

	slot["gamedata"] = gd_dict

	# actualizar legacy para menú
	slot["scene_path"] = str(gd_dict.get("scene_path", slot.get("scene_path", "")))
	slot["checkpoint_id"] = str(gd_dict.get("checkpoint_id", slot.get("checkpoint_id", "")))
	slot["play_time"] = float(gd_dict.get("play_time", slot.get("play_time", 0.0)))

	slots[id] = slot
	data["slots"] = slots

	_write(data, notify)
	print("[SaveManager] Guardado (dict en saves.json): slot=", slot_id, " cp=", slot["checkpoint_id"])

func clear_slot(slot_id: int) -> void:
	# Borrar slot desde MENU (NO mostrar indicador)
	var data: Dictionary = load_all()
	var slots: Dictionary = data["slots"] as Dictionary
	slots[str(slot_id)] = _default_slot()
	data["slots"] = slots
	_write(data, false)

# -------------------------------------------------------
# Guardar checkpoint SOLO (AUTOSAVE en mundo) -> SI muestra indicador
# -------------------------------------------------------
func save_checkpoint(slot_id: int, scene_path: String, checkpoint_id: String) -> void:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	var slot: Dictionary = slots[id] as Dictionary

	if not bool(slot.get("used", false)):
		return

	slot["scene_path"] = scene_path
	slot["checkpoint_id"] = checkpoint_id
	slot["last_played"] = Time.get_unix_time_from_system()

	slots[id] = slot
	data["slots"] = slots

	_write(data, true)

# -------------------------------------------------------
# Guardado COMPLETO (legacy) -> SI muestra indicador
# -------------------------------------------------------
func save_progress(
	slot_id: int,
	owner_name: String,
	play_time: float,
	scene_path: String,
	checkpoint_id: String,
	intro_done: bool,
	has_flashlight: bool,
	buscar_linterna_done: bool,
	flashlight_on: bool,
	hoja_encontrada_done: bool,
	roca_accidente_done: bool = false,
	arbol_caido_done: bool = false
) -> void:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	var slot: Dictionary = slots[id] as Dictionary

	slot["used"] = true
	slot["owner_name"] = owner_name
	slot["play_time"] = max(play_time, 0.0)
	slot["scene_path"] = scene_path
	slot["checkpoint_id"] = checkpoint_id
	slot["intro_done"] = intro_done
	slot["has_flashlight"] = has_flashlight
	slot["buscar_linterna_done"] = buscar_linterna_done
	slot["flashlight_on"] = flashlight_on
	slot["hoja_encontrada_done"] = hoja_encontrada_done
	slot["roca_accidente_done"] = roca_accidente_done
	slot["arbol_caido_done"] = arbol_caido_done
	slot["last_played"] = Time.get_unix_time_from_system()

	slots[id] = slot
	data["slots"] = slots

	_write(data, true)

func get_checkpoint(slot_id: int) -> Dictionary:
	var s: Dictionary = get_slot(slot_id)
	return {
		"scene_path": str(s.get("scene_path", "")),
		"checkpoint_id": str(s.get("checkpoint_id", ""))
	}

# -------------------------------------------------------
# ✅ Guardar directo desde GameData (AUTOSAVE)
# -------------------------------------------------------
func save_from_gamedata(gd: Node) -> void:
	var slot_id: int = int(gd.current_slot_id)
	var owner_name: String = str(gd.player_name)
	if slot_id <= 0:
		return

	gd.stop_survival_timer()

	if gd.has_method("to_save_dict"):
		var gd_dict: Dictionary = gd.to_save_dict()
		save_dict(slot_id, owner_name, gd_dict, true)
	else:
		save_progress(
			slot_id,
			owner_name,
			float(gd.get_total_survival_time()),
			str(gd.current_scene_path),
			str(gd.current_checkpoint_id),
			bool(gd.intro_done),
			bool(gd.has_flashlight),
			bool(gd.buscar_linterna_done),
			bool(gd.flashlight_on),
			bool(gd.hoja_encontrada_done),
			bool(gd.roca_accidente_done),
			bool(gd.arbol_caido_done)
		)

	gd.start_survival_timer()

# -------------------------------------------------------
# ✅ Cargar slot y aplicarlo a GameData
# -------------------------------------------------------
func load_into_gamedata(slot_id: int, gd: Node) -> void:
	var s: Dictionary = get_slot(slot_id)

	gd.current_slot_id = slot_id
	gd.player_name = str(s.get("owner_name", gd.player_name))

	# 1) Universal dict
	var gdd_raw: Variant = s.get("gamedata", {})
	if typeof(gdd_raw) == TYPE_DICTIONARY:
		var gdd: Dictionary = gdd_raw as Dictionary
		if gdd.size() > 0 and gd.has_method("apply_save_dict"):
			gd.apply_save_dict(gdd)
			gd.current_slot_id = slot_id
			gd.player_name = str(s.get("owner_name", gd.player_name))
			return

	# 2) Legacy fallback
	gd.current_scene_path = str(s.get("scene_path", ""))
	gd.current_checkpoint_id = str(s.get("checkpoint_id", ""))

	gd.intro_done = bool(s.get("intro_done", false))
	gd.has_flashlight = bool(s.get("has_flashlight", false))
	gd.buscar_linterna_done = bool(s.get("buscar_linterna_done", false))
	gd.flashlight_on = bool(s.get("flashlight_on", false))
	gd.hoja_encontrada_done = bool(s.get("hoja_encontrada_done", false))

	gd.roca_accidente_done = bool(s.get("roca_accidente_done", false))
	gd.arbol_caido_done = bool(s.get("arbol_caido_done", false))

	if s.has("play_time"):
		gd.set_survival_time(float(s.get("play_time", 0.0)))

# -------------------------------------------------------
# Escritura al disco con notify opcional
# -------------------------------------------------------
func _write(data: Dictionary, notify: bool = false) -> void:
	if notify:
		emit_signal("save_started")

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		if notify:
			emit_signal("save_failed", "FileAccess.open() devolvió null")
			emit_signal("save_finished")
		return

	f.store_string(JSON.stringify(data, "\t"))
	f.close()

	if notify:
		emit_signal("save_finished")
