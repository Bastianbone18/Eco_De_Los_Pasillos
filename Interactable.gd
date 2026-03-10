# Interactable.gd
extends StaticBody3D

@export var owner_node: Node3D

func _ready():
	if owner_node == null:
		# Si no se asignó desde el editor, intenta buscar el padre
		var parent = get_parent()
		if parent != null:
			owner_node = parent
