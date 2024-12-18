extends Node3D

# Array con tus archivos de sonido
var sonidos = [
	preload("res://Musica y sonidos/Sonidos/Rama_crugiendo.ogg"),
	preload("res://Musica y sonidos/Sonidos/Otra voz.ogg"),
	preload("res://Musica y sonidos/Sonidos/sususrros.ogg"),
	preload("res://Musica y sonidos/Sonidos/respiro_tenso.ogg"),
	preload("res://Musica y sonidos/Sonidos/Bestia.ogg")
]

# Referencia al nodo AudioStreamPlayer
@onready var audio_player = $AudioStreamPlayer

const INTERVALO_MIN = 10.0
const INTERVALO_MAX = 60.0
const CHANCE_SUPERPOSICION = 20  # Porcentaje de probabilidad de superposición

func _ready():
	print("Script iniciado, asignando bus Atmosfera")
	audio_player.bus = "Atmosfera"
	reproducir_sonido_random()

func reproducir_sonido_random():
	print("Iniciando reproducción aleatoria")
	# Determina si permite superposición de sonidos
	if audio_player.is_playing():
		if randf() * 100 < CHANCE_SUPERPOSICION:
			print("Superposición activada.")
		else:
			print("Esperando a que el sonido actual termine...")
			await audio_player.finished

	# Selecciona un sonido al azar
	audio_player.stream = sonidos.pick_random()
	print("Reproduciendo sonido:", audio_player.stream.resource_path)
	audio_player.play()

	# Genera un intervalo aleatorio
	var intervalo = randf_range(INTERVALO_MIN, INTERVALO_MAX)
	if randf() > 0.7:
		var pausa_extra = randf_range(20.0, 40.0)
		intervalo += pausa_extra
		print("Pausa extendida añadida de:", pausa_extra, "segundos.")

	print("Siguiente sonido en:", intervalo, "segundos.")
	await get_tree().create_timer(intervalo).timeout
	reproducir_sonido_random()
