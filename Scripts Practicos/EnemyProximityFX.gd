extends Node
class_name EnemyProximityFX

@export var player_path: NodePath
@export var light_path: NodePath
@export var fear_overlay_path: NodePath  # apunta al ColorRect FearOverlay

# Distancia donde empieza el miedo (más lejos = más suave)
@export var max_distance: float = 18.0
# Distancia “peligro” (casi captura)
@export var min_distance: float = 2.5

# Luz 3D
@export var max_light_energy: float = 3.0
@export var light_pulse_speed: float = 6.0
@export var light_min_energy_floor: float = 0.0  # si quieres que nunca apague del todo

# Suavizado (evita flicker)
@export var smooth_speed: float = 8.0

var _player: Node3D
var _light: Light3D
var _overlay: ColorRect
var _current_intensity: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_light = get_node_or_null(light_path) as Light3D
	_overlay = get_node_or_null(fear_overlay_path) as ColorRect

	set_process(true)

	# Seguridad: arranca apagado
	if _light:
		_light.light_energy = 0.0
	if _overlay and _overlay.material:
		_overlay.material.set_shader_parameter("intensity", 0.0)

func _process(delta: float) -> void:
	if _player == null:
		return

	var enemy := get_parent() as Node3D
	if enemy == null:
		return

	var dist := enemy.global_position.distance_to(_player.global_position)

	# Convertir distancia -> intensidad 0..1
	# dist >= max_distance -> 0
	# dist <= min_distance -> 1
	var t := inverse_lerp(max_distance, min_distance, dist) # Godot: 0..1
	t = clamp(t, 0.0, 1.0)

	# Curva más “terror” (sube más agresivo al final)
	t = t * t  # puedes probar t*t*t si lo quieres más fuerte al final

	# Suavizar para que no parpadee por micro-movimientos
	_current_intensity = lerp(_current_intensity, t, 1.0 - exp(-smooth_speed * delta))

	_apply_light(_current_intensity)
	_apply_overlay(_current_intensity)

func _apply_light(intensity: float) -> void:
	if _light == null:
		return

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * light_pulse_speed)
	var e := intensity * max_light_energy * (0.6 + 0.4 * pulse)

	# Piso mínimo opcional
	e = max(e, light_min_energy_floor * intensity)

	_light.light_energy = e

func _apply_overlay(intensity: float) -> void:
	if _overlay == null:
		return
	if _overlay.material == null:
		return
	_overlay.material.set_shader_parameter("intensity", intensity)
