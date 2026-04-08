extends Control

@onready var texture_rect: TextureRect = $TextureRect

@export var zoom_step: float = 0.1
@export var max_zoom: float = 3.0
@export var min_zoom: float = 1.0 # ← tamaño original (no baja de aquí)

var current_zoom: float = 1.0

func _ready() -> void:
	texture_rect.pivot_offset = texture_rect.size / 2.0
	texture_rect.scale = Vector2.ONE * current_zoom


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = min(current_zoom + zoom_step, max_zoom)
			_apply_zoom()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = max(current_zoom - zoom_step, min_zoom)
			_apply_zoom()


func _apply_zoom() -> void:
	texture_rect.scale = Vector2.ONE * current_zoom
