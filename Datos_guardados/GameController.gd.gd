extends Node

var survival_time = 0.0  # Tiempo de supervivencia

func _ready():
	# Asegúrate de que el contador de tiempo comience correctamente
	survival_time = 0.0  # Asegurarse de que comienza desde cero (en caso de reinicio)
	print("Tiempo de supervivencia comenzado: ", survival_time)

func _process(delta):
	survival_time += delta  # Acumula el tiempo con cada frame
	GameData.survival_time = survival_time  # Guarda el tiempo en GameData

	# Depuración: Imprimir el tiempo cada frame
	print("Tiempo acumulado: ", survival_time)
	print("GameData.survival_time: ", GameData.survival_time)
