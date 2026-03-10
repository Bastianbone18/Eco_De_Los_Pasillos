extends Area3D

@export var jumpscare_scene_path: String = "res://Cinematicas/jumpscare.tscn"
@export var cause: String = "killzone"

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# tu player está en grupo "Player"
	if not body.is_in_group("Player"):
		return

	# 1) Congelar/invalidar al player para que no siga corriendo un frame raro
	_soft_kill_player(body)

	# 2) Ir al jumpscare (NO llamar body.die() para no ir directo a GameOver)
	get_tree().change_scene_to_file(jumpscare_scene_path)

func _soft_kill_player(player: Node) -> void:
	# parar timer por coherencia (igual que en die())
	if GameData and GameData.has_method("stop_survival_timer"):
		GameData.stop_survival_timer()

	# marcar al player como muerto para que deje de moverse
	# (tu script tiene var _is_dead)
	if player != null:
		# set() sirve si la variable existe
		player.set("_is_dead", true)
		player.set_physics_process(false)
		player.set_process(false)

		# si tiene la señal died, la emitimos (opcional, por logs/telemetría)
		if player.has_signal("died"):
			player.emit_signal("died", cause)
