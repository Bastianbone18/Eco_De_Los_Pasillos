extends StaticBody3D

# Estados
var isOpen = false
var canInteract = true
var failed_attempts := 0

# Configuración
@export var StartsOpened := false
@export var isLocked := false
@export var needsKey := false
@export var neededKey := StaticBody3D  # Nodo que representa la llave
@export var llave_objeto: Node3D  # Nodo raíz de la llave con su luz

# Referencias
@onready var animation_player = $MiAnimationPlayer
@onready var interaction_area = $Area3D

# Señales para mostrar u ocultar mensajes
signal show_message(msg)
signal hide_message()

func _ready():
	if animation_player == null:
		print("❌ Error: MiAnimationPlayer no encontrado.")
	else:
		animation_player.connect("animation_finished", Callable(self, "_on_mi_animation_player_animation_finished"))

# 👉 Interacción principal
func action_use():
	if isLocked:
		animation_player.play("Locked")

		if needsKey and is_instance_valid(neededKey):
			if failed_attempts == 0:
				mostrar_dialogo_puerta_cerrada()
			else:
				mostrar_dialogo_puerta_segundo_intento()

			failed_attempts += 1
			return
		else:
			emit_signal("show_message", "Puerta desbloqueada")
			isLocked = false
			open_door()

	elif !isOpen and canInteract:
		open_door()
	elif isOpen and canInteract:
		close_door()

# 💬 Primer intento sin llave
func mostrar_dialogo_puerta_cerrada():
	var dialogue_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var dialogue_instance = dialogue_scene.instantiate()
	get_tree().get_current_scene().add_child(dialogue_instance)

	var dialogue_resource = load("res://Dialogos/Puerta_cerrada.dialogue")
	dialogue_instance.start(dialogue_resource, "puerta_cerrada")

	# 👉 Conectamos para que al terminar el diálogo se active la llave
	dialogue_instance.dialogue_finished.connect(_on_dialogo_terminado.bind(dialogue_instance))
	# Mostrar diálogo
func _on_dialogo_terminado(dialogo):
	if is_instance_valid(dialogo):
		dialogo.queue_free()

	if llave_objeto and llave_objeto.has_method("activar_llave"):
		llave_objeto.activar_llave()


# 💬 Segundo intento sin llave
func mostrar_dialogo_puerta_segundo_intento():
	var dialogue_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var dialogue_instance = dialogue_scene.instantiate()
	get_tree().get_current_scene().add_child(dialogue_instance)

	var dialogue_resource = load("res://Dialogos/Puerta_cerrada_2.dialogue")
	dialogue_instance.start(dialogue_resource, "puerta_cerrada_2")

# 🚪 Abrir puerta
func open_door():
	canInteract = false
	if animation_player:
		animation_player.play("Open")
	isOpen = true
	emit_signal("show_message", "Puerta abierta")

# 🚪 Cerrar puerta
func close_door():
	canInteract = false
	if animation_player:
		animation_player.play("Close")
	isOpen = false
	emit_signal("show_message", "Puerta cerrada")

# 🔁 Restaurar interacción al terminar animación
func _on_mi_animation_player_animation_finished(anim_name):
	canInteract = true

# 👁️ Mostrar mensaje al acercarse
func _on_body_entered(body):
	if body.name == "Player":
		if isLocked and needsKey and is_instance_valid(neededKey):
			emit_signal("show_message", "La puerta está cerrada...")
		elif isOpen:
			emit_signal("show_message", "Puerta abierta")
		else:
			emit_signal("show_message", "Puerta cerrada")

# 👁️ Ocultar mensaje al alejarse
func _on_body_exited(body):
	if body.name == "Player":
		emit_signal("hide_message")
