extends Node3D

# Lista de sonidos con peso opcional para controlar frecuencia
var sonidos = [
	{ stream = preload("res://Musica y sonidos/Sonidos/Rama_crugiendo.ogg"), peso = 3 },
	{ stream = preload("res://Musica y sonidos/Sonidos/Otra voz.ogg"), peso = 2 },
	{ stream = preload("res://Musica y sonidos/Sonidos/sususrros.ogg"), peso = 4 },
	{ stream = preload("res://Musica y sonidos/Sonidos/respiro_tenso.ogg"), peso = 2 },
	{ stream = preload("res://Musica y sonidos/Sonidos/Bestia.ogg"), peso = 1 }
]

@onready var audio_player = $AudioStreamPlayer  # Usa AudioStreamPlayer3D si es 3D

const CHANCE_SUPERPOSICION = 20  # %
const RETRASO_INICIAL = 30.0     # segundos

var intervalo_min = 60.0
var intervalo_max = 180.0
var incremento_intervalo = 5.0

var ultimo_sonido: AudioStream = null

func _ready():
	print("Script iniciado, asignando bus Atmosfera")
	audio_player.bus = "Atmosfera"

	print("Esperando", RETRASO_INICIAL, "segundos antes de iniciar sonidos.")
	await get_tree().create_timer(RETRASO_INICIAL).timeout

	reproducir_sonido_random()

func reproducir_sonido_random():
	print("Iniciando reproducción aleatoria")

	if audio_player.is_playing():
		if randf() * 100 < CHANCE_SUPERPOSICION:
			print("Superposición activada.")
			await get_tree().create_timer(randf_range(0.2, 1.0)).timeout
		else:
			print("Esperando a que el sonido actual termine...")
			await audio_player.finished

	# Seleccionar un sonido distinto al anterior
	var nuevo_sonido = seleccionar_sonido_distinto()
	audio_player.stream = nuevo_sonido
	ultimo_sonido = nuevo_sonido

	# Variación de volumen y pitch para mayor naturalidad
	audio_player.volume_db = randf_range(-12, -4)
	audio_player.pitch_scale = randf_range(0.95, 1.05)

	print("Reproduciendo:", nuevo_sonido.resource_path)
	audio_player.play()

	# Esperar un nuevo intervalo aleatorio
	var intervalo = randf_range(intervalo_min, intervalo_max)
	print("Siguiente sonido en:", intervalo, "segundos")

	# Controlar crecimiento de los intervalos
	intervalo_min = clamp(intervalo_min + incremento_intervalo, 60.0, 300.0)
	intervalo_max = clamp(intervalo_max + incremento_intervalo, 180.0, 600.0)

	await get_tree().create_timer(intervalo).timeout
	reproducir_sonido_random()

func seleccionar_sonido_distinto() -> AudioStream:
	var total_peso = 0
	for s in sonidos:
		total_peso += s.peso

	# Intentamos evitar repetir el sonido anterior
	for intento in range(10):  # Máximo 10 intentos
		var r = randi_range(1, total_peso)
		var acumulado = 0
		for s in sonidos:
			acumulado += s.peso
			if r <= acumulado:
				if s.stream != ultimo_sonido:
					return s.stream

	# Si no se logró encontrar uno distinto, usar cualquiera
	return sonidos.pick_random().stream
