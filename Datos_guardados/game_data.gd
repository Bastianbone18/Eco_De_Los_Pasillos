extends Node

var player_name := ""
var current_slot_id: int = 0

var current_scene_path: String = ""
var current_checkpoint_id: String = ""

# ==================================================
# FLAGS DE PROGRESO
# ==================================================

var intro_done: bool = false
var has_flashlight: bool = false

# Mundo 1 controles
var world1_controls_shown: bool = false

# Mundo 2 intro
var intro_mundo2_done: bool = false

# Mundo 3 intro
var intro_mundo3_done: bool = false

# muñeco antiguo
var muneco_antiguo_done: bool = false

# diálogo Buscar_linterna
var buscar_linterna_done: bool = false

# Estatua angel
var angel_statua_done: bool = false

# persecución mundo 2
var chase_capture_mode: String = "knockout"
var chase_retry_checkpoint_id: String = "before_mission2"

# estado linterna
var flashlight_on: bool = false

# hoja vieja
var hoja_encontrada_done: bool = false

# eventos mundo
var roca_accidente_done: bool = false
var arbol_caido_done: bool = false
var letrero_viejo_done: bool = false

# atmósfera mundo 2
var world2_atmos_stage: int = 0

# foto familiar
var foto_familiar_done: bool = false

# ==================================================
# TIMER
# ==================================================

var survival_time := 0.0
var _start_ticks := 0
var _running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ==================================================
# CHECKPOINTS
# ==================================================

func set_checkpoint(scene_path: String, checkpoint_id: String) -> void:
	current_scene_path = scene_path
	current_checkpoint_id = checkpoint_id


func clear_checkpoint() -> void:
	current_scene_path = ""
	current_checkpoint_id = ""


# ==================================================
# TIMER CONTROL
# ==================================================

func start_survival_timer() -> void:
	if _running:
		return
	_start_ticks = Time.get_ticks_msec()
	_running = true


func stop_survival_timer() -> void:
	if _running and _start_ticks > 0:
		var elapsed_ms := Time.get_ticks_msec() - _start_ticks
		survival_time += float(elapsed_ms) / 1000.0
	_running = false
	_start_ticks = 0


func reset_survival_time() -> void:
	survival_time = 0.0
	_start_ticks = 0
	_running = false


func set_survival_time(seconds: float) -> void:
	survival_time = max(seconds, 0.0)
	_running = false
	_start_ticks = 0


func get_total_survival_time() -> float:
	if _running and _start_ticks > 0:
		var elapsed_ms := Time.get_ticks_msec() - _start_ticks
		return survival_time + float(elapsed_ms) / 1000.0
	return survival_time


# ==================================================
# SAVE
# ==================================================

func to_save_dict() -> Dictionary:
	return {
		# escena
		"scene_path": current_scene_path,
		"checkpoint_id": current_checkpoint_id,

		# progreso
		"intro_done": intro_done,
		"has_flashlight": has_flashlight,
		"world1_controls_shown": world1_controls_shown,

		"intro_mundo2_done": intro_mundo2_done,
		"intro_mundo3_done": intro_mundo3_done,

		"muneco_antiguo_done": muneco_antiguo_done,

		"buscar_linterna_done": buscar_linterna_done,
		"angel_statua_done": angel_statua_done,
		"letrero_viejo_done": letrero_viejo_done,

		# objetos / eventos específicos
		"flashlight_on": flashlight_on,
		"hoja_encontrada_done": hoja_encontrada_done,
		"foto_familiar_done": foto_familiar_done,

		# eventos mundo
		"roca_accidente_done": roca_accidente_done,
		"arbol_caido_done": arbol_caido_done,

		# atmósfera
		"world2_atmos_stage": world2_atmos_stage,

		# persecución
		"chase_capture_mode": chase_capture_mode,
		"chase_retry_checkpoint_id": chase_retry_checkpoint_id,

		# tiempo jugado
		"play_time": get_total_survival_time()
	}


# ==================================================
# LOAD
# ==================================================

func apply_save_dict(d: Dictionary) -> void:
	current_scene_path = d.get("scene_path", current_scene_path)
	current_checkpoint_id = d.get("checkpoint_id", current_checkpoint_id)

	# progreso
	intro_done = bool(d.get("intro_done", intro_done))
	has_flashlight = bool(d.get("has_flashlight", has_flashlight))
	world1_controls_shown = bool(d.get("world1_controls_shown", world1_controls_shown))

	intro_mundo2_done = bool(d.get("intro_mundo2_done", intro_mundo2_done))
	intro_mundo3_done = bool(d.get("intro_mundo3_done", intro_mundo3_done))

	muneco_antiguo_done = bool(d.get("muneco_antiguo_done", muneco_antiguo_done))

	buscar_linterna_done = bool(d.get("buscar_linterna_done", buscar_linterna_done))
	angel_statua_done = bool(d.get("angel_statua_done", angel_statua_done))
	letrero_viejo_done = bool(d.get("letrero_viejo_done", letrero_viejo_done))

	# objetos / eventos específicos
	flashlight_on = bool(d.get("flashlight_on", flashlight_on))
	hoja_encontrada_done = bool(d.get("hoja_encontrada_done", hoja_encontrada_done))
	foto_familiar_done = bool(d.get("foto_familiar_done", foto_familiar_done))

	# eventos
	roca_accidente_done = bool(d.get("roca_accidente_done", roca_accidente_done))
	arbol_caido_done = bool(d.get("arbol_caido_done", arbol_caido_done))

	# atmósfera
	world2_atmos_stage = int(d.get("world2_atmos_stage", world2_atmos_stage))
	world2_atmos_stage = clamp(world2_atmos_stage, 0, 3)

	# persecución
	chase_capture_mode = str(d.get("chase_capture_mode", chase_capture_mode))
	chase_retry_checkpoint_id = str(d.get("chase_retry_checkpoint_id", chase_retry_checkpoint_id))

	# tiempo
	if d.has("play_time"):
		set_survival_time(float(d.get("play_time", get_total_survival_time())))
