extends CenterContainer

@onready var pointer_icon := $TextureRect

var raycast: RayCast3D = null
var control_manual := false

# =========================
# TEXTURAS
# =========================
@export var ojo_abierto: Texture2D
@export var ojo_guino: Texture2D

# =========================
# TAMAÑO
# =========================
@export var escala_base := 1.3

# =========================
# GUIÑO
# =========================
@export var tiempo_para_guino := 1.5
@export var duracion_guino := 0.15

# =========================
# PULSO
# =========================
@export var pulso_velocidad := 2.5
@export var pulso_intensidad := 0.008

var timer := 0.0
var guinando := false
var pulso_t := 0.0

# DEBUG
var printed_guino := false


func _ready():

	print("👁 Script iniciado")

	pointer_icon.visible = false
	pointer_icon.texture = ojo_abierto
	pointer_icon.modulate = Color(1,1,1)

	# filtro pixel perfecto
	pointer_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# tamaño base
	pointer_icon.scale = Vector2.ONE * escala_base

	print("✔ Pointer listo")


# =========================
# CONTROL MANUAL
# =========================
func mostrar_puntero():
	control_manual = true
	pointer_icon.visible = true
	print("🎯 Puntero mostrado desde evento")

func ocultar_puntero():
	control_manual = false
	pointer_icon.visible = false
	print("🙈 Puntero ocultado desde evento")


# =========================
# PROCESO
# =========================
func _process(delta):

	var mirando_objeto := false

	if control_manual:

		mirando_objeto = pointer_icon.visible

	else:

		if raycast == null:
			return

		if raycast.is_colliding():

			var collider = raycast.get_collider()

			if collider != null:

				var is_interactable: bool = collider.has_method("action_use") \
				or (collider.has_meta("interactable_owner") and collider.get_meta("interactable_owner").has_method("action_use"))

				pointer_icon.visible = is_interactable
				mirando_objeto = is_interactable

			else:
				pointer_icon.visible = false

		else:
			pointer_icon.visible = false


	# =========================
	# PULSO DEL OJO
	# =========================
	if mirando_objeto and pointer_icon.visible:

		pulso_t += delta * pulso_velocidad

		var scale_pulse = escala_base + sin(pulso_t) * pulso_intensidad
		pointer_icon.scale = Vector2.ONE * scale_pulse

		timer += delta

		if timer >= tiempo_para_guino and not guinando:

			if !printed_guino:
				print("😉 GUIÑO ACTIVADO")
				printed_guino = true

			guiñar()

	else:

		timer = 0.0
		pointer_icon.texture = ojo_abierto
		pointer_icon.scale = Vector2.ONE * escala_base
		pulso_t = 0.0


func guiñar():

	guinando = true
	pointer_icon.texture = ojo_guino

	await get_tree().create_timer(duracion_guino).timeout

	pointer_icon.texture = ojo_abierto
	timer = 0.0
	guinando = false
