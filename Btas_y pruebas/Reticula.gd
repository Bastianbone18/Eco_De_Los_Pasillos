extends CenterContainer

@onready var pointer_icon := $TextureRect
var raycast: RayCast3D = null
var control_manual := false  # 🔄 Esto activa/desactiva el control automático

func _ready():
	pointer_icon.visible = false  # Oculto al inicio
	pointer_icon.modulate = Color(1, 1, 1)

# Muestra u oculta desde scripts externos (como el carro)
func mostrar_puntero():
	control_manual = true
	pointer_icon.visible = true
	print("🎯 Puntero mostrado desde evento")

func ocultar_puntero():
	control_manual = false
	pointer_icon.visible = false
	print("🙈 Puntero ocultado desde evento")

func _process(_delta):
	if control_manual:
		return  # 🔒 No actualices si está en modo manual

	if raycast == null:
		return

	if raycast.is_colliding():
		var collider = raycast.get_collider()

		if collider != null:
			var is_interactable: bool = collider.has_method("action_use") \
				or (collider.has_meta("interactable_owner") and collider.get_meta("interactable_owner").has_method("action_use"))

			pointer_icon.visible = is_interactable
		else:
			pointer_icon.visible = false
	else:
		pointer_icon.visible = false
