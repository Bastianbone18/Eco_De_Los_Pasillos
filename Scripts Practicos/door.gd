@tool
extends StaticBody3D

var isOpen = false
var canInteract = true

@export var StartsOpened := false 
@onready var animation_player = $MiAnimationPlayer  # Referencia al nodo AnimationPlaye
@export var isLocked := false 
@export var needsKey := false
@export var neededKey := StaticBody3D




# Configuración inicial
func _ready():
	if animation_player == null:
		print("Error: MiAnimationPlayer no encontrado.")
	else:
		# Conectar la señal animation_finished para controlar la interacción después de que termine
		animation_player.connect("animation_finished", Callable(self, "_on_mi_animation_player_animation_finished"))

# Función que se llama cuando el nodo es interactuado
func action_use():
	if isLocked:
		$MiAnimationPlayer.play("Locked")
		if needsKey:
			print("Necesitas una llave")
			if !is_instance_valid(neededKey):
				print("Puerta Bloqueada")
				isLocked= false
				open_door()
		
	
	elif !isOpen and canInteract:
		open_door()
	elif isOpen and canInteract:
		close_door()

# Función para abrir la puerta
func open_door():
	canInteract = false
	if animation_player:
		animation_player.play("Open")
	else:
		print("Error: MiAnimationPlayer no encontrado para abrir la puerta.")
	isOpen = true

# Función para cerrar la puerta
func close_door():
	canInteract = false
	if animation_player:
		animation_player.play("Close")
	else:
		print("Error: MiAnimationPlayer no encontrado para cerrar la puerta.")
	isOpen = false

# Función llamada cuando la animación termina
func _on_mi_animation_player_animation_finished(anim_name):
	canInteract = true
