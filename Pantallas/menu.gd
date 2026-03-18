extends Control

# ----------------------
# NODOS
# ----------------------
@onready var slider_musica_menu: HSlider = $Volumen/SliderMusicaMenu
@onready var hover_player: AudioStreamPlayer = $AudioStreamPlayerBoton
@onready var click_player: AudioStreamPlayer = $AudioStreamPlayerClick
@onready var anim_player: AnimationPlayer = $Titulo/AnimationPlayer

# Encendido
@onready var flash_rect: CanvasItem = $FlashRect
@onready var flash_anim: AnimationPlayer = $FlashRect/Flashani
@onready var tv_on_audio: AudioStreamPlayer = $TV_On
@onready var root_container: Control = $VBoxContainer

# Apagado
@onready var power_off_rect: CanvasItem = $Flash_off
@onready var power_off_anim: AnimationPlayer = $Flash_off/Flashapagar
@onready var tv_off_audio: AudioStreamPlayer = $Flash_off/TV_OFF

# ----------------------
# SONIDOS
# ----------------------
var hover_sound = preload("res://Musica y sonidos/Sonidos/Click_linterna.ogg")
var click_sound = preload("res://Musica y sonidos/Sonidos/Clicks.ogg")

const BUS_NAME: String = "Menu"  # Bus para efectos de UI
var _exiting: bool = false

# ----------------------
# READY
# ----------------------
func _ready() -> void:
	_reset_flash_overlay()
	_reset_power_off_overlay()

	call_deferred("_connect_buttons")

	slider_musica_menu.min_value = 0.0
	slider_musica_menu.max_value = 100.0
	slider_musica_menu.step = 0.1
	slider_musica_menu.value_changed.connect(_on_slider_musica_menu_changed)

	if hover_player:
		hover_player.bus = BUS_NAME
	if click_player:
		click_player.bus = BUS_NAME

	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index >= 0:
		var volumen_actual_db: float = AudioServer.get_bus_volume_db(bus_index)
		slider_musica_menu.value = db_to_slider_value(volumen_actual_db)
	else:
		bus_index = AudioServer.get_bus_index("Master")
		if bus_index >= 0:
			var volumen_actual_db: float = AudioServer.get_bus_volume_db(bus_index)
			slider_musica_menu.value = db_to_slider_value(volumen_actual_db)

	if not MusicManager.did_menu_flash:
		MusicManager.did_menu_flash = true
		if tv_on_audio:
			tv_on_audio.play()
		_show_flash_overlay()
		if flash_anim:
			flash_anim.play("Flash")
			await flash_anim.animation_finished
		_reset_flash_overlay()
		await MusicManager.play_menu(0.6)
	else:
		MusicManager.play_menu()

	if anim_player:
		anim_player.play("FadeLoop")

# ----------------------
# CONEXIÓN DE BOTONES
# ----------------------
func _connect_buttons() -> void:
	var botones = get_tree().get_nodes_in_group("botones")
	for button in botones:
		if not button.is_connected("mouse_entered", Callable(self, "_on_button_hover")):
			button.mouse_entered.connect(_on_button_hover)
		if not button.is_connected("pressed", Callable(self, "_on_button_pressed")):
			button.pressed.connect(_on_button_pressed)

# ----------------------
# SLIDER DE VOLUMEN
# ----------------------
func _on_slider_musica_menu_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index >= 0:
		var volumen_db: float = slider_value_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, volumen_db)

# ----------------------
# APAGADO Y SALIDA
# ----------------------
func _on_exit_pressed() -> void:
	if _exiting: return
	_exiting = true
	await _power_off_then_quit()

func _power_off_then_quit() -> void:
	MusicManager.stop(false)
	_show_power_off_overlay()
	if tv_off_audio:
		tv_off_audio.play()
	if power_off_anim and power_off_anim.has_animation("OFF"):
		power_off_anim.play("OFF")
		await power_off_anim.animation_finished
	_reset_power_off_overlay()
	get_tree().quit()

# ----------------------
# SONIDOS BOTONES
# ----------------------
func _on_button_hover() -> void:
	if hover_player:
		hover_player.stop()
		hover_player.stream = hover_sound
		hover_player.pitch_scale = randf_range(0.95, 1.05)
		hover_player.play()

func _on_button_pressed() -> void:
	if click_player:
		click_player.stop()
		click_player.stream = click_sound
		click_player.pitch_scale = randf_range(0.95, 1.05)
		click_player.play()
		await get_tree().process_frame

# ----------------------
# OVERLAY ENCENDIDO
# ----------------------
func _reset_flash_overlay() -> void:
	if flash_anim:
		flash_anim.stop()
	if flash_rect:
		flash_rect.visible = false
		var c := flash_rect.modulate
		c.a = 0.0
		flash_rect.modulate = c

func _show_flash_overlay() -> void:
	if flash_rect:
		var c := flash_rect.modulate
		c.a = 1.0
		flash_rect.modulate = c
		flash_rect.visible = true

# ----------------------
# OVERLAY APAGADO
# ----------------------
func _reset_power_off_overlay() -> void:
	if power_off_anim:
		power_off_anim.stop()
	if power_off_rect:
		power_off_rect.visible = false
		var c := power_off_rect.modulate
		c.a = 0.0
		power_off_rect.modulate = c

func _show_power_off_overlay() -> void:
	if power_off_rect:
		var c := power_off_rect.modulate
		c.a = 1.0
		power_off_rect.modulate = c
		power_off_rect.visible = true

# ----------------------
# CONVERSIÓN DB <-> SLIDER
# ----------------------
func db_to_slider_value(db: float) -> float:
	db = clamp(db, -80.0, 0.0)
	return lerp(0.0, float(slider_musica_menu.max_value), (db + 80.0) / 80.0)

func slider_value_to_db(value: float) -> float:
	var t: float = clamp(value / float(slider_musica_menu.max_value), 0.0, 1.0)
	return lerp(-80.0, 0.0, t)

# ----------------------
# BOTONES ESCENAS
# ----------------------
func _on_play_pressed() -> void:
	MusicManager.stop(false)
	await get_tree().create_timer(0.05).timeout
	get_tree().change_scene_to_file("res://Pantallas/Register.tscn")

func _on_options_pressed() -> void:
	MusicManager.stop(false)
	await get_tree().create_timer(0.05).timeout
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
