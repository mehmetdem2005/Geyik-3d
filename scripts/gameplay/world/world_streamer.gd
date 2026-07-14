class_name WorldStreamer
extends Node3D

@export var world_seed := 684221
@export var chunk_size := 72.0
@export_range(1, 4, 1) var active_radius := 2
@export var water_level := -0.8
@export var river_half_width := 9.0

var _player: Node3D
var _active_chunks: Dictionary = {}
var _generation_queue: Array[Vector2i] = []
var _current_center := Vector2i(999999, 999999)
var _continental_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _biome_noise := FastNoiseLite.new()
var _ground_material: StandardMaterial3D
var _water_material: Material
var _tree_mesh: ArrayMesh
var _rock_mesh: Mesh
var _grass_mesh: ArrayMesh
var _bridge_deck_y := 1.0
var _refresh_accumulator := 0.0


func _ready() -> void:
	add_to_group(&"world_streamer")
	_configure_noise()
	_build_shared_assets()
	_bridge_deck_y = maxf(_sample_base_height(-river_half_width - 4.0, 0.0), _sample_base_height(river_half_width + 4.0, 0.0)) + 0.7
	_build_bridge_landmark()
	_build_outpost()
	EventBus.player_spawned.connect(set_player)


func set_player(player: Node) -> void:
	_player = player as Node3D
	_refresh_streaming(true)
	# The analytical terrain is available immediately, but the collision and
	# visual mesh are streamed. Build the player's current chunk before the first
	# playable frame so a slow phone can never reveal the sky below the terrain.
	if _active_chunks.is_empty() and not _generation_queue.is_empty():
		_generate_next_chunk()


func _process(delta: float) -> void:
	if _player == null:
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= 0.35:
		_refresh_accumulator = 0.0
		_refresh_streaming(false)
	if not _generation_queue.is_empty():
		_generate_next_chunk()


func sample_height(world_x: float, world_z: float) -> float:
	var base := _sample_base_height(world_x, world_z)
	var river_distance := distance_to_river(world_x, world_z)
	var river_blend := smoothstep(river_half_width, river_half_width + 10.0, river_distance)
	return lerpf(water_level - 2.8, base, river_blend)


func sample_ground_color(world_x: float, world_z: float, height: float) -> Color:
	var river_distance := distance_to_river(world_x, world_z)
	if river_distance < river_half_width + 2.0:
		return Color("#8f8068")
	var biome := _biome_noise.get_noise_2d(world_x, world_z)
	if height > 8.0:
		return Color("#898b83")
	if biome > 0.22:
		return Color("#748b6d")
	return Color("#657d60")


func river_center_x(world_z: float) -> float:
	return sin(world_z * 0.0062) * 24.0 + sin(world_z * 0.0017) * 34.0


func distance_to_river(world_x: float, world_z: float) -> float:
	return absf(world_x - river_center_x(world_z))


func is_swimmable_position(world_position: Vector3) -> bool:
	return distance_to_river(world_position.x, world_position.z) < river_half_width - 0.6 and world_position.y < water_level + 0.55


func is_water_xz(world_x: float, world_z: float) -> bool:
	return distance_to_river(world_x, world_z) < river_half_width


func get_water_level() -> float:
	return water_level


func is_landmark_clearance(point: Vector2) -> bool:
	return (
		point.distance_to(Vector2(river_center_x(0.0), 0.0)) < 34.0
		or point.distance_to(Vector2(42.0, 18.0)) < 18.0
		or point.distance_to(Vector2(50.0, 6.0)) < 24.0
	)


func seed_for_chunk(coordinate: Vector2i) -> int:
	return int(world_seed) ^ (coordinate.x * 73856093) ^ (coordinate.y * 19349663)


func get_ground_material() -> StandardMaterial3D:
	return _ground_material


func get_water_material() -> Material:
	return _water_material


func get_tree_mesh() -> ArrayMesh:
	return _tree_mesh


func get_rock_mesh() -> Mesh:
	return _rock_mesh


func get_grass_mesh() -> ArrayMesh:
	return _grass_mesh


func _sample_base_height(world_x: float, world_z: float) -> float:
	var continental := _continental_noise.get_noise_2d(world_x, world_z) * 10.5
	var detail := _detail_noise.get_noise_2d(world_x, world_z) * 2.2
	return continental + detail + 1.8


func _configure_noise() -> void:
	_continental_noise.seed = world_seed
	_continental_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continental_noise.frequency = 0.0038
	_continental_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continental_noise.fractal_octaves = 4
	_continental_noise.fractal_gain = 0.5
	_detail_noise.seed = world_seed + 71
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.018
	_detail_noise.fractal_octaves = 2
	_biome_noise.seed = world_seed + 313
	_biome_noise.frequency = 0.0025


func _refresh_streaming(force: bool) -> void:
	var center := Vector2i(floori(_player.global_position.x / chunk_size), floori(_player.global_position.z / chunk_size))
	if not force and center == _current_center:
		return
	_current_center = center
	var desired: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for z_offset in range(-active_radius, active_radius + 1):
		for x_offset in range(-active_radius, active_radius + 1):
			var coordinate := center + Vector2i(x_offset, z_offset)
			desired[coordinate] = true
			if not _active_chunks.has(coordinate) and not _generation_queue.has(coordinate):
				candidates.append(coordinate)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	_generation_queue.append_array(candidates)
	for coordinate: Vector2i in _active_chunks.keys():
		if not desired.has(coordinate):
			var chunk: Node = _active_chunks[coordinate]
			_active_chunks.erase(coordinate)
			chunk.queue_free()
	_generation_queue = _generation_queue.filter(func(coordinate: Vector2i) -> bool: return desired.has(coordinate))


func _generate_next_chunk() -> void:
	var coordinate: Vector2i = _generation_queue.pop_front()
	if _active_chunks.has(coordinate):
		return
	var distance: float = coordinate.distance_squared_to(_current_center)
	var resolution := 28 if distance <= 2.0 else (18 if distance <= 8.0 else 12)
	var chunk := WorldChunk.new()
	_active_chunks[coordinate] = chunk
	add_child(chunk)
	chunk.configure(self, coordinate, resolution)


func _build_shared_assets() -> void:
	_ground_material = StandardMaterial3D.new()
	_ground_material.vertex_color_use_as_albedo = true
	_ground_material.albedo_texture = load("res://assets/textures/forest_ground_04/forest_ground_04_diff_1k.jpg")
	_ground_material.normal_enabled = true
	_ground_material.normal_texture = load("res://assets/textures/forest_ground_04/forest_ground_04_nor_gl_1k.jpg")
	_ground_material.normal_scale = 0.72
	_ground_material.roughness = 0.96
	_ground_material.roughness_texture = load("res://assets/textures/forest_ground_04/forest_ground_04_rough_1k.jpg")
	_ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_ground_material.cull_mode = BaseMaterial3D.CULL_BACK
	var water_shader_material := ShaderMaterial.new()
	water_shader_material.shader = load("res://assets/shaders/water.gdshader")
	_water_material = water_shader_material
	_tree_mesh = _create_tree_mesh()
	_grass_mesh = _create_grass_mesh()
	_rock_mesh = _load_combined_model_mesh("res://assets/models/rock_moss_set_01/rock_moss_set_01_1k.gltf")
	if _rock_mesh == null:
		var fallback_rock := SphereMesh.new()
		fallback_rock.radius = 0.9
		fallback_rock.height = 1.35
		fallback_rock.radial_segments = 14
		fallback_rock.rings = 8
		var rock_material := StandardMaterial3D.new()
		rock_material.albedo_color = Color("#73796f")
		rock_material.roughness = 0.95
		fallback_rock.material = rock_material
		_rock_mesh = fallback_rock


func _create_tree_mesh() -> ArrayMesh:
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_texture = load("res://assets/textures/pine_tree_01/pine_tree_01_bark_diff_1k.jpg")
	trunk_material.normal_enabled = true
	trunk_material.normal_texture = load("res://assets/textures/pine_tree_01/pine_tree_01_bark_nor_gl_1k.jpg")
	trunk_material.normal_scale = 0.72
	trunk_material.roughness = 0.92
	var bark_arm: Texture2D = load("res://assets/textures/pine_tree_01/pine_tree_01_bark_arm_1k.jpg")
	trunk_material.roughness_texture = bark_arm
	trunk_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	trunk_material.ao_enabled = true
	trunk_material.ao_texture = bark_arm
	trunk_material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var foliage_material := ShaderMaterial.new()
	foliage_material.shader = load("res://assets/shaders/pine_card.gdshader")
	foliage_material.set_shader_parameter(&"albedo_texture", load("res://assets/textures/pine_tree_01/pine_tree_01_branch_rgba_1k.png"))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.24
	trunk.bottom_radius = 0.46
	trunk.height = 6.2
	trunk.radial_segments = 12
	trunk.rings = 4
	trunk.material = trunk_material
	var foliage_card := QuadMesh.new()
	foliage_card.size = Vector2.ONE
	foliage_card.material = foliage_material
	var result := ArrayMesh.new()
	var trunk_surface := SurfaceTool.new()
	trunk_surface.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3.UP * 3.1))
	trunk_surface.set_material(trunk_material)
	trunk_surface.commit(result)
	var foliage_surface := SurfaceTool.new()
	var tiers: Array[Vector3] = [
		Vector3(3.65, 4.4, 1.55),
		Vector3(4.65, 4.05, 1.5),
		Vector3(5.6, 3.65, 1.42),
		Vector3(6.5, 3.2, 1.34),
		Vector3(7.3, 2.65, 1.22),
		Vector3(8.0, 2.05, 1.08),
		Vector3(8.58, 1.35, 0.94),
	]
	for tier: Vector3 in tiers:
		for plane_index in 4:
			var angle := float(plane_index) * PI / 4.0
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(tier.y, tier.z, 1.0))
			foliage_surface.append_from(foliage_card, 0, Transform3D(basis, Vector3(0.0, tier.x, 0.0)))
	foliage_surface.set_material(foliage_material)
	foliage_surface.commit(result)
	return result


func _load_combined_model_mesh(path: String) -> ArrayMesh:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var result := ArrayMesh.new()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var surface := SurfaceTool.new()
			surface.append_from(mesh_instance.mesh, surface_index, mesh_instance.transform)
			surface.set_material(mesh_instance.mesh.surface_get_material(surface_index))
			surface.commit(result)
	root.free()
	return result if result.get_surface_count() > 0 else null


func _create_grass_mesh() -> ArrayMesh:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/grass.gdshader")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI * 0.5]:
		var basis := Basis(Vector3.UP, angle)
		var points := [
			Vector3(-0.11, 0.0, 0.0), Vector3(0.11, 0.0, 0.0),
			Vector3(-0.065, 0.48, 0.0), Vector3(0.065, 0.48, 0.0),
			Vector3(0.0, 0.82, 0.0),
		]
		var triangle_indices := [0, 1, 2, 1, 3, 2, 2, 3, 4]
		for point_index in triangle_indices:
			var point: Vector3 = points[point_index]
			surface.set_normal(basis * Vector3.FORWARD)
			surface.set_uv(Vector2(point.x / 0.22 + 0.5, point.y / 0.82))
			surface.add_vertex(basis * point)
	surface.set_material(material)
	return surface.commit()


func _build_bridge_landmark() -> void:
	var bridge := Node3D.new()
	bridge.name = "KoprucayBridge"
	bridge.position = Vector3(river_center_x(0.0), _bridge_deck_y, 0.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#5b3c24")
	wood.roughness = 0.86
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color("#352619")
	dark_wood.roughness = 0.92
	_add_bridge_box(bridge, "Deck", Vector3(30.0, 0.45, 8.0), Vector3(0.0, 0.0, 0.0), wood, true)
	for x in range(-14, 15, 2):
		_add_bridge_box(bridge, "Plank_%s" % x, Vector3(1.78, 0.08, 7.8), Vector3(x, 0.265, 0.0), wood, false)
		if x % 4 == 0:
			_add_bridge_box(bridge, "PostL_%s" % x, Vector3(0.22, 1.55, 0.22), Vector3(x, 0.78, -3.65), dark_wood, false)
			_add_bridge_box(bridge, "PostR_%s" % x, Vector3(0.22, 1.55, 0.22), Vector3(x, 0.78, 3.65), dark_wood, false)
	_add_bridge_box(bridge, "RailL", Vector3(29.0, 0.22, 0.22), Vector3(0.0, 1.35, -3.65), dark_wood, true)
	_add_bridge_box(bridge, "RailR", Vector3(29.0, 0.22, 0.22), Vector3(0.0, 1.35, 3.65), dark_wood, true)
	add_child(bridge)


func _add_bridge_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material, collision_enabled: bool) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	visual.position = local_position
	parent.add_child(visual)
	if collision_enabled:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = local_position
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)


func _build_outpost() -> void:
	var outpost := OutpostTerminal.new()
	outpost.name = "ForestOutpost"
	var x := 42.0
	var z := 18.0
	outpost.position = Vector3(x, sample_height(x, z), z)
	add_child(outpost)
