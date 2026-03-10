extends StaticBody3D

@export var owner_node: Node = null

func _ready():
	if owner_node:
		print("✅ StaticBody3D listo con owner_node:", owner_node.name)
		set_meta("interactable_owner", owner_node)
	else:
		print("⚠️ StaticBody3D sin owner_node asignado")
