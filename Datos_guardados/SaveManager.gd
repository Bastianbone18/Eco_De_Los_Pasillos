extends Node

signal save_started
signal save_finished
signal save_failed(err_msg: String)

const SAVE_DIR: String = "user://save_data"
const SAVE_PATH: String = "user://save_data/saves.json"

# ==================================================
# INIT
# ==================================================

func _ready() -> void:
	print("[SaveManager] user:// real = ", OS.get_user_data_dir())
	print("[SaveManager] SAVE_DIR = ", SAVE_DIR)
	print("[SaveManager] SAVE_PATH = ", SAVE_PATH)
	_ensure_save_system()

func _ensure_save_system() -> void:
	var err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[SaveManager] No se pudo crear SAVE_DIR: " + SAVE_DIR + " | err=" + str(err))
		return

	if not FileAccess.file_exists(SAVE_PATH):
		var d: Dictionary = _default_data()
		var ok := _write(d, false)
		if not ok:
			push_warning("[SaveManager] No se pudo crear saves.json inicial")

# ==================================================
# RESET / DEFAULTS
# ==================================================

func reset_all() -> void:
	_write(_default_data(), false)

func _default_data() -> Dictionary:
	return {
		"slots": {
			"1": _default_slot(),
			"2": _default_slot()
		}
	}

func _default_slot() -> Dictionary:
	return {
		"used": false,
		"owner_name": "",
		"play_time": 0.0,
		"last_played": 0,

		# compat legacy
		"scene_path": "",
		"checkpoint_id": "",
		"intro_done": false,
		"has_flashlight": false,
		"buscar_linterna_done": false,
		"flashlight_on": false,
		"hoja_encontrada_done": false,
		"roca_accidente_done": false,
		"arbol_caido_done": false,

		# sistema actual
		"gamedata": {}
	}

# ==================================================
# LOAD ALL
# ==================================================

func load_all() -> Dictionary:
	_ensure_save_system()

	if not FileAccess.file_exists(SAVE_PATH):
		var d: Dictionary = _default_data()
		_write(d, false)
		return d

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] No se pudo abrir SAVE_PATH para lectura: " + SAVE_PATH)
		var d2: Dictionary = _default_data()
		_write(d2, false)
		return d2

	var text: String = f.get_as_text()
	f.close()

	if text.strip_edges() == "":
		push_warning("[SaveManager] saves.json vacío, recreando.")
		var d_empty: Dictionary = _default_data()
		_write(d_empty, false)
		return d_empty

	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_warning("[SaveManager] JSON inválido en saves.json, recreando.")
		var d3: Dictionary = _default_data()
		_write(d3, false)
		return d3

	var raw: Variant = json.get_data()
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("[SaveManager] saves.json no contiene un Dictionary válido, recreando.")
		var d4: Dictionary = _default_data()
		_write(d4, false)
		return d4

	var data: Dictionary = raw as Dictionary

	if not data.has("slots"):
		data["slots"] = {}

	var slots: Dictionary = data["slots"] as Dictionary
	var def: Dictionary = _default_data()
	var def_slots: Dictionary = def["slots"] as Dictionary

	for id in ["1", "2"]:
		if not slots.has(id):
			slots[id] = def_slots[id]
		else:
			var slot_var: Variant = slots[id]
			if typeof(slot_var) != TYPE_DICTIONARY:
				slots[id] = def_slots[id]
			else:
				var slot_dict: Dictionary = slot_var as Dictionary
				var def_slot_dict: Dictionary = def_slots[id] as Dictionary
				_ensure_slot_keys(slot_dict, def_slot_dict)
				slots[id] = slot_dict

	data["slots"] = slots
	return data

func _ensure_slot_keys(slot: Dictionary, def_slot: Dictionary) -> void:
	for k in def_slot.keys():
		if not slot.has(k):
			slot[k] = def_slot[k]

	slot["used"] = bool(slot.get("used", false))
	slot["owner_name"] = str(slot.get("owner_name", ""))
	slot["play_time"] = float(slot.get("play_time", 0.0))
	slot["last_played"] = int(slot.get("last_played", 0))

	var gdv_raw: Variant = slot.get("gamedata", {})
	var gdv: Dictionary = {}
	if typeof(gdv_raw) == TYPE_DICTIONARY:
		gdv = gdv_raw as Dictionary
	slot["gamedata"] = gdv

# ==================================================
# SLOT HELPERS
# ==================================================

func get_slot(slot_id: int) -> Dictionary:
	var data: Dictionary = load_all()
	var slots: Dictionary = data["slots"] as Dictionary

	if not slots.has(str(slot_id)):
		push_warning("[SaveManager] get_slot(): slot inválido -> " + str(slot_id))
		return _default_slot()

	var s_raw: Variant = slots[str(slot_id)]
	if typeof(s_raw) != TYPE_DICTIONARY:
		return _default_slot()

	return s_raw as Dictionary

func slot_exists(slot_id: int) -> bool:
	var s: Dictionary = get_slot(slot_id)
	return bool(s.get("used", false))

func save_slot(slot_id: int, owner_name: String, play_time: float) -> void:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	if not slots.has(id):
		push_warning("[SaveManager] save_slot(): Slot no existe: " + id)
		return

	var slot: Dictionary = slots[id] as Dictionary

	slot["used"] = true
	slot["owner_name"] = owner_name
	slot["play_time"] = max(play_time, 0.0)
	slot["last_played"] = Time.get_unix_time_from_system()

	slots[id] = slot
	data["slots"] = slots

	_write(data, false)

func delete_slot(slot_id: int) -> void:
	clear_slot(slot_id)
	print("[SaveManager] Slot borrado:", slot_id)

func clear_slot(slot_id: int) -> void:
	var data: Dictionary = load_all()
	var slots: Dictionary = data["slots"] as Dictionary
	var id := str(slot_id)

	if not slots.has(id):
		push_warning("[SaveManager] clear_slot(): Slot no existe: " + id)
		return

	slots[id] = _default_slot()
	data["slots"] = slots
	_write(data, false)

# ==================================================
# SAVE ACTUAL
# ==================================================

func save_dict(slot_id: int, player_name: String, gd_dict: Dictionary, notify: bool = true) -> bool:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	if not slots.has(id):
		push_warning("[SaveManager] save_dict(): Slot no existe: " + id)
		return false

	var slot: Dictionary = slots[id] as Dictionary

	slot["used"] = true
	slot["owner_name"] = player_name
	slot["last_played"] = Time.get_unix_time_from_system()
	slot["gamedata"] = gd_dict.duplicate(true)

	slot["scene_path"] = str(gd_dict.get("scene_path", slot.get("scene_path", "")))
	slot["checkpoint_id"] = str(gd_dict.get("checkpoint_id", slot.get("checkpoint_id", "")))
	slot["play_time"] = float(gd_dict.get("play_time", slot.get("play_time", 0.0)))

	slots[id] = slot
	data["slots"] = slots

	var ok := _write(data, notify)
	if ok:
		print("[SaveManager] Guardado OK -> slot=", slot_id, " path=", SAVE_PATH)
	else:
		print("[SaveManager] Guardado FALLÓ -> slot=", slot_id)

	return ok

func save_checkpoint(slot_id: int, scene_path: String, checkpoint_id: String) -> void:
	var data: Dictionary = load_all()
	var id: String = str(slot_id)

	var slots: Dictionary = data["slots"] as Dictionary
	if not slots.has(id):
		push_warning("[SaveManager] save_checkpoint(): Slot no existe: " + id)
		return

	var slot: Dictionary = slots[id] as Dictionary

	if not bool(slot.get("used", false)):
		return

	slot["scene_path"] = scene_path
	slot["checkpoint_id"] = checkpoint_id
	slot["last_played"] = Time.get_unix_time_from_system()

	slots[id] = slot
	data["slots"] = slots

	_write(data, true)

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
	if not slots.has(id):
		push_warning("[SaveManager] save_progress(): Slot no existe: " + id)
		return

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

func save_from_gamedata(gd: Node) -> bool:
	if gd == null:
		push_warning("[SaveManager] save_from_gamedata(): gd es null")
		return false

	var slot_id: int = int(gd.current_slot_id)
	var owner_name: String = str(gd.player_name)

	print("[SaveManager] save_from_gamedata() slot_id=", slot_id, " owner=", owner_name)

	if slot_id <= 0:
		push_warning("[SaveManager] save_from_gamedata(): current_slot_id inválido")
		return false

	if gd.has_method("stop_survival_timer"):
		gd.stop_survival_timer()

	var ok := false

	if gd.has_method("to_save_dict"):
		var gd_dict: Dictionary = gd.to_save_dict()
		ok = save_dict(slot_id, owner_name, gd_dict, true)
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
		ok = true

	if gd.has_method("start_survival_timer"):
		gd.start_survival_timer()

	return ok

func load_into_gamedata(slot_id: int, gd: Node) -> bool:
	if gd == null:
		push_warning("[SaveManager] load_into_gamedata(): gd es null")
		return false

	var s: Dictionary = get_slot(slot_id)
	if s.is_empty():
		push_warning("[SaveManager] load_into_gamedata(): slot vacío")
		return false

	gd.current_slot_id = slot_id
	gd.player_name = str(s.get("owner_name", gd.player_name))

	var gdd_raw: Variant = s.get("gamedata", {})
	if typeof(gdd_raw) == TYPE_DICTIONARY:
		var gdd: Dictionary = gdd_raw as Dictionary
		if gdd.size() > 0 and gd.has_method("apply_save_dict"):
			gd.apply_save_dict(gdd)
			gd.current_slot_id = slot_id
			gd.player_name = str(s.get("owner_name", gd.player_name))
			print("[SaveManager] LOAD OK desde gamedata -> slot=", slot_id)
			return true

	gd.current_scene_path = str(s.get("scene_path", ""))
	gd.current_checkpoint_id = str(s.get("checkpoint_id", ""))

	gd.intro_done = bool(s.get("intro_done", false))
	gd.has_flashlight = bool(s.get("has_flashlight", false))
	gd.buscar_linterna_done = bool(s.get("buscar_linterna_done", false))
	gd.flashlight_on = bool(s.get("flashlight_on", false))
	gd.hoja_encontrada_done = bool(s.get("hoja_encontrada_done", false))

	gd.roca_accidente_done = bool(s.get("roca_accidente_done", false))
	gd.arbol_caido_done = bool(s.get("arbol_caido_done", false))

	if s.has("play_time") and gd.has_method("set_survival_time"):
		gd.set_survival_time(float(s.get("play_time", 0.0)))

	print("[SaveManager] LOAD OK legacy -> slot=", slot_id)
	return true

# ==================================================
# WRITE
# ==================================================

func _write(data: Dictionary, notify: bool = false) -> bool:
	if notify:
		emit_signal("save_started")

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] Error al abrir SAVE_PATH para escritura: " + SAVE_PATH)
		if notify:
			emit_signal("save_failed", "Error al guardar")
			emit_signal("save_finished")
		return false

	f.store_string(JSON.stringify(data, "\t"))
	f.close()

	if notify:
		emit_signal("save_finished")

	print("[SaveManager] WRITE OK -> ", SAVE_PATH)
	return true
