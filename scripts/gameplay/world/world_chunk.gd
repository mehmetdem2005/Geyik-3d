class_name WorldChunk
extends Node3D

var coordinate := Vector2i.ZERO
var _world: WorldStreamer
var _resolution := 14


func configure(world: WorldStreamer, chunk_coordinate: Vector2i, resolution: int) -> void:
	_world = world
	coordinate = chunk_coordinate
	_resolution = resolution
	name = "Chunk_%s_%s" % [coordinate.x, coordinate.y]
	position = Vector3(coordinate.x * _world.chunk_size, 0.0, coordinate.y * _world.chunk_size)
	_build_ground()
	_build_water_strip()
	_build_vegetation()


func _build_ground() -> void:
	var side := _resolution + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	colors.resize(side * side)
	uvs.resize(side * side)
	var step := _world.chunk_size / float(_resolution)
	for z_index in side:
		for x_index in side:
			var local_x := x_index * step
			var local_z := z_index * step
			var world_x := position.x + local_x
			var world_z := position.z + local_z
			var height := _world.sample_height(world_x, world_z)
			var vertex_index := z_index * side + x_index
			vertices[vertex_index] = Vector3(local_x, height, local_z)
			uvs[vertex_index] = Vector2(world_x, world_z) * 0.035
			colors[vertex_index] = _world.sample_ground_color(world_x, world_z, height)
	for z_index in _resolution:
		for x_index in _resolution:
			var top_left := z_index * side + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + side
			var bottom_right := bottom_left + 1
			indices.append_array(PackedInt32Array([top_left, bottom_left, top_right, top_right, bottom_left, bottom_right]))
	_accumulate_normals(vertices, indices, normals)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _world.get_ground_material())
	var ground_visual := MeshInstance3D.new()
	ground_visual.name = "GroundVisual"
	ground_visual.mesh = mesh
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground_visual)

	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index in indices.size():
		faces[index] = vertices[indices[index]]
	var ground_shape := ConcavePolygonShape3D.new()
	ground_shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = ground_shape
	body.add_child(collision)
	add_child(body)


func _accumulate_normals(vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array) -> void:
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
		normals[a] = normals[a] + normal
		normals[b] = normals[b] + normal
		normals[c] = normals[c] + normal
	for index in normals.size():
		normals[index] = normals[index].normalized()


func _build_water_strip() -> void:
	var segments := 8
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in segments + 1:
		var local_z := _world.chunk_size * float(segment) / segments
		var world_z := position.z + local_z
		var center_x := _world.river_center_x(world_z) - position.x
		for side_index in 2:
			var side_sign := -1.0 if side_index == 0 else 1.0
			vertices.append(Vector3(center_x + side_sign * _world.river_half_width, _world.water_level, local_z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(side_index), world_z * 0.025))
	if not _river_intersects_chunk(vertices):
		return
	for segment in segments:
		var base := segment * 2
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _world.get_water_material())
	var water := MeshInstance3D.new()
	water.name = "RiverWater"
	water.mesh = mesh
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _river_intersects_chunk(vertices: PackedVector3Array) -> bool:
	for vertex in vertices:
		if vertex.x >= -_world.river_half_width and vertex.x <= _world.chunk_size + _world.river_half_width:
			return true
	return false


func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world.seed_for_chunk(coordinate)
	var quality := int(SettingsService.get_value(&"vegetation_quality", 1))
	var tree_budget := 28 + quality * 14
	var rock_budget := 7 + quality * 3
	var tree_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	for index in tree_budget:
		var local_position := Vector3(rng.randf_range(2.0, _world.chunk_size - 2.0), 0.0, rng.randf_range(2.0, _world.chunk_size - 2.0))
		var world_x := position.x + local_position.x
		var world_z := position.z + local_position.z
		if _world.distance_to_river(world_x, world_z) < _world.river_half_width + 5.0:
			continue
		if _world.is_landmark_clearance(Vector2(world_x, world_z)):
			continue
		local_position.y = _world.sample_height(world_x, world_z)
		var scale := rng.randf_range(0.72, 1.28)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale)
		tree_transforms.append(Transform3D(basis, local_position))
	for index in rock_budget:
		var local_position := Vector3(rng.randf_range(1.0, _world.chunk_size - 1.0), 0.0, rng.randf_range(1.0, _world.chunk_size - 1.0))
		var world_x := position.x + local_position.x
		var world_z := position.z + local_position.z
		if _world.distance_to_river(world_x, world_z) < _world.river_half_width + 2.0:
			continue
		local_position.y = _world.sample_height(world_x, world_z) + 0.35
		var scale := rng.randf_range(0.5, 1.45)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.65, 1.0), scale))
		rock_transforms.append(Transform3D(basis, local_position))
	_add_multimesh("Trees", _world.get_tree_mesh(), tree_transforms, 260.0)
	_add_multimesh("Rocks", _world.get_rock_mesh(), rock_transforms, 210.0)
	_add_tree_collisions(tree_transforms)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], range_end: float) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.visibility_range_end = range_end
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(instance)


func _add_tree_collisions(tree_transforms: Array[Transform3D]) -> void:
	if tree_transforms.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "TreeCollisionCluster"
	body.collision_layer = 1
	body.collision_mask = 0
	var collider_count := mini(8, tree_transforms.size())
	for index in collider_count:
		var source := tree_transforms[index]
		var shape := CylinderShape3D.new()
		shape.radius = 0.42 * source.basis.get_scale().x
		shape.height = 5.0 * source.basis.get_scale().y
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = source.origin + Vector3.UP * shape.height * 0.5
		body.add_child(collision)
	add_child(body)

