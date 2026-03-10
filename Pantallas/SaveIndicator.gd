extends CanvasLayer

@onready var sigil: CanvasItem = $Sigil
@onready var save_sfx: AudioStreamPlayer = $SaveSfx

@export var min_show_time := 2.5
@export var rotation_speed := 1.1

var enabled := true
var rotating := false
var wobble_time := 0.0

var _shown_at := 0.0
var _active := false
var _show_token := 0

func _ready() -> void:
	# ✅ IMPORTANTÍSIMO: que procese aun en pausa y esté arriba
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	sigil.visible = false
	sigil.modulate.a = 0.0
	set_process(true)

	await _connect_to_save_manager()

func _connect_to_save_manager() -> void:
	var tries := 0
	while get_node_or_null("/root/SaveManager") == null and tries < 120:
		tries += 1
		await get_tree().process_frame

	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		push_warning("[SaveIndicator] No se encontró /root/SaveManager.")
		return

	if not sm.save_started.is_connected(_on_save_started):
		sm.save_started.connect(_on_save_started)
	if not sm.save_finished.is_connected(_on_save_finished):
		sm.save_finished.connect(_on_save_finished)
	if not sm.save_failed.is_connected(_on_save_failed):
		sm.save_failed.connect(_on_save_failed)

	print("[SaveIndicator] Conectado a SaveManager ✅")

func set_enabled(v: bool) -> void:
	enabled = v
	if not enabled:
		_show_token += 1
		_active = false
		rotating = false
		sigil.visible = false
		sigil.modulate.a = 0.0
		if save_sfx:
			save_sfx.stop()

func _play_save_sound() -> void:
	if save_sfx:
		save_sfx.stop()
		save_sfx.play()

func _show_sigil_and_sound() -> void:
	_show_token += 1
	_shown_at = Time.get_ticks_msec() / 1000.0
	_active = true
	rotating = true

	sigil.visible = true
	sigil.modulate.a = 0.0

	_play_save_sound()

	var tween := create_tween()
	tween.tween_property(sigil, "modulate:a", 1.0, 0.25)

func _on_save_started() -> void:
	if not enabled:
		return
	print("[SaveIndicator] save_started ✅")
	_show_sigil_and_sound()

func _on_save_failed(err_msg: String = "") -> void:
	print("[SaveIndicator] save_failed ⚠️: ", err_msg)
	_on_save_finished()

func _on_save_finished() -> void:
	if not enabled:
		return
	if not _active:
		return

	print("[SaveIndicator] save_finished ✅")

	var token := _show_token
	var elapsed := (Time.get_ticks_msec() / 1000.0) - _shown_at
	if elapsed < min_show_time:
		# ✅ Timer que corre incluso en pausa
		await get_tree().create_timer(min_show_time - elapsed, true).timeout

	if token != _show_token:
		return
	if not enabled:
		return

	_active = false
	rotating = false

	var tween := create_tween()
	tween.tween_property(sigil, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func():
		if token == _show_token and enabled:
			sigil.visible = false
	)

func show_for_load() -> void:
	if not enabled:
		return
	_show_sigil_and_sound()

func _process(delta: float) -> void:
	if rotating:
		wobble_time += delta
		sigil.rotation += delta * rotation_speed
		sigil.rotation += sin(wobble_time * 3.5) * 0.002
