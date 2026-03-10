extends Node
class_name AtmosphereManager

@export var world_env_path: NodePath
@export var sun_path: NodePath
@export var smooth_time: float = 1.25
@export var ambient_floor_color: Color = Color8(120, 130, 140)

# ✅ Autosave real
@export var autosave_on_stage_change: bool = true
@export var autosave_cooldown: float = 0.35

var stage: int = 0

var _world_env: WorldEnvironment
var _env: Environment
var _sun: DirectionalLight3D
var _tween: Tween

var _save_timer: Timer


func _ready() -> void:
	add_to_group("atmosphere")

	_world_env = get_node_or_null(world_env_path) as WorldEnvironment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D

	if _world_env == null:
		push_error("[AtmosphereManager] world_env_path inválido")
		return

	_env = _world_env.environment
	if _env == null:
		push_error("[AtmosphereManager] WorldEnvironment no tiene Environment asignado")
		return

	_env.adjustment_enabled = true
	_env.fog_enabled = true
	_env.volumetric_fog_enabled = true

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = ambient_floor_color

	# ✅ Timer anti-spam autosave
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	add_child(_save_timer)

	# ✅ Cargar stage persistido (si existe)
	var saved_stage: int = 0
	if "world2_atmos_stage" in GameData:
		saved_stage = int(GameData.world2_atmos_stage)

	stage = clamp(saved_stage, 0, 3)
	apply_stage(stage, true)

	print("[AtmosphereManager] READY ✅ stage=", stage)


func advance_stage() -> void:
	set_stage(stage + 1)


func set_stage(new_stage: int) -> void:
	new_stage = clamp(new_stage, 0, 3)
	if new_stage == stage:
		return

	stage = new_stage

	# ✅ Guardar stage actual en GameData (si existe)
	if "world2_atmos_stage" in GameData:
		GameData.world2_atmos_stage = stage
	else:
		push_warning("[AtmosphereManager] GameData no tiene world2_atmos_stage (añádelo).")

	apply_stage(stage, false)

	# ✅ Autosave real al disco
	if autosave_on_stage_change:
		_request_autosave()


func _request_autosave() -> void:
	if GameData.current_slot_id <= 0:
		return
	if _save_timer == null:
		return
	if _save_timer.time_left > 0.0:
		return

	_save_timer.start(autosave_cooldown)
	if not _save_timer.timeout.is_connected(_do_autosave):
		_save_timer.timeout.connect(_do_autosave, CONNECT_ONE_SHOT)


func _do_autosave() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[AtmosphereManager] Autosave ✅ stage=", stage)


# =========================================================
# TU apply_stage ORIGINAL (sin cambiar valores)
# =========================================================
func apply_stage(s: int, immediate: bool) -> void:
	var fog_density: float = 0.013
	var fog_light_energy: float = 0.58
	var fog_sun_scatter: float = 0.035
	var fog_aerial: float = 0.16
	var fog_sky_affect: float = 0.42
	var fog_height: float = -2.0
	var fog_height_density: float = 0.12
	var fog_light_color: Color = Color8(105, 120, 134)

	var v_density: float = 0.045
	var v_length: float = 92.0
	var v_anisotropy: float = 0.22
	var v_ambient_inject: float = 0.16
	var v_sky_affect: float = 0.40
	var v_albedo: Color = Color8(150, 160, 168)

	var adj_brightness: float = 0.99
	var adj_contrast: float = 1.06
	var adj_saturation: float = 0.92

	var sun_color: Color = Color8(110, 130, 150)
	var sun_energy: float = 0.64
	var sun_indirect: float = 0.36
	var sun_vol_fog_energy: float = 0.60

	var amb_energy: float = 0.62
	var exposure: float = 0.92

	match s:
		0:
			amb_energy = 0.62
			exposure = 0.92
			adj_brightness = 0.99
			sun_energy = 0.64
			sun_indirect = 0.36

		1:
			fog_density = 0.017
			fog_light_energy = 0.55
			fog_sky_affect = 0.38
			fog_height_density = 0.14
			fog_light_color = Color8(92, 106, 118)

			v_density = 0.060
			v_length = 78.0
			v_anisotropy = 0.18
			v_ambient_inject = 0.15
			v_sky_affect = 0.34
			v_albedo = Color8(132, 142, 150)

			adj_brightness = 0.975
			adj_contrast = 1.10
			adj_saturation = 0.88

			sun_energy = 0.58
			sun_indirect = 0.32
			sun_vol_fog_energy = 0.55
			sun_color = Color8(96, 114, 132)

			amb_energy = 0.58
			exposure = 0.88

		2:
			fog_density = 0.021
			fog_light_energy = 0.53
			fog_sky_affect = 0.34
			fog_height_density = 0.16
			fog_light_color = Color8(78, 90, 100)

			v_density = 0.075
			v_length = 66.0
			v_anisotropy = 0.14
			v_ambient_inject = 0.15
			v_sky_affect = 0.30
			v_albedo = Color8(118, 126, 132)

			adj_brightness = 0.965
			adj_contrast = 1.14
			adj_saturation = 0.80

			sun_energy = 0.54
			sun_indirect = 0.30
			sun_vol_fog_energy = 0.52
			sun_color = Color8(82, 96, 110)

			amb_energy = 0.56
			exposure = 0.90

		3:
			fog_density = 0.024
			fog_light_energy = 0.56
			fog_sky_affect = 0.30
			fog_height_density = 0.18
			fog_light_color = Color8(70, 80, 88)

			v_density = 0.085
			v_length = 58.0
			v_anisotropy = 0.10
			v_ambient_inject = 0.18
			v_sky_affect = 0.26
			v_albedo = Color8(108, 114, 118)

			adj_brightness = 0.97
			adj_contrast = 1.14
			adj_saturation = 0.74

			sun_energy = 0.56
			sun_indirect = 0.34
			sun_vol_fog_energy = 0.52
			sun_color = Color8(76, 86, 94)

			amb_energy = 0.88
			exposure = 1.05

	_kill_tween()

	if immediate:
		_apply_env_values(
			fog_density, fog_light_energy, fog_sun_scatter, fog_aerial, fog_sky_affect, fog_height, fog_height_density, fog_light_color,
			v_density, v_length, v_anisotropy, v_ambient_inject, v_sky_affect, v_albedo,
			adj_brightness, adj_contrast, adj_saturation,
			amb_energy, ambient_floor_color, exposure
		)
		_apply_sun_values(sun_color, sun_energy, sun_indirect, sun_vol_fog_energy)
		return

	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(_env, "fog_density", fog_density, smooth_time)
	_tween.tween_property(_env, "fog_light_energy", fog_light_energy, smooth_time)
	_tween.tween_property(_env, "fog_sun_scatter", fog_sun_scatter, smooth_time)
	_tween.tween_property(_env, "fog_aerial_perspective", fog_aerial, smooth_time)
	_tween.tween_property(_env, "fog_sky_affect", fog_sky_affect, smooth_time)
	_tween.tween_property(_env, "fog_height", fog_height, smooth_time)
	_tween.tween_property(_env, "fog_height_density", fog_height_density, smooth_time)
	_tween.tween_property(_env, "fog_light_color", fog_light_color, smooth_time)

	_tween.tween_property(_env, "volumetric_fog_density", v_density, smooth_time)
	_tween.tween_property(_env, "volumetric_fog_length", v_length, smooth_time)
	_tween.tween_property(_env, "volumetric_fog_anisotropy", v_anisotropy, smooth_time)
	_tween.tween_property(_env, "volumetric_fog_ambient_inject", v_ambient_inject, smooth_time)
	_tween.tween_property(_env, "volumetric_fog_sky_affect", v_sky_affect, smooth_time)
	_tween.tween_property(_env, "volumetric_fog_albedo", v_albedo, smooth_time)

	_env.adjustment_enabled = true
	_tween.tween_property(_env, "adjustment_brightness", adj_brightness, smooth_time)
	_tween.tween_property(_env, "adjustment_contrast", adj_contrast, smooth_time)
	_tween.tween_property(_env, "adjustment_saturation", adj_saturation, smooth_time)

	_tween.tween_property(_env, "ambient_light_energy", amb_energy, smooth_time)
	_tween.tween_property(_env, "ambient_light_color", ambient_floor_color, smooth_time)
	_tween.tween_property(_env, "tonemap_exposure", exposure, smooth_time)

	if _sun != null:
		_tween.tween_property(_sun, "light_color", sun_color, smooth_time)
		_tween.tween_property(_sun, "light_energy", sun_energy, smooth_time)
		_tween.tween_property(_sun, "light_indirect_energy", sun_indirect, smooth_time)
		_tween.tween_property(_sun, "light_volumetric_fog_energy", sun_vol_fog_energy, smooth_time)

func _apply_env_values(
	fog_density: float, fog_light_energy: float, fog_sun_scatter: float, fog_aerial: float, fog_sky_affect: float,
	fog_height: float, fog_height_density: float, fog_light_color: Color,
	v_density: float, v_length: float, v_anisotropy: float, v_ambient_inject: float, v_sky_affect: float, v_albedo: Color,
	adj_brightness: float, adj_contrast: float, adj_saturation: float,
	amb_energy: float, amb_color: Color, exposure: float
) -> void:
	_env.fog_enabled = true
	_env.fog_density = fog_density
	_env.fog_light_energy = fog_light_energy
	_env.fog_sun_scatter = fog_sun_scatter
	_env.fog_aerial_perspective = fog_aerial
	_env.fog_sky_affect = fog_sky_affect
	_env.fog_height = fog_height
	_env.fog_height_density = fog_height_density
	_env.fog_light_color = fog_light_color

	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = v_density
	_env.volumetric_fog_length = v_length
	_env.volumetric_fog_anisotropy = v_anisotropy
	_env.volumetric_fog_ambient_inject = v_ambient_inject
	_env.volumetric_fog_sky_affect = v_sky_affect
	_env.volumetric_fog_albedo = v_albedo

	_env.adjustment_enabled = true
	_env.adjustment_brightness = adj_brightness
	_env.adjustment_contrast = adj_contrast
	_env.adjustment_saturation = adj_saturation

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = amb_color
	_env.ambient_light_energy = amb_energy

	_env.tonemap_exposure = exposure

func _apply_sun_values(c: Color, e: float, ie: float, vfe: float) -> void:
	if _sun == null:
		return
	_sun.light_color = c
	_sun.light_energy = e
	_sun.light_indirect_energy = ie
	_sun.light_volumetric_fog_energy = vfe

func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
