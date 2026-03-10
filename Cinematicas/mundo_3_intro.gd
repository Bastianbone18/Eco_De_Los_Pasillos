extends Control

@onready var fondo: ColorRect = $Fondo
@onready var texto: Label = $TextoDespierta
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var imagen_lore: TextureRect = $ImagenLore

@export var next_scene_path: String = "res://Modelos_Blender/TerrenoMundo3/Mundo3.tscn"
@export var lore_images: Array[Texture2D] = []

var shake_strength := 0.0
var base_pos := Vector2.ZERO
var shaking := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# ✅ Marcar intro de Mundo 3 como vista
	GameData.intro_mundo3_done = true

	# ✅ Dejar preparado que el destino real es Mundo3
	GameData.current_scene_path = next_scene_path

	# ✅ Guardar inmediatamente para que si muere / carga no repita la intro
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_from_gamedata"):
		sm.save_from_gamedata(GameData)
		print("[Mundo3Intro] intro_mundo3_done guardado.")

	texto.visible = true
	texto.text = "DESPIERTA"

	base_pos = texto.position

	if imagen_lore:
		imagen_lore.visible = false

	if anim.has_animation("intro"):
		anim.play("intro")
	else:
		push_error("[Mundo3Intro] No existe la animación 'intro'.")

func _process(_delta: float) -> void:
	if not shaking:
		return

	texto.position = base_pos + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)

func set_shaking(active: bool) -> void:
	shaking = active
	if not active:
		texto.position = base_pos

func set_shake_strength(value: float) -> void:
	shake_strength = value

func show_lore_image(index: int) -> void:
	if imagen_lore == null:
		return
	if index < 0 or index >= lore_images.size():
		return

	imagen_lore.texture = lore_images[index]
	imagen_lore.visible = true

func hide_lore_image() -> void:
	if imagen_lore:
		imagen_lore.visible = false

func finish_intro() -> void:
	get_tree().paused = false
	print("[Mundo3Intro] fin intro -> cargando Mundo3 real: ", next_scene_path)
	get_tree().change_scene_to_file(next_scene_path)
