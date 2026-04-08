extends CanvasLayer

@onready var label: Label = $Label
@onready var rect: ColorRect = $ColorRect

@export var duracion_mensaje: float = 10.0
@export var escena_creditos: String = "res://Pantallas/CreditsScene.tscn"

var cancelado: bool = false


func _ready() -> void:
	rect.color.a = 1.0

	if rect.material:
		rect.material.set_shader_parameter("intensity", 0.0)
		rect.material.set_shader_parameter("glitch_strength", 0.0)
		rect.material.set_shader_parameter("chromatic_aberration", 0.0)
		rect.material.set_shader_parameter("noise_strength", 0.0)
		rect.material.set_shader_parameter("hell_red", 0.0)
		rect.material.set_shader_parameter("darkness", 0.0)

	label.rotation = 0.0
	label.scale = Vector2.ONE
	rect.rotation = 0.0

	start_sequence()


func start_sequence() -> void:
	label.text = "La fe levantó este pueblo...\n\npero fue la sangre la que lo consagró."

	var tiempo: float = 0.0

	while tiempo < duracion_mensaje and not cancelado:
		var t: float = tiempo / duracion_mensaje

		# Shader progresivo
		if rect.material:
			rect.material.set_shader_parameter("intensity", t)
			rect.material.set_shader_parameter("glitch_strength", t * 2.5)
			rect.material.set_shader_parameter("chromatic_aberration", t * 2.0)
			rect.material.set_shader_parameter("noise_strength", t * 3.0)
			rect.material.set_shader_parameter("darkness", pow(t, 1.6))
			rect.material.set_shader_parameter("hell_red", pow(t, 2.0))

		# Últimos 2 segundos → horror total
		if tiempo > duracion_mensaje - 2.0:
			var p: float = (tiempo - (duracion_mensaje - 2.0)) / 2.0

			if rect.material:
				rect.material.set_shader_parameter(
					"hell_red",
					0.8 + sin(Time.get_ticks_msec() * 0.02) * 0.2
				)

			label.rotation = randf_range(-0.02, 0.02) * p
			label.scale = Vector2.ONE + Vector2(
				randf_range(-0.05, 0.05),
				randf_range(-0.05, 0.05)
			) * p

			rect.rotation = randf_range(-0.01, 0.01) * p

		await get_tree().process_frame
		tiempo += get_process_delta_time()

	if cancelado:
		queue_free()
		return

	# Cambiar a la escena de créditos
	var err := get_tree().change_scene_to_file(escena_creditos)
	if err != OK:
		push_error("❌ No se pudo cambiar a la escena de créditos: " + escena_creditos)
		return

	queue_free()


func cancelar_evento() -> void:
	cancelado = true
	queue_free()
