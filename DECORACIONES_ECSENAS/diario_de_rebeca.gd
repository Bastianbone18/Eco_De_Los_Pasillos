extends Node3D

@onready var area = $Area3D
@onready var static_body = $StaticBody3D
@onready var mesh = $StaticBody3D/MeshInstance3D
@onready var light = $OmniLight3D

var player_inside = false
var already_used = false
var puntero_ui: Node = null
var diario_anim_instance: Node = null  # 🔁 Animación del diario

var float_amplitude := 0.15
var float_speed := 3.0
var base_y := 0.0
var time := 0.0

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	if static_body:
		static_body.set_meta("interactable_owner", self)
		print("✅ interactable_owner asignado:", static_body.get_meta("interactable_owner"))

	if mesh:
		base_y = mesh.global_transform.origin.y

	# Buscar el puntero UI al inicio
	puntero_ui = get_tree().get_current_scene().find_child("CenterContainer", true, false)
	if puntero_ui == null:
		push_warning("⚠️ No se encontró CenterContainer para mostrar el puntero")

func _on_body_entered(body):
	if body.name == "Player":
		player_inside = true
		if puntero_ui and puntero_ui.has_method("mostrar_puntero"):
			puntero_ui.mostrar_puntero()

func _on_body_exited(body):
	if body.name == "Player":
		player_inside = false
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()

func _process(delta):
	if not already_used:
		time += delta
		if mesh:
			var new_y = base_y + sin(time * float_speed) * float_amplitude
			var pos = mesh.global_transform.origin
			pos.y = new_y
			mesh.global_transform.origin = pos

	if player_inside and Input.is_action_just_pressed("action_use") and not already_used:
		already_used = true
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()
		mostrar_dialogo_diario()

func action_use():
	if not already_used:
		already_used = true
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()
		mostrar_dialogo_diario()

func mostrar_dialogo_diario():
	# Instanciar y reproducir el diálogo principal
	var dialogue_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var dialogue_instance = dialogue_scene.instantiate()
	get_tree().get_current_scene().add_child(dialogue_instance)

	var dialogue_resource = load("res://Dialogos/Dialogo_Diario.dialogue")
	dialogue_instance.start(dialogue_resource, "start")
	dialogue_instance.dialogue_finished.connect(_on_dialogue_finished.bind(dialogue_instance))

	# 🎬 Instanciar animación del diario y guardar referencia
	var anim_scene = preload("res://PNG_OBJETOS/DiarioAnimacion.tscn")
	diario_anim_instance = anim_scene.instantiate()
	get_tree().get_current_scene().add_child(diario_anim_instance)

	if diario_anim_instance.has_node("AnimDiario"):
		diario_anim_instance.get_node("AnimDiario").play("mostrar")

func _on_dialogue_finished(_balloon):
	# 🧹 Eliminar la animación justo cuando termina el diálogo
	if diario_anim_instance:
		diario_anim_instance.queue_free()
		diario_anim_instance = null

	# 🔊 Reproducir risa
	var risa = AudioStreamPlayer.new()
	risa.stream = preload("res://Musica y sonidos/Sonidos/Risa_de_lejos.ogg")
	risa.bus = "Master"
	get_tree().get_current_scene().add_child(risa)
	risa.play()

	# 💡 Parpadeo de linterna
	var player = get_tree().get_current_scene().get_node("Player")
	if player and player.has_method("flashlight_blink"):
		player.flashlight_blink()

	await get_tree().create_timer(2.5).timeout
	mostrar_dialogo_reaccion()

func mostrar_dialogo_reaccion():
	var dialogue_scene = preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var dialogue_instance = dialogue_scene.instantiate()
	get_tree().get_current_scene().add_child(dialogue_instance)

	var dialogue_resource = load("res://Dialogos/Dialogo_Diario.dialogue")
	dialogue_instance.start(dialogue_resource, "reaccion_risa")

	await get_tree().create_timer(2.5).timeout
	queue_free()
