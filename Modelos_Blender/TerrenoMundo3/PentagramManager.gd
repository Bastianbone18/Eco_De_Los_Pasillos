extends Node3D
class_name PentagramManager

@export var pentagrama_player_path: NodePath
@export var pentagrama_anillo_path: NodePath
@export var pentagrama_campana_path: NodePath
@export var pentagrama_vela_path: NodePath

var pentagramas: Dictionary = {}
var activados: Dictionary = {
	"anillo": false,
	"campana": false,
	"vela": false,
	"player": false
}

func _ready() -> void:
	pentagramas["player"] = get_node_or_null(pentagrama_player_path)
	pentagramas["anillo"] = get_node_or_null(pentagrama_anillo_path)
	pentagramas["campana"] = get_node_or_null(pentagrama_campana_path)
	pentagramas["vela"] = get_node_or_null(pentagrama_vela_path)

	for key in pentagramas.keys():
		var pentagrama = pentagramas[key]
		if pentagrama != null:
			_set_active_state(pentagrama, false, 0)

func activar_pentagrama(id: String) -> void:
	if not pentagramas.has(id):
		push_warning("[PentagramManager] No existe pentagrama con id: " + id)
		return

	if activados.has(id) and activados[id]:
		return

	var pentagrama = pentagramas[id]
	if pentagrama == null:
		push_warning("[PentagramManager] Nodo null para id: " + id)
		return

	activados[id] = true

	var stage := _get_stage_count()
	_set_active_state(pentagrama, true, stage)
	_refresh_existing_pentagrams()
	_revisar_activar_player()

func _revisar_activar_player() -> void:
	if activados["player"]:
		return

	if activados["anillo"] and activados["campana"] and activados["vela"]:
		var pentagrama_player = pentagramas.get("player", null)
		if pentagrama_player != null:
			activados["player"] = true
			_set_active_state(pentagrama_player, true, 4)
			_refresh_existing_pentagrams()

func _refresh_existing_pentagrams() -> void:
	var stage := _get_stage_count()

	if activados["anillo"]:
		_set_active_state(pentagramas["anillo"], true, min(stage, 4))
	if activados["campana"]:
		_set_active_state(pentagramas["campana"], true, min(stage, 4))
	if activados["vela"]:
		_set_active_state(pentagramas["vela"], true, min(stage, 4))
	if activados["player"]:
		_set_active_state(pentagramas["player"], true, 4)

func _get_stage_count() -> int:
	var c := 0
	if activados["anillo"]:
		c += 1
	if activados["campana"]:
		c += 1
	if activados["vela"]:
		c += 1
	if activados["player"]:
		c += 1
	return c

func _set_active_state(pentagrama: Node, is_active: bool, stage: int) -> void:
	var mesh := _get_mesh_instance(pentagrama)
	if mesh == null:
		push_warning("[PentagramManager] Mesh no encontrado en " + str(pentagrama))
		return

	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		var current := mesh.get_active_material(0)
		if current is ShaderMaterial:
			mat = (current as ShaderMaterial).duplicate()
			mesh.set_surface_override_material(0, mat)
		else:
			push_warning("[PentagramManager] El material de " + mesh.name + " no es ShaderMaterial")
			return

	if not is_active:
		# Shader apagado
		mat.set_shader_parameter("active", 0.0)
		mat.set_shader_parameter("pulse_speed", 0.5)
		mat.set_shader_parameter("pulse_strength", 0.8)
		mat.set_shader_parameter("emission_strength", 0.0)
		mat.set_shader_parameter("glitch_strength", 0.0)

		# Parámetros extra del shader horror
		_try_set_shader_param(mat, "time_scale", 0.8)
		_try_set_shader_param(mat, "noise_strength", 0.0)
		_try_set_shader_param(mat, "flicker_strength", 0.0)
		_try_set_shader_param(mat, "vertex_wobble", 0.0)
		_try_set_shader_param(mat, "chaos_breath_strength", 0.0)
		_try_set_shader_param(mat, "chaos_breath_speed", 0.4)
		_try_set_shader_param(mat, "fever_snap_strength", 0.0)
		_try_set_shader_param(mat, "fever_snap_rate", 10.0)
		_try_set_shader_param(mat, "bleed_strength", 0.0)
		_try_set_shader_param(mat, "bleed_speed", 1.0)
		_try_set_shader_param(mat, "cd_glitch_strength", 0.0)
		_try_set_shader_param(mat, "cd_glitch_rate", 8.0)
		_try_set_shader_param(mat, "scream_line_strength", 0.0)
		_try_set_shader_param(mat, "panic_wave_strength", 0.0)
		_try_set_shader_param(mat, "panic_wave_speed", 0.8)
		_try_set_shader_param(mat, "panic_wave_density", 18.0)
		_try_set_shader_param(mat, "radial_distort_strength", 0.0)

		_set_particles_enabled(pentagrama, false)
		_set_particles_stage(pentagrama, 0)
		return

	match stage:
		1:
			mat.set_shader_parameter("active", 1.0)
			mat.set_shader_parameter("pulse_speed", 0.55)
			mat.set_shader_parameter("pulse_strength", 0.95)
			mat.set_shader_parameter("emission_strength", 1.3)
			mat.set_shader_parameter("glitch_strength", 0.002)

			_try_set_shader_param(mat, "time_scale", 0.75)
			_try_set_shader_param(mat, "noise_strength", 0.04)
			_try_set_shader_param(mat, "flicker_strength", 0.05)
			_try_set_shader_param(mat, "vertex_wobble", 0.0015)
			_try_set_shader_param(mat, "chaos_breath_strength", 0.008)
			_try_set_shader_param(mat, "chaos_breath_speed", 0.35)
			_try_set_shader_param(mat, "fever_snap_strength", 0.001)
			_try_set_shader_param(mat, "fever_snap_rate", 8.0)
			_try_set_shader_param(mat, "bleed_strength", 0.0015)
			_try_set_shader_param(mat, "bleed_speed", 0.9)
			_try_set_shader_param(mat, "cd_glitch_strength", 0.0)
			_try_set_shader_param(mat, "cd_glitch_rate", 8.0)
			_try_set_shader_param(mat, "scream_line_strength", 0.0)
			_try_set_shader_param(mat, "panic_wave_strength", 0.0004)
			_try_set_shader_param(mat, "panic_wave_speed", 0.5)
			_try_set_shader_param(mat, "panic_wave_density", 14.0)
			_try_set_shader_param(mat, "radial_distort_strength", 0.0008)

		2:
			mat.set_shader_parameter("active", 1.0)
			mat.set_shader_parameter("pulse_speed", 0.8)
			mat.set_shader_parameter("pulse_strength", 1.08)
			mat.set_shader_parameter("emission_strength", 1.8)
			mat.set_shader_parameter("glitch_strength", 0.0035)

			_try_set_shader_param(mat, "time_scale", 0.82)
			_try_set_shader_param(mat, "noise_strength", 0.06)
			_try_set_shader_param(mat, "flicker_strength", 0.08)
			_try_set_shader_param(mat, "vertex_wobble", 0.0025)
			_try_set_shader_param(mat, "chaos_breath_strength", 0.014)
			_try_set_shader_param(mat, "chaos_breath_speed", 0.42)
			_try_set_shader_param(mat, "fever_snap_strength", 0.0018)
			_try_set_shader_param(mat, "fever_snap_rate", 10.0)
			_try_set_shader_param(mat, "bleed_strength", 0.0025)
			_try_set_shader_param(mat, "bleed_speed", 1.0)
			_try_set_shader_param(mat, "cd_glitch_strength", 0.0015)
			_try_set_shader_param(mat, "cd_glitch_rate", 10.0)
			_try_set_shader_param(mat, "scream_line_strength", 0.0)
			_try_set_shader_param(mat, "panic_wave_strength", 0.0008)
			_try_set_shader_param(mat, "panic_wave_speed", 0.65)
			_try_set_shader_param(mat, "panic_wave_density", 16.0)
			_try_set_shader_param(mat, "radial_distort_strength", 0.0014)

		3:
			mat.set_shader_parameter("active", 1.0)
			mat.set_shader_parameter("pulse_speed", 1.1)
			mat.set_shader_parameter("pulse_strength", 1.22)
			mat.set_shader_parameter("emission_strength", 2.35)
			mat.set_shader_parameter("glitch_strength", 0.005)

			_try_set_shader_param(mat, "time_scale", 0.9)
			_try_set_shader_param(mat, "noise_strength", 0.08)
			_try_set_shader_param(mat, "flicker_strength", 0.12)
			_try_set_shader_param(mat, "vertex_wobble", 0.0035)
			_try_set_shader_param(mat, "chaos_breath_strength", 0.018)
			_try_set_shader_param(mat, "chaos_breath_speed", 0.5)
			_try_set_shader_param(mat, "fever_snap_strength", 0.0025)
			_try_set_shader_param(mat, "fever_snap_rate", 12.0)
			_try_set_shader_param(mat, "bleed_strength", 0.0035)
			_try_set_shader_param(mat, "bleed_speed", 1.08)
			_try_set_shader_param(mat, "cd_glitch_strength", 0.0025)
			_try_set_shader_param(mat, "cd_glitch_rate", 12.0)
			_try_set_shader_param(mat, "scream_line_strength", 0.03)
			_try_set_shader_param(mat, "panic_wave_strength", 0.0011)
			_try_set_shader_param(mat, "panic_wave_speed", 0.8)
			_try_set_shader_param(mat, "panic_wave_density", 18.0)
			_try_set_shader_param(mat, "radial_distort_strength", 0.0022)

		4:
			mat.set_shader_parameter("active", 1.0)
			mat.set_shader_parameter("pulse_speed", 1.45)
			mat.set_shader_parameter("pulse_strength", 1.38)
			mat.set_shader_parameter("emission_strength", 2.9)
			mat.set_shader_parameter("glitch_strength", 0.0065)

			_try_set_shader_param(mat, "time_scale", 1.0)
			_try_set_shader_param(mat, "noise_strength", 0.1)
			_try_set_shader_param(mat, "flicker_strength", 0.14)
			_try_set_shader_param(mat, "vertex_wobble", 0.004)
			_try_set_shader_param(mat, "chaos_breath_strength", 0.022)
			_try_set_shader_param(mat, "chaos_breath_speed", 0.58)
			_try_set_shader_param(mat, "fever_snap_strength", 0.003)
			_try_set_shader_param(mat, "fever_snap_rate", 14.0)
			_try_set_shader_param(mat, "bleed_strength", 0.0045)
			_try_set_shader_param(mat, "bleed_speed", 1.15)
			_try_set_shader_param(mat, "cd_glitch_strength", 0.0035)
			_try_set_shader_param(mat, "cd_glitch_rate", 14.0)
			_try_set_shader_param(mat, "scream_line_strength", 0.05)
			_try_set_shader_param(mat, "panic_wave_strength", 0.0015)
			_try_set_shader_param(mat, "panic_wave_speed", 0.95)
			_try_set_shader_param(mat, "panic_wave_density", 20.0)
			_try_set_shader_param(mat, "radial_distort_strength", 0.003)

	_set_particles_enabled(pentagrama, true)
	_set_particles_stage(pentagrama, stage)

func _set_particles_enabled(pentagrama: Node, enabled: bool) -> void:
	if pentagrama == null:
		return

	for child in pentagrama.get_children():
		if child is GPUParticles3D:
			var p := child as GPUParticles3D
			p.emitting = enabled
			if enabled:
				p.restart()

func _set_particles_stage(pentagrama: Node, stage: int) -> void:
	if pentagrama == null:
		return

	var ratio := 0.0
	var speed := 0.0

	match stage:
		0:
			ratio = 0.0
			speed = 0.0
		1:
			ratio = 0.28
			speed = 0.75
		2:
			ratio = 0.5
			speed = 0.9
		3:
			ratio = 0.75
			speed = 1.05
		4:
			ratio = 1.0
			speed = 1.2

	for child in pentagrama.get_children():
		if child is GPUParticles3D:
			var p := child as GPUParticles3D
			p.amount_ratio = ratio
			p.speed_scale = speed
			p.emitting = stage > 0

func _try_set_shader_param(mat: ShaderMaterial, param_name: String, value) -> void:
	if mat == null:
		return

	var shader: Shader = mat.shader
	if shader == null:
		return

	# Godot no expone una forma limpia de validar uniforms por nombre en tiempo real,
	# así que hacemos set directo de forma segura.
	mat.set_shader_parameter(param_name, value)

func _get_mesh_instance(root: Node) -> MeshInstance3D:
	if root == null:
		return null

	if root is MeshInstance3D:
		return root as MeshInstance3D

	for child in root.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	for child in root.get_children():
		var found := _get_mesh_instance(child)
		if found != null:
			return found

	return null
