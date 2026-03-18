extends Control

@onready var scroll = $ScrollContainer
@onready var vbox = $ScrollContainer/VBoxContainer
@onready var talk = $TalkSound
@onready var laugh = $LaughSound

@onready var transition: ColorRect = $TransitionRect
@onready var fondo: ColorRect = $Fondo

var scroll_speed = 18
var type_speed = 0.03
var total_duration = 60.0

var labels = []
var texts = {}

var finished = false


func _ready():

	randomize()

	# bajar volumen clicks
	talk.volume_db = -6

	# fondo oscuro permanente
	fondo.color = Color("#120707")

	# guardar textos
	for node in vbox.get_children():
		if node is Label:
			labels.append(node)
			texts[node] = node.text
			node.text = ""

	start_global_timer()
	start_intro_transition()


func _process(delta):
	scroll.scroll_vertical += scroll_speed * delta


# ------------------------------------------------
# TRANSICIÓN ROJA INICIAL
# ------------------------------------------------

func start_intro_transition():

	var tiempo := 0.0
	var duracion := 4.0

	var rojo_inicio = Color("#660505")
	var negro_final = Color("#120707")

	transition.visible = true
	transition.color = rojo_inicio

	laugh.play()

	while tiempo < duracion:

		var t = tiempo / duracion

		# transición normal rojo → negro
		if tiempo < duracion - 0.5:

			transition.color = rojo_inicio.lerp(negro_final, t)

		# últimos 0.5 segundos → pulso
		else:

			var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.08

			transition.color = Color(
				rojo_inicio.r + pulse,
				rojo_inicio.g,
				rojo_inicio.b
			)

		await get_tree().process_frame
		tiempo += get_process_delta_time()

	transition.visible = false

	start_sequence()


# ------------------------------------------------
# TIMER GLOBAL
# ------------------------------------------------

func start_global_timer():

	await get_tree().create_timer(total_duration).timeout
	end_credits()


# ------------------------------------------------
# SECUENCIA CRÉDITOS
# ------------------------------------------------

func start_sequence():

	for label in labels:

		await typewriter(label)

		if label.is_in_group("title"):
			flash_label(label)

		await get_tree().create_timer(0.3).timeout

	await get_tree().create_timer(10.0).timeout
	end_credits()


# ------------------------------------------------
# MAQUINA DE ESCRIBIR
# ------------------------------------------------

func typewriter(label: Label):

	var full_text = texts[label]

	for i in full_text.length():

		label.text += full_text[i]

		if randi_range(0,1) == 0:
			play_talk()

		await get_tree().create_timer(type_speed).timeout


func play_talk():

	talk.pitch_scale = randf_range(0.95,1.2)
	talk.play()


# ------------------------------------------------
# DESTELLO TITULOS
# ------------------------------------------------

func flash_label(label):

	var tween = create_tween()

	tween.tween_property(label,"modulate",Color(1.6,1.6,1.6),0.10)
	tween.tween_property(label,"modulate",Color(1,1,1),0.15)


# ------------------------------------------------
# FINAL
# ------------------------------------------------

func end_credits():

	if finished:
		return

	finished = true

	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")
