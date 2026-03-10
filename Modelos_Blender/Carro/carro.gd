extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var interaction_area: Area3D = $Area3D
@onready var safe_exit_area: Area3D = $Seguro

# Fuego principal (según tu árbol renombrado)
@onready var fuego_area: Area3D = $Fuego/FuegoArea1

# (Opcional) Fuego2, si también quieres que haga algo
@onready var fuego2_area: Area3D = $Fuego2/FuegoArea2

@onready var puerta_derecha: StaticBody3D = $Puerta_derecha/StaticBody3D
@onready var puerta_izquierda: StaticBody3D = $Puerta_izquierda/StaticBody3D

@onready var puntero_ui := get_tree().get_current_scene().find_child("CenterContainer", true, false)

var player_inside: bool = false
var isOpen: bool = false
var canInteract: bool = true

var ha_visto_dialogo_fuego: bool = false
var fire_dialogue_ready: bool = true

# Local: evita doble trigger en la misma sesión
var ya_mostro_dialogo_luz: bool = false


func _ready() -> void:
	print("[Carro] READY ->", get_path())
	print("[Carro] interaction_area:", interaction_area)
	print("[Carro] fuego_area:", fuego_area)
	print("[Carro] fuego2_area:", fuego2_area)
	print("[Carro] safe_exit_area:", safe_exit_area)

	# 🔥 Animación de fuego
	if animation_player and animation_player.has_animation("Fuego"):
		animation_player.play("Fuego")

	# Conectar señales (una sola vez, con protección)
	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_body_entered):
			interaction_area.body_entered.connect(_on_body_entered)
		if not interaction_area.body_exited.is_connected(_on_body_exited):
			interaction_area.body_exited.connect(_on_body_exited)
	else:
		push_error("[Carro] Falta $Area3D (interaction_area).")

	if fuego_area:
		if not fuego_area.body_entered.is_connected(_on_fire_area_entered):
			fuego_area.body_entered.connect(_on_fire_area_entered)
		if not fuego_area.body_exited.is_connected(_on_fire_area_exited):
			fuego_area.body_exited.connect(_on_fire_area_exited)
	else:
		push_error("[Carro] Falta $Fuego/FuegoArea1 (fuego_area).")

	# ✅ Si quieres que Fuego2 también dispare el mismo diálogo del fuego,
	# descomenta estas líneas:
	# if fuego2_area:
	# 	if not fuego2_area.body_entered.is_connected(_on_fire_area_entered):
	# 		fuego2_area.body_entered.connect(_on_fire_area_entered)
	# 	if not fuego2_area.body_exited.is_connected(_on_fire_area_exited):
	# 		fuego2_area.body_exited.connect(_on_fire_area_exited)

	if safe_exit_area:
		if not safe_exit_area.body_exited.is_connected(_on_safe_exit_area_exited):
			safe_exit_area.body_exited.connect(_on_safe_exit_area_exited)
	else:
		push_error("[Carro] Falta $Seguro (safe_exit_area).")

	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

	# Registrar metas en nodos interactuables (para RayCast)
	for body in get_tree().get_nodes_in_group("interactables_coche"):
		if body is StaticBody3D:
			body.set_meta("interactable_owner", self)
			print("✅ Meta interactable_owner asignada a:", body.name)


func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("action_use") and canInteract:
		if isOpen:
			close_door()
		else:
			open_door()


func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("Player"):
		player_inside = true
		if puntero_ui and puntero_ui.has_method("mostrar_puntero"):
			puntero_ui.mostrar_puntero()


func _on_body_exited(body: Node) -> void:
	if body and body.is_in_group("Player"):
		player_inside = false
		if puntero_ui and puntero_ui.has_method("ocultar_puntero"):
			puntero_ui.ocultar_puntero()


func _on_fire_area_entered(body: Node) -> void:
	if body and body.is_in_group("Player") and fire_dialogue_ready:
		fire_dialogue_ready = false

		if ha_visto_dialogo_fuego:
			mostrar_dialogo_fuego("nuevo_ingreso")
		else:
			mostrar_dialogo_fuego("fuego_peligroso")
			ha_visto_dialogo_fuego = true


func _on_fire_area_exited(body: Node) -> void:
	if body and body.is_in_group("Player"):
		fire_dialogue_ready = true


func _on_safe_exit_area_exited(body: Node) -> void:
	if not body or not body.is_in_group("Player"):
		return

	# ✅ Persistente: si ya se mostró alguna vez, no repetir jamás
	if GameData.buscar_linterna_done:
		print("⏩ Buscar_linterna ya fue mostrado (save). No se repetirá.")
		return

	# Local: evita doble trigger en la misma sesión
	if ya_mostro_dialogo_luz:
		return

	var player := get_tree().get_current_scene().get_node_or_null("Player")
	if player and ("has_flashlight" in player) and player.has_flashlight:
		print("🔦 Jugador ya tiene linterna, no se mostrará el diálogo.")
		# Si ya tiene linterna, este diálogo no tiene sentido -> marcar como hecho
		GameData.buscar_linterna_done = true
		return

	# ✅ Marcar desde ya para evitar duplicados durante el await
	ya_mostro_dialogo_luz = true
	GameData.buscar_linterna_done = true

	await get_tree().create_timer(6.0).timeout

	# Rechequear por si la recogió durante la espera
	player = get_tree().get_current_scene().get_node_or_null("Player")
	if player and ("has_flashlight" in player) and player.has_flashlight:
		print("🔦 Durante la espera, el jugador recogió la linterna. No se mostrará el diálogo.")
		return

	print("💡 Mostrando diálogo 'necesita_luz' (Buscar_linterna).")

	var resource_path := "res://Dialogos/Buscar_linterna.dialogue"
	if not ResourceLoader.exists(resource_path):
		push_error("[Carro] No existe: " + resource_path)
		return

	var dialogue_res := load(resource_path)
	if dialogue_res == null:
		push_error("[Carro] No se pudo cargar: " + resource_path)
		return

	var balloon_scene := preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon)

	if balloon.has_method("start"):
		balloon.start(dialogue_res, "necesita_luz")

	print("✅ Diálogo 'necesita_luz' iniciado.")


func mostrar_dialogo_fuego(etiqueta: String) -> void:
	var balloon_scene := preload("res://Pantallas/Dialogos_ecenas/balloon.tscn")
	var balloon = balloon_scene.instantiate()
	get_tree().get_current_scene().add_child(balloon)

	var resource := load("res://Dialogos/Int_fuego.dialogue")
	if resource and balloon.has_method("start"):
		balloon.start(resource, etiqueta)


func open_door() -> void:
	canInteract = false
	isOpen = true
	if animation_player:
		animation_player.play("Puertas_carro")


func close_door() -> void:
	canInteract = false
	isOpen = false
	if animation_player:
		animation_player.play("Close_van")


func _on_animation_finished(_anim_name: StringName) -> void:
	canInteract = true
