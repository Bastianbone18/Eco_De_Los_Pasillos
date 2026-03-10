extends Node3D

@onready var musica_fondo: AudioStreamPlayer = $MusicaFondo
@onready var musica_iglesia: AudioStreamPlayer = $Iglesia_estruc/MusicaIglesia

var tiempo_actual = 0.0  # Almacena el tiempo sobrevivido

func _ready():
	tiempo_actual = 0.0
	musica_fondo.play()  # Inicia música de fondo

func _process(delta):
	tiempo_actual += delta

	if should_end_game():
		end_game()

func should_end_game() -> bool:
	# Lógica personalizada para finalizar el juego
	return false

func end_game():
	GameData.survival_time = tiempo_actual
	get_tree().change_scene_to_file("res://Pantallas/GameOver.tscn")

func crossfade(player_out: AudioStreamPlayer, player_in: AudioStreamPlayer, duration: float = 1.5):
	var tween = create_tween()
	
	# Fade out del primero
	tween.tween_property(player_out, "volume_db", -80, duration)
	tween.tween_callback(Callable(player_out, "stop"))

	# Fade in del segundo
	player_in.play()
	player_in.volume_db = -80
	tween.tween_property(player_in, "volume_db", 0, duration)

# Llamar cuando el jugador entra a la iglesia
func _on_player_entered_iglesia():
	crossfade(musica_fondo, musica_iglesia)

# Llamar cuando el jugador sale de la iglesia
func _on_player_exited_iglesia():
	crossfade(musica_iglesia, musica_fondo)
