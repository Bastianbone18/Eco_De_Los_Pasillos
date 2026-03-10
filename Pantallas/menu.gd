extends Control

@onready var slider_musica_menu: HSlider = $Volumen/SliderMusicaMenu
@onready var button_sound_player: AudioStreamPlayer = $AudioStreamPlayerBoton
@onready var anim_player: AnimationPlayer = $Titulo/AnimationPlayer

# Encendido (ya lo tenías)
@onready var flash_rect: CanvasItem = $FlashRect
@onready var flash_anim: AnimationPlayer = $FlashRect/Flashani
@onready var tv_on_audio: AudioStreamPlayer = $TV_On
@onready var root_container: Control = $VBoxContainer

# 🔌 Apagado (tus nodos nuevos)
@onready var power_off_rect: CanvasItem = $Flash_off              # ColorRect / Control
@onready var power_off_anim: AnimationPlayer = $Flash_off/Flashapagar
@onready var tv_off_audio: AudioStreamPlayer = $Flash_off/TV_OFF

const BUS_NAME: String = "Musica"
var _exiting: bool = false   # evita doble click en Salir

func _ready() -> void:

	_reset_flash_overlay()
	_reset_power_off_overlay()  # importante: que no quede visible al volver

	# Slider volumen
	slider_musica_menu.min_value = 0.0
	slider_musica_menu.max_value = 100.0
	slider_musica_menu.step = 0.1
	slider_musica_menu.connect("value_changed", Callable(self, "_on_slider_musica_menu_changed"))

	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	var volumen_actual_db: float = AudioServer.get_bus_volume_db(bus_index)
	slider_musica_menu.value = db_to_slider_value(volumen_actual_db)

	# Encendido TV solo 1 vez
	if not MusicManager.did_menu_flash:
		MusicManager.did_menu_flash = true
		if tv_on_audio: tv_on_audio.play()
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


func _on_slider_musica_menu_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	var volumen_db: float = slider_value_to_db(value)
	AudioServer.set_bus_volume_db(bus_index, volumen_db)

# ----------------------
# 🔌 Apagado y salida
# ----------------------
func _on_exit_pressed() -> void:
	if _exiting: return
	_exiting = true
	play_button_sound()
	await _power_off_then_quit()

func _power_off_then_quit() -> void:
	# baja música con fade
	MusicManager.stop(false)
	# muestra overlay de apagado y reproduce animación
	_show_power_off_overlay()
	if tv_off_audio:
		tv_off_audio.play()
	if power_off_anim and power_off_anim.has_animation("OFF"):
		power_off_anim.play("OFF")
		await power_off_anim.animation_finished
	# por si acaso, ocultar overlay al final
	_reset_power_off_overlay()
	get_tree().quit()

# ----------------------
# Encendido overlay utils
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
# Apagado overlay utils
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
# Conversión dB <-> Slider
# ----------------------
func db_to_slider_value(db: float) -> float:
	db = clamp(db, -80.0, 0.0)
	return lerp(0.0, float(slider_musica_menu.max_value), (db + 80.0) / 80.0)

func slider_value_to_db(value: float) -> float:
	var t: float = clamp(value / float(slider_musica_menu.max_value), 0.0, 1.0)
	return lerp(-80.0, 0.0, t)

# Sonido botón
func play_button_sound() -> void:
	if button_sound_player:
		button_sound_player.play()

# Botones restantes
func _on_play_pressed() -> void:
	play_button_sound()
	MusicManager.stop(false)
	get_tree().change_scene_to_file("res://Pantallas/Register.tscn")

func _on_options_pressed() -> void:
	play_button_sound()
	get_tree().change_scene_to_file("res://Pantallas/opciones.tscn")
