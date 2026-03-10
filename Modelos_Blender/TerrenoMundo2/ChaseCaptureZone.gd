extends Area3D
class_name ChaseCaptureZone

# ==================================================
# Esta zona NO mata ni cambia escenas.
# Solo escribe en GameData el modo de captura que
# debe resolverse cuando el enemigo capture.
#
# - death    -> repetir misión (retry)
# - knockout -> avanzar a Mundo 3
# ==================================================

@export_enum("death", "knockout") var mode: String = "knockout"

# Solo se usa si mode == "death"
@export var retry_checkpoint_id: String = "before_mission2"

# Debug opcional
@export var debug_print: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	print("[ChaseCaptureZone] ENTER -> zone=", name, " mode=", mode, " body=", body)

	# A veces el collider que entra no es el Player directamente.
	var is_player := body.is_in_group("Player") or (body.get_parent() and body.get_parent().is_in_group("Player"))
	if not is_player:
		return

	# ✅ La arquitectura dice: flags/estado siempre en GameData
	GameData.chase_capture_mode = mode

	# Si esta zona es de muerte, define el checkpoint al que debe volver
	if mode == "death":
		GameData.chase_retry_checkpoint_id = retry_checkpoint_id

	if debug_print:
		print("[ChaseCaptureZone] ENTER -> mode=", mode, " retry_cp=", retry_checkpoint_id)
		print("[GameData] chase_capture_mode=", GameData.chase_capture_mode,
			" chase_retry_checkpoint_id=", GameData.chase_retry_checkpoint_id)
