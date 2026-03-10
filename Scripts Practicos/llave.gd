extends StaticBody3D

@onready var pickup_sound = $AudioStreamPlayer3D
@onready var luz = $OmniLight3D
@onready var mesh = $Plane

var is_picked_up = false
var flotando = false
var float_timer := 0.0
var altura_base := 0.0
var llave_anim_instance: Node = null

func _ready():
	luz.visible = false
	mesh.visible = false
	self.visible = false
	altura_base = global_transform.origin.y

func action_use():
	if is_picked_up:
		return

	is_picked_up = true

	if pickup_sound:
		pickup_sound.play()
		await pickup_sound.finished

	mostrar_dialogo_llave()

func mostrar_dialogo_llave():
	# Instanciar el balloon de diálogo
	var dialogue_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var dialogue_instance = dialogue_scene.instantiate()
	get_tree().get_current_scene().add_child(dialogue_instance)

	# Cargar recurso de diálogo y reproducir
	var dialogue_resource = load("res://Dialogos/Llave_casa1.dialogue")
	dialogue_instance.start(dialogue_resource, "llave_casa1")

	# Conectar señal de fin de diálogo
	dialogue_instance.dialogue_finished.connect(_on_dialogue_finished.bind(dialogue_instance))

	# Instanciar animación de la llave
	var anim_scene = preload("res://PNG_OBJETOS/LlaveCasa1animacion.tscn")
	llave_anim_instance = anim_scene.instantiate()
	get_tree().get_current_scene().add_child(llave_anim_instance)

	# Reproducir animación
	if llave_anim_instance.has_node("AnimLlave"):
		llave_anim_instance.get_node("AnimLlave").play("LlaveAnim")

func _on_dialogue_finished(_balloon):
	# 🧹 Eliminar la animación cuando finaliza el diálogo
	if llave_anim_instance:
		llave_anim_instance.queue_free()
		llave_anim_instance = null

	# ⌛ Espera opcional antes de eliminar el objeto llave
	await get_tree().create_timer(1.5).timeout

	# 🗝️ Eliminar la llave de la escena
	queue_free()

func activar_llave():
	luz.visible = true
	mesh.visible = true
	self.visible = true
	flotando = true

func _process(delta):
	if flotando:
		float_timer += delta
		var altura = sin(float_timer * 2.0) * 0.05

		var new_transform := global_transform
		new_transform.origin.y = altura_base + altura
		global_transform = new_transform
