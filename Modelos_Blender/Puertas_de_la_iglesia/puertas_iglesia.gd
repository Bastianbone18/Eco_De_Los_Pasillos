extends StaticBody3D

# Estado
var isOpen := false
var canInteract := true

# Referencias
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area3D = $Area3D

# Señales opcionales para mostrar mensajes
signal show_message(msg)
signal hide_message()

func _ready():
	# Conectamos la señal del AnimationPlayer para saber cuándo termina
	animation_player.animation_finished.connect(_on_animation_finished)
	# Conectamos las señales del área de interacción
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

# 👉 Acción al interactuar
func action_use():
	if not isOpen and canInteract:
		open_door()

# 🚪 Abrir puerta
func open_door():
	canInteract = false
	isOpen = true
	animation_player.play("OpenIglesia")
	emit_signal("show_message", "Puerta abierta")

# 🔁 Al terminar la animación se puede volver a interactuar (si fuera necesario)
func _on_animation_finished(anim_name):
	canInteract = true

# 👁️ Mostrar mensaje al acercarse
func _on_body_entered(body):
	if body.name == "Player":
		if isOpen:
			emit_signal("show_message", "Puerta abierta")
		else:
			emit_signal("show_message", "Presiona 'E' para abrir la puerta")

# 👁️ Ocultar mensaje al alejarse
func _on_body_exited(body):
	if body.name == "Player":
		emit_signal("hide_message")
