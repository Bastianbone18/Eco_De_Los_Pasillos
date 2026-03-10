extends Area3D

@export var jumpscare_scene_path: String = "res://Cinematicas/jumpscare.tscn"
@export var player_layer_bit_index: int = 0  # 0=capa1, 7=capa8
@export var trigger_once: bool = true

var _triggered: bool = false

func _ready() -> void:
	# Solo escucha: su propia layer no importa
	collision_layer = 0

	# Escuchar SOLO la capa del Player
	collision_mask = 0
	set_collision_mask_value(player_layer_bit_index + 1, true)

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	print("[TOUCH AREA] listo. mask en capa ", player_layer_bit_index + 1)

func _on_body_entered(body: Node) -> void:
	var is_player := body.is_in_group("Player") \
		or (body.get_parent() and body.get_parent().is_in_group("Player"))
	if not is_player:
		return
	if trigger_once and _triggered:
		return
	_triggered = true
	await _play_jumpscare_and_gameover()

func _play_jumpscare_and_gameover() -> void:
	if ResourceLoader.exists(jumpscare_scene_path):
		var js_res: PackedScene = load(jumpscare_scene_path) as PackedScene
		if js_res == null:
			push_warning("No se pudo cargar la escena de jumpscare.")
			await get_tree().create_timer(0.5).timeout
		else:
			var js: Node = js_res.instantiate()
			get_tree().current_scene.add_child(js)

			if js.has_method("play_jumpscare"):
				js.call_deferred("play_jumpscare")

			if js.has_signal("finished"):
				await js.finished
			else:
				await get_tree().create_timer(2.5).timeout
	else:
		push_warning("No se encontró jumpscare en: " + jumpscare_scene_path)
		await get_tree().create_timer(0.5).timeout

	get_tree().change_scene_to_file("res://Pantallas/Game_over.tscn")
