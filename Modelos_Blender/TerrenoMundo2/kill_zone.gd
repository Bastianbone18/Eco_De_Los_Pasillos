extends Area3D

@export var jumpscare_scene_path: String = "res://Cinematicas/jumpscare.tscn"
@export var cause: String = "killzone"

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return

	# 1) Congelar/invalidar al player para evitar frames raros
	_soft_kill_player(body)

	# 2) Cambiar de escena en deferred para no romper el callback físico
	call_deferred("_go_to_jumpscare")

func _go_to_jumpscare() -> void:
	get_tree().change_scene_to_file(jumpscare_scene_path)

func _soft_kill_player(player: Node) -> void:
	if GameData and GameData.has_method("stop_survival_timer"):
		GameData.stop_survival_timer()

	if player != null:
		player.set("_is_dead", true)
		player.set_physics_process(false)
		player.set_process(false)

		if player.has_signal("died"):
			player.emit_signal("died", cause)
