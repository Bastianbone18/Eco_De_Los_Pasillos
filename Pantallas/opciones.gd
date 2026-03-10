extends Control

@onready var button_sound_player = $AudioStreamPlayerBoton
@onready var pantalla_toggle = $PantallaToggle
@onready var mensaje_label = $MensajeLabel

var mensajes = [
	"Las voces susurran desde el abismo, pero ¿quién osa responder?",
	"Lo que está roto no siempre busca ser reparado...",
	"Tu sombra se alarga en la oscuridad...",
	"El camino recto es el más fácil... y el más engañoso.",
	"La casa desierta se llenará de sombras,\n y allí morarán los espectros de la soledad.",
	"La ciudad yace desierta\nsus moradores son solo sombras"
]

func _ready():
	MusicManager.play_menu()
	actualizar_mensaje()

	# OJO: conectamos a un handler propio
	pantalla_toggle.pressed.connect(_on_pantalla_toggle_pressed)
	_actualizar_icono_pantalla()

	# si cambias de modo en otra escena, se actualiza aquí también
	if not DisplaySettings.window_mode_changed.is_connected(_on_window_mode_changed):
		DisplaySettings.window_mode_changed.connect(_on_window_mode_changed)

func actualizar_mensaje():
	mensaje_label.text = mensajes.pick_random()

func play_button_sound():
	if button_sound_player:
		button_sound_player.play()

func _on_creditos_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/creditos.tscn")

func _on_back_pressed():
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/menu.tscn")

func _on_pantalla_toggle_pressed():
	play_button_sound()
	DisplaySettings.toggle_fullscreen()
	_actualizar_icono_pantalla()

func _on_window_mode_changed(_is_fullscreen: bool):
	_actualizar_icono_pantalla()

func _actualizar_icono_pantalla():
	# Corrijo tu comentario: si está fullscreen, el botón debería decir "VENTANA"
	if DisplaySettings.is_fullscreen():
		pantalla_toggle.text = "▢" # ventana
	else:
		pantalla_toggle.text = "□" # completa
