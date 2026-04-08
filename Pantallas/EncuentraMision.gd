extends CanvasLayer
class_name EncuentraMision

@onready var fx_rect: ColorRect = $Root/FXRect
@onready var ritual_label: Label = $Root/TopCenter/RitualLabel
@onready var sigil_icon: TextureRect = $Root/BottomLeft/SigilIcon
@onready var objective_label: Label = $Root/BottomLeft/ObjectiveLabel

@export var mission_title: String = "Completa el ritual"
@export var portal_title: String = "Entra al portal"

@export var current_progress: int = 0
@export var max_progress: int = 3

@export_range(1.0, 100.0, 1.0) var intensity: float = 1.0
var target_intensity: float = 1.0

var ritual_base_pos: Vector2
var icon_base_pos: Vector2
var objective_base_pos: Vector2

var ritual_base_rotation: float = 0.0
var objective_base_rotation: float = 0.0

var flash_amount: float = 0.0
var mission_active: bool = false
var mission_finished: bool = false

var completed_pedestals: Dictionary = {}

var color_base: Color = Color("E7E1D6")
var color_mid: Color = Color("C7A15B")
var color_end: Color = Color("8B2E2E")

var fx_material_instance: ShaderMaterial = null

# Timers / fases para glitches orgánicos
var title_glitch_timer: float = 0.0
var count_glitch_timer: float = 0.0
var title_snap_timer: float = 0.0
var count_snap_timer: float = 0.0
var title_drift_seed: float = 0.0
var count_drift_seed: float = 0.0

# Estado de snaps
var title_snap_offset: Vector2 = Vector2.ZERO
var count_snap_offset: Vector2 = Vector2.ZERO
var title_snap_rot: float = 0.0
var count_snap_rot: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	sigil_icon.pivot_offset = sigil_icon.size * 0.5
	ritual_label.pivot_offset = ritual_label.size * 0.5
	objective_label.pivot_offset = objective_label.size * 0.5

	ritual_label.text = mission_title
	_update_objective_text()

	ritual_base_pos = ritual_label.position
	icon_base_pos = sigil_icon.position
	objective_base_pos = objective_label.position

	ritual_base_rotation = ritual_label.rotation
	objective_base_rotation = objective_label.rotation

	title_drift_seed = randf() * 10.0
	count_drift_seed = randf() * 10.0

	_setup_fx_rect()
	_apply_visuals(0.0, 0.0)


func _setup_fx_rect() -> void:
	if fx_rect == null:
		return

	fx_rect.color = Color(0.14, 0.05, 0.05, 0.0)

	if fx_rect.material is ShaderMaterial:
		fx_material_instance = (fx_rect.material as ShaderMaterial).duplicate()
		fx_rect.material = fx_material_instance
		_apply_fx_shader(0.0, 0.0)


func _process(delta: float) -> void:
	if not mission_active:
		return

	intensity = lerpf(intensity, target_intensity, delta * 2.4)

	var t: float = inverse_lerp(1.0, 100.0, intensity)
	var time: float = Time.get_ticks_msec() / 1000.0

	var breathe: float = sin(time * lerpf(1.2, 4.3, t)) * 0.5 + 0.5
	var panic_pulse: float = sin(time * lerpf(2.0, 8.0, t)) * 0.5 + 0.5

	# --------------------------------------------------
	# TÍTULO - movimiento más vivo y errático
	# --------------------------------------------------
	var title_curve: Vector2 = _curve_drift(time, title_drift_seed, lerpf(0.0, 9.0, t))
	var title_micro: Vector2 = Vector2(
		sin(time * 12.0),
		cos(time * 8.0)
	) * lerpf(0.0, 0.9, t)

	title_glitch_timer -= delta
	title_snap_timer -= delta

	if title_glitch_timer <= 0.0:
		title_glitch_timer = randf_range(0.05, 0.22)

		if randf() < lerpf(0.08, 0.86, t):
			title_snap_offset = Vector2(
				randf_range(-6.0, 6.0) * t,
				randf_range(-2.0, 2.0) * t
			)
			title_snap_rot = randf_range(-0.018, 0.018) * t
			title_snap_timer = randf_range(0.02, 0.07)
		else:
			title_snap_offset = Vector2.ZERO
			title_snap_rot = 0.0
			title_snap_timer = 0.0

	if title_snap_timer <= 0.0:
		title_snap_offset = title_snap_offset.lerp(Vector2.ZERO, delta * 14.0)
		title_snap_rot = lerpf(title_snap_rot, 0.0, delta * 14.0)

	var title_final_pos: Vector2 = ritual_base_pos + title_curve + title_micro + title_snap_offset
	var title_final_rot: float = ritual_base_rotation + _curve_rot(time, title_drift_seed, t) + title_snap_rot

	ritual_label.position = title_final_pos
	ritual_label.rotation = title_final_rot

	# --------------------------------------------------
	# CONTADOR - más contenido, pero también vivo
	# --------------------------------------------------
	var count_curve: Vector2 = _curve_drift(time * 0.9, count_drift_seed, lerpf(0.0, 3.6, t))
	var count_micro: Vector2 = Vector2(
		sin(time * 7.4),
		cos(time * 5.9)
	) * lerpf(0.0, 0.35, t)

	count_glitch_timer -= delta
	count_snap_timer -= delta

	if count_glitch_timer <= 0.0:
		count_glitch_timer = randf_range(0.10, 0.30)

		if randf() < lerpf(0.03, 0.42, t):
			count_snap_offset = Vector2(
				randf_range(-2.2, 2.2) * t,
				randf_range(-0.8, 0.8) * t
			)
			count_snap_rot = randf_range(-0.012, 0.012) * t
			count_snap_timer = randf_range(0.02, 0.06)
		else:
			count_snap_offset = Vector2.ZERO
			count_snap_rot = 0.0
			count_snap_timer = 0.0

	if count_snap_timer <= 0.0:
		count_snap_offset = count_snap_offset.lerp(Vector2.ZERO, delta * 14.0)
		count_snap_rot = lerpf(count_snap_rot, 0.0, delta * 14.0)

	objective_label.position = objective_base_pos + count_curve + count_micro + count_snap_offset
	objective_label.rotation = objective_base_rotation + _curve_rot(time * 0.8, count_drift_seed, t) * 0.45 + count_snap_rot

	# --------------------------------------------------
	# ICONO - fijo pero con respiración mínima
	# --------------------------------------------------
	sigil_icon.position = icon_base_pos
	var icon_scale: float = lerpf(1.0, 1.03, t) + breathe * lerpf(0.0, 0.02, t)
	sigil_icon.scale = Vector2(icon_scale, icon_scale)

	flash_amount = lerpf(flash_amount, 0.0, delta * 3.0)

	_apply_visuals(t, breathe)
	_apply_fx_shader(t, panic_pulse)


func _frac(value: float) -> float:
	return value - floor(value)


func _curve_drift(time: float, seed: float, amount: float) -> Vector2:
	# Movimiento inclinado / errático tipo _/_ con mezcla de rampas y curvas
	var phase1: float = _frac(time * 0.42 + seed * 0.137)
	var phase2: float = _frac(time * 0.29 + seed * 0.271)

	var ramp1: float = phase1 * 2.0 - 1.0
	var ramp2: float = phase2 * 2.0 - 1.0

	var x: float = ramp1 * amount * 0.85
	x += sin(time * 1.7 + seed * 2.1) * amount * 0.22
	x += sin(time * 3.9 + seed * 0.8) * amount * 0.10

	var y: float = ramp2 * amount * 0.18
	y += cos(time * 1.3 + seed * 1.9) * amount * 0.08
	y += sin(time * 4.2 + seed * 0.5) * amount * 0.04

	return Vector2(x, y)


func _curve_rot(time: float, seed: float, t: float) -> float:
	var ramp: float = _frac(time * 0.31 + seed * 0.17) * 2.0 - 1.0
	return ramp * 0.0035 * t + sin(time * 2.8 + seed) * 0.0022 * t


func _apply_visuals(t: float, breathe: float) -> void:
	var title_color: Color
	var icon_color: Color
	var count_color: Color

	if t < 0.5:
		var nt: float = t / 0.5
		title_color = color_base.lerp(color_mid, nt)
		icon_color = Color("CFC6B8").lerp(Color("D8BB7A"), nt)
		count_color = color_base.lerp(color_mid, nt * 0.7)
	else:
		var nt2: float = (t - 0.5) / 0.5
		title_color = color_mid.lerp(color_end, nt2)
		icon_color = Color("D8BB7A").lerp(Color("C96E6E"), nt2)
		count_color = color_mid.lerp(color_end, nt2 * 0.78)

	var flash_tint: Color = Color(1.0, 0.92, 0.92, 1.0)

	title_color = title_color.lerp(flash_tint, flash_amount * 0.30)
	icon_color = icon_color.lerp(flash_tint, flash_amount * 0.18)
	count_color = count_color.lerp(flash_tint, flash_amount * 0.15)

	ritual_label.modulate = title_color
	sigil_icon.modulate = icon_color
	objective_label.modulate = count_color

	ritual_label.add_theme_color_override("font_color", title_color)
	objective_label.add_theme_color_override("font_color", count_color)

	var title_scale: float = lerpf(1.0, 1.055, t) + breathe * lerpf(0.0, 0.018, t)
	ritual_label.scale = Vector2(title_scale, title_scale)

	var count_scale: float = lerpf(1.0, 1.02, t) + breathe * lerpf(0.0, 0.008, t)
	objective_label.scale = Vector2(count_scale, count_scale)

	var fx_alpha: float = lerpf(0.02, 0.24, t)
	fx_rect.color = Color(0.18, 0.05, 0.05, fx_alpha)


func _apply_fx_shader(t: float, pulse: float) -> void:
	if fx_material_instance == null:
		return

	var progress_band: float = clampf(float(current_progress) / float(max_progress), 0.0, 1.0)

	fx_material_instance.set_shader_parameter("progress_intensity", t)
	fx_material_instance.set_shader_parameter("mission_progress", progress_band)
	fx_material_instance.set_shader_parameter("pulse_amount", pulse)
	fx_material_instance.set_shader_parameter("flash_amount", flash_amount)

	fx_material_instance.set_shader_parameter("scanline_strength", lerpf(0.03, 0.28, t))
	fx_material_instance.set_shader_parameter("noise_strength", lerpf(0.012, 0.14, t))
	fx_material_instance.set_shader_parameter("ghost_strength", lerpf(0.0, 0.12, t))
	fx_material_instance.set_shader_parameter("chroma_strength", lerpf(0.0, 0.0048, t))
	fx_material_instance.set_shader_parameter("glitch_strength", lerpf(0.0, 0.09, t))
	fx_material_instance.set_shader_parameter("band_shift_strength", lerpf(0.0, 0.06, t))
	fx_material_instance.set_shader_parameter("vignette_strength", lerpf(0.02, 0.20, t))
	fx_material_instance.set_shader_parameter("darkness_strength", lerpf(0.02, 0.22, t))
	fx_material_instance.set_shader_parameter("red_push", lerpf(0.0, 0.30, t))
	fx_material_instance.set_shader_parameter("curve_wave_strength", lerpf(0.0, 0.03, t))
	fx_material_instance.set_shader_parameter("scream_line_strength", lerpf(0.0, 0.16, t))


func _update_objective_text() -> void:
	objective_label.text = str(current_progress) + "/" + str(max_progress)


func start_mission() -> void:
	mission_active = true
	mission_finished = false
	visible = true

	completed_pedestals.clear()

	ritual_label.text = mission_title
	current_progress = 0
	_update_objective_text()

	intensity = 8.0
	target_intensity = 8.0
	flash_amount = 0.25

	title_glitch_timer = 0.0
	count_glitch_timer = 0.0
	title_snap_timer = 0.0
	count_snap_timer = 0.0

	title_snap_offset = Vector2.ZERO
	count_snap_offset = Vector2.ZERO
	title_snap_rot = 0.0
	count_snap_rot = 0.0

	ritual_label.position = ritual_base_pos
	objective_label.position = objective_base_pos
	ritual_label.rotation = ritual_base_rotation
	objective_label.rotation = objective_base_rotation
	ritual_label.scale = Vector2.ONE
	objective_label.scale = Vector2.ONE

	sigil_icon.position = icon_base_pos
	sigil_icon.scale = Vector2.ONE

	var tt: float = inverse_lerp(1.0, 100.0, intensity)
	_apply_visuals(tt, 0.0)
	_apply_fx_shader(tt, 0.0)


func set_progress(value: int) -> void:
	current_progress = clampi(value, 0, max_progress)
	_update_objective_text()

	match current_progress:
		0:
			set_intensity(8.0)
		1:
			set_intensity(36.0)
			trigger_flash(0.35)
		2:
			set_intensity(68.0)
			trigger_flash(0.58)
		3:
			set_intensity(92.0)
			trigger_flash(0.90)


func set_intensity(value: float) -> void:
	target_intensity = clampf(value, 1.0, 100.0)


func add_intensity(amount: float) -> void:
	set_intensity(target_intensity + amount)


func portal_opened() -> void:
	ritual_label.text = portal_title
	set_intensity(100.0)
	trigger_flash(1.0)


func reset_mission() -> void:
	mission_finished = false
	completed_pedestals.clear()

	ritual_label.text = mission_title
	current_progress = 0
	_update_objective_text()
	set_intensity(8.0)


func hide_mission() -> void:
	mission_active = false
	visible = false


func trigger_flash(amount: float = 1.0) -> void:
	flash_amount = clampf(amount, 0.0, 1.0)


func set_dialogue_overlay_active(active: bool) -> void:
	if active:
		ritual_label.visible = false
		sigil_icon.visible = false
		objective_label.visible = false
		fx_rect.visible = false
	else:
		ritual_label.visible = true
		sigil_icon.visible = true
		objective_label.visible = true
		fx_rect.visible = true


func register_pedestal_completed(pedestal_id: String) -> void:
	if pedestal_id == "":
		return

	if completed_pedestals.has(pedestal_id):
		return

	completed_pedestals[pedestal_id] = true

	var total_completed: int = completed_pedestals.size()
	set_progress(total_completed)

	if total_completed >= max_progress:
		mission_finished = true
		portal_opened()
