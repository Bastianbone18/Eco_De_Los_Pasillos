extends Node3D

# =========================
# REFERENCIAS
# =========================
@export var tree_scene: PackedScene              # Tree_A.tscn
@export var terreno_path: NodePath               # TerrenoJugable (MeshInstance3D)
@export var trees_parent_path: NodePath          # Trees (Node3D, scale 1,1,1)

# =========================
# DENSIDAD / TAMAÑO
# =========================
@export var tree_count: int = 800
@export var min_distance: float = 3.2
@export var min_scale: float = 0.22
@export var max_scale: float = 0.40

# =========================
# RAYCAST
# =========================
@export var ray_start_height: float = 250.0
@export var ray_length: float = 800.0
@export var use_collision_mask: bool = false
@export var collision_mask: int = 1

# =========================
# SEED (EDITABLE)
# =========================
@export var use_fixed_seed: bool = true
@export var fixed_seed: int = 1337

# =========================
# BAKE (FIJO EN DISCO)
# =========================
@export var use_baked_layout: bool = true
@export var baked_file_path: String = "user://forest_layout.json"
@export var bake_now: bool = false   # activar UNA VEZ

# =========================
# INTERNOS
# =========================
var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector3] = []
var _layout: Array = []   # [{pos:[x,y,z], rot:float, scale:float}]

# =========================
# READY
# =========================
func _ready() -> void:
	var trees_parent := get_node_or_null(trees_parent_path) as Node3D
	if trees_parent == null:
		push_error("[ForestSpawner] trees_parent_path inválido.")
		return

	# 1) Cargar bake si existe
	if use_baked_layout and FileAccess.file_exists(baked_file_path) and not bake_now:
		_clear_children(trees_parent)
		_load_layout(trees_parent)
		return

	# 2) Preparar RNG
	if use_fixed_seed:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()

	# 3) Generar
	_clear_children(trees_parent)
	_generate_layout_and_spawn(trees_parent)

	# 4) Guardar bake si se pidió
	if bake_now and use_baked_layout:
		_save_layout()
		bake_now = false
		print("[ForestSpawner] Bake realizado. bake_now vuelto a false.")

# =========================
# GENERACIÓN
# =========================
func _generate_layout_and_spawn(trees_parent: Node3D) -> void:
	_layout.clear()
	_placed.clear()

	var terreno := get_node_or_null(terreno_path) as MeshInstance3D
	if terreno == null or terreno.mesh == null:
		push_error("[ForestSpawner] terreno_path inválido.")
		return

	var aabb: AABB = terreno.mesh.get_aabb()
	var minp: Vector3 = aabb.position
	var maxp: Vector3 = aabb.position + aabb.size

	for i in range(tree_count):
		var tries := 0
		while tries < 30:
			tries += 1

			var lx: float = _rng.randf_range(minp.x, maxp.x)
			var lz: float = _rng.randf_range(minp.z, maxp.z)
			var global_xz: Vector3 = terreno.to_global(Vector3(lx, 0.0, lz))

			var hit_pos := _raycast_to_ground(global_xz)
			if hit_pos == Vector3.INF:
				continue

			if not _valid_min_distance(hit_pos):
				continue

			var rot_y: float = _rng.randf_range(0.0, TAU)
			var s: float = _rng.randf_range(min_scale, max_scale)

			_layout.append({
				"pos": [hit_pos.x, hit_pos.y, hit_pos.z],
				"rot": rot_y,
				"scale": s
			})

			_spawn_one(trees_parent, hit_pos, rot_y, s)
			_placed.append(hit_pos)
			break

	print("[ForestSpawner] Árboles generados:", _layout.size())

func _spawn_one(parent: Node3D, pos: Vector3, rot_y: float, s: float) -> void:
	var tree := tree_scene.instantiate()
	parent.add_child(tree)
	tree.global_position = pos
	tree.global_rotation = Vector3(0.0, rot_y, 0.0)
	tree.scale = Vector3.ONE * s

# =========================
# RAYCAST
# =========================
func _raycast_to_ground(global_xz: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state

	var from := global_xz + Vector3(0.0, ray_start_height, 0.0)
	var to := from - Vector3(0.0, ray_length, 0.0)

	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	if use_collision_mask:
		params.collision_mask = collision_mask

	var result := space.intersect_ray(params)
	if result.is_empty():
		return Vector3.INF

	return result["position"] as Vector3

# =========================
# DISTANCIA
# =========================
func _valid_min_distance(p: Vector3) -> bool:
	var min_d2 := min_distance * min_distance
	for q in _placed:
		var dx := p.x - q.x
		var dz := p.z - q.z
		if (dx * dx + dz * dz) < min_d2:
			return false
	return true

# =========================
# BAKE SAVE / LOAD
# =========================
func _save_layout() -> void:
	var data := {
		"seed": fixed_seed,
		"tree_count": tree_count,
		"min_distance": min_distance,
		"min_scale": min_scale,
		"max_scale": max_scale,
		"layout": _layout
	}

	var f := FileAccess.open(baked_file_path, FileAccess.WRITE)
	if f == null:
		push_error("[ForestSpawner] No se pudo guardar bake.")
		return
	f.store_string(JSON.stringify(data))
	f.close()

	print("[ForestSpawner] Layout guardado en:", baked_file_path)

func _load_layout(trees_parent: Node3D) -> void:
	var f := FileAccess.open(baked_file_path, FileAccess.READ)
	if f == null:
		push_error("[ForestSpawner] No se pudo leer bake.")
		return

	var parsed: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	var loaded_layout: Array = parsed.get("layout", [])

	for item in loaded_layout:
		var pos_arr: Array = item["pos"]
		var pos := Vector3(
			float(pos_arr[0]),
			float(pos_arr[1]),
			float(pos_arr[2])
		)
		var rot_y: float = float(item["rot"])
		var s: float = float(item["scale"])
		_spawn_one(trees_parent, pos, rot_y, s)

	print("[ForestSpawner] Layout cargado:", loaded_layout.size())

# =========================
# UTIL
# =========================
func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
