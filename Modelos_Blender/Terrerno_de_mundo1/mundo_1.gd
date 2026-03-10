extends Node3D

@export var checkpoints_path: NodePath = NodePath("Checkpoints")
@export var player_path: NodePath = NodePath("Player")

# Nodos que SOLO deben existir/activarse en NEW GAME (start)
@export var intro_manager_path: NodePath
@export var intro_dialog_triggers_path: NodePath
@export var truck_flashlight_spawn_path: NodePath

@export var flashlight_controller_path: NodePath
@export var crash_fx_path: NodePath = NodePath("CrashFX")

var _intro_sequence_started: bool = false
var _primer_dialogo_started: bool = false

@onready var checkpoints: Node3D = get_node_or_null(checkpoints_path)
@onready var player: Node3D = get_node_or_null(player_path)
@onready var crash_fx: CrashFX = get_node_or_null(crash_fx_path) as CrashFX

# =====================================================
# READY
# =====================================================

func _ready() -> void:
	var cp: String = GameData.current_checkpoint_id

	if cp.strip_edges() == "":
		cp = "start"

	_spawn_at_checkpoint(cp)

	# Si estás cargando, ya no es NEW GAME
	if cp != "start":
		GameData.intro_done = true

	print(
		"[Mundo1] Flags al entrar | intro_done:", GameData.intro_done,
		" has_flashlight:", GameData.has_flashlight,
		" buscar_linterna_done:", GameData.buscar_linterna_done,
		" flashlight_on:", GameData.flashlight_on,
		" hoja_done:", GameData.hoja_encontrada_done
	)

	_apply_loaded_state(cp)

	# =====================================================
	# NEW GAME (SOLO UNA VEZ)
	# =====================================================
	if cp == "start" and !GameData.intro_done and !_intro_sequence_started:
		_intro_sequence_started = true

		# 🔒 Bloqueo fuerte para que ningún otro trigger vuelva a disparar intro
		GameData.intro_done = true

		# 1) CrashFX (anim 3.05 -> FX -> extra_delay)
		if crash_fx != null:
			crash_fx.play_crash()
			await crash_fx.crash_finished

		# 2) Diálogo EXACTO al terminar todo
		_start_primer_dialogo()


# =====================================================
# SPAWN
# =====================================================

func _spawn_at_checkpoint(cp: String) -> void:
	if checkpoints == null or player == null:
		push_error("[Mundo1] Falta Checkpoints o Player. Revisa paths exportados.")
		return

	var marker: Marker3D = checkpoints.get_node_or_null(cp) as Marker3D

	if marker != null:
		player.global_transform = marker.global_transform
		print("[Mundo1] Spawn en checkpoint:", cp)
	else:
		print("[Mundo1] No encontré checkpoint:", cp, "-> usando start")
		var start_marker: Marker3D = checkpoints.get_node_or_null("start") as Marker3D
		if start_marker != null:
			player.global_transform = start_marker.global_transform


# =====================================================
# LOAD STATE
# =====================================================

func _apply_loaded_state(cp: String) -> void:
	print(
		"[Mundo1] LOAD detectado -> aplicando estado. intro_done:",
		GameData.intro_done,
		" has_flashlight:",
		GameData.has_flashlight
	)

	# 1) Desactivar intro si ya pasó
	if GameData.intro_done:
		_disable_node(intro_manager_path, "IntroManager")
		_disable_node(intro_dialog_triggers_path, "IntroDialogTriggers")
		_disable_node(truck_flashlight_spawn_path, "TruckFlashlightSpawn")

	# 2) Mantener linterna
	if GameData.has_flashlight:
		_enable_flashlight()


# =====================================================
# HELPERS
# =====================================================

func _disable_node(path: NodePath, label: String) -> void:
	if path == NodePath(""):
		return

	var n := get_node_or_null(path)
	if n:
		n.queue_free()
		print("[Mundo1] Desactivado:", label)


func _enable_flashlight() -> void:
	if flashlight_controller_path == NodePath(""):
		print("[Mundo1] has_flashlight=true pero no se asignó flashlight_controller_path")
		return

	var f := get_node_or_null(flashlight_controller_path)
	if f == null:
		print("[Mundo1] No encontré flashlight controller.")
		return

	if f.has_method("set_enabled"):
		f.call("set_enabled", true)
	elif f.has_method("enable"):
		f.call("enable")
	elif f is Node:
		(f as Node).process_mode = Node.PROCESS_MODE_INHERIT
		if f.has_method("show"):
			f.call("show")

	print("[Mundo1] Linterna activada por LOAD.")


# =====================================================
# DIÁLOGO INICIAL
# =====================================================

func _start_primer_dialogo() -> void:
	# 🔒 Anti-duplicado: si algo intenta llamarlo 2 veces, se cancela
	if _primer_dialogo_started:
		print("[Mundo1] Primer_Dialogo ya fue iniciado. Ignorando llamada duplicada.")
		return
	_primer_dialogo_started = true

	# Si existe un singleton "DialogueManager", úsalo
	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		if dm != null and dm.has_method("show_dialogue_balloon"):
			dm.call(
				"show_dialogue_balloon",
				load("res://Dialogos/Primer_Dialogo.dialogue"),
				"start"
			)
			return

	# Si tu IntroManager lo maneja
	var intro := get_node_or_null(intro_manager_path)
	if intro != null:
		if intro.has_method("start_primer_dialogo"):
			intro.call("start_primer_dialogo")
			return
		if intro.has_method("start_dialogue"):
			intro.call("start_dialogue", "res://Dialogos/Primer_Dialogo.dialogue")
			return

	push_warning("[Mundo1] No pude iniciar Primer_Dialogo.")
