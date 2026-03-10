extends Node

@export var first_checkpoint_id: String = "world3_start"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var scene_path: String = get_tree().current_scene.scene_file_path
	print("[Mundo3] READY -> scene_path = ", scene_path)

	# ✅ Solo registra checkpoint inicial si realmente vienes entrando
	# por primera vez a Mundo3 o si no hay checkpoint válido aún.
	if GameData.current_scene_path != scene_path or GameData.current_checkpoint_id == "":
		GameData.set_checkpoint(scene_path, first_checkpoint_id)

		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("save_from_gamedata"):
			sm.save_from_gamedata(GameData)

		print("[Mundo3] Checkpoint inicial registrado -> ", first_checkpoint_id)
	else:
		print("[Mundo3] Manteniendo checkpoint actual -> ", GameData.current_checkpoint_id)
