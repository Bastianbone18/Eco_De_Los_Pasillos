extends Control

# Declaraciones de variables @onready
@onready var progress_bar : ProgressBar = $VBoxContainer/ProgressBar
@onready var label : Label = $VBoxContainer/Label
@onready var change_scene_button : Button = $Button

func _ready():
	progress_bar.value = 0
	label.text = "Cargando..."
	change_scene_button.disabled = true
	_simulate_loading()

async func _simulate_loading():
	var total_steps = 100
	for i in range(total_steps):
		progress_bar.value = i
		await get_tree().idle_frame()

	change_scene_button.disabled = false
	label.text = "Cargando... ¡Listo para jugar!"
	change_scene_button.connect("pressed", self, "_on_change_scene_pressed")

func _on_change_scene_pressed():
	label.text = "¡Escena cambiada!"
