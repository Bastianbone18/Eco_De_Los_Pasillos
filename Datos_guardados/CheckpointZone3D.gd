extends Area3D
class_name CheckpointZone

@export var checkpoint_id: String = "altar_01"
@export var cooldown_seconds: float = 30.0
@export var autosave: bool = true

var _armed: bool = true

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	if GameData.current_slot_id <= 0:
		return
	if not _armed:
		return

	_armed = false
	_disable_checkpoint_visual_and_collision()

	# 1) Actualiza GameData (checkpoint + escena)
	var scene_path: String = get_tree().current_scene.scene_file_path
	GameData.set_checkpoint(scene_path, checkpoint_id)

	# 2) Guardar TODO (universal)
	GameData.stop_survival_timer()
	var total: float = GameData.get_total_survival_time()

	if autosave:
		var sm := get_node_or_null("/root/SaveManager")
		if sm:
			if sm.has_method("save_from_gamedata"):
				sm.save_from_gamedata(GameData)
				print("[Checkpoint] Guardado (universal):", scene_path, "->", checkpoint_id, "time:", total)
			else:
				push_warning("[Checkpoint] SaveManager no tiene save_from_gamedata().")
		else:
			push_warning("[Checkpoint] /root/SaveManager no encontrado.")

	GameData.start_survival_timer()

	# 3) Cooldown
	await get_tree().create_timer(cooldown_seconds).timeout
	_enable_checkpoint_visual_and_collision()
	_armed = true

func _disable_checkpoint_visual_and_collision() -> void:
	visible = false
	monitoring = false
	monitorable = false
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true

func _enable_checkpoint_visual_and_collision() -> void:
	visible = true
	monitoring = true
	monitorable = true
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = false
