class_name AnimalVisual
extends Node3D

var legs: Array[Node3D] = []
var head: Node3D
var body: Node3D
var _walk_phase := 0.0
var _downed_amount := 0.0


func build(definition: AnimalDefinition) -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = definition.body_color
	body_material.roughness = 0.92
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = definition.body_color.darkened(0.52)
	dark_material.roughness = 0.96
	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = Color("#d7cab0")
	accent_material.roughness = 0.88

	match definition.species_id:
		&"bear":
			_build_bear(body_material, dark_material)
		&"wolf":
			_build_wolf(body_material, dark_material)
		_:
			_build_deer(body_material, dark_material, accent_material)


func animate_motion(speed: float, delta: float, downed: bool) -> void:
	if downed:
		_downed_amount = minf(1.0, _downed_amount + delta * 2.4)
		rotation.z = lerp_angle(rotation.z, deg_to_rad(88.0), _downed_amount)
		return
	if speed > 0.1:
		_walk_phase += delta * (3.2 + speed * 1.15)
		var swing := sin(_walk_phase) * minf(0.72, 0.18 + speed * 0.055)
		if legs.size() >= 4:
			legs[0].rotation.x = swing
			legs[1].rotation.x = -swing
			legs[2].rotation.x = -swing
			legs[3].rotation.x = swing
		if body != null:
			body.position.y = sin(_walk_phase * 2.0) * 0.035
	elif head != null:
		head.rotation.x = lerpf(head.rotation.x, sin(Time.get_ticks_msec() * 0.0013) * 0.08, delta * 2.0)
		for leg in legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, delta * 6.0)


func _build_deer(main: Material, dark: Material, horn: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_box(body, Vector3(0.92, 0.96, 2.25), Vector3(0.0, 1.48, 0.0), main)
	_add_box(body, Vector3(0.44, 1.25, 0.48), Vector3(0.0, 2.0, -0.82), main, Vector3(deg_to_rad(-18.0), 0.0, 0.0))
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 2.55, -1.2)
	body.add_child(head)
	_add_box(head, Vector3(0.52, 0.52, 0.82), Vector3.ZERO, main)
	_add_box(head, Vector3(0.34, 0.3, 0.5), Vector3(0.0, -0.08, -0.55), dark)
	_add_box(head, Vector3(0.38, 0.12, 0.24), Vector3(0.4, 0.14, -0.02), main, Vector3(0.0, 0.0, deg_to_rad(18.0)))
	_add_box(head, Vector3(0.38, 0.12, 0.24), Vector3(-0.4, 0.14, -0.02), main, Vector3(0.0, 0.0, deg_to_rad(-18.0)))
	_add_antler(head, 1.0, horn)
	_add_antler(head, -1.0, horn)
	_build_legs(body, 1.28, 0.18, dark, 0.33, 0.78)


func _build_wolf(main: Material, dark: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_box(body, Vector3(0.72, 0.78, 1.85), Vector3(0.0, 1.02, 0.0), main)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.3, -1.0)
	body.add_child(head)
	_add_box(head, Vector3(0.58, 0.52, 0.7), Vector3.ZERO, main)
	_add_box(head, Vector3(0.32, 0.3, 0.58), Vector3(0.0, -0.08, -0.53), dark)
	_add_cone(head, 0.15, 0.45, Vector3(0.2, 0.43, -0.05), dark)
	_add_cone(head, 0.15, 0.45, Vector3(-0.2, 0.43, -0.05), dark)
	_add_box(body, Vector3(0.25, 0.25, 1.05), Vector3(0.0, 1.1, 1.35), main, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_build_legs(body, 0.9, 0.17, dark, 0.25, 0.62)


func _build_bear(main: Material, dark: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_box(body, Vector3(1.75, 1.55, 2.65), Vector3(0.0, 1.28, 0.0), main)
	_add_box(body, Vector3(1.55, 0.6, 1.3), Vector3(0.0, 2.05, -0.45), main)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.65, -1.55)
	body.add_child(head)
	_add_box(head, Vector3(1.05, 0.9, 1.0), Vector3.ZERO, main)
	_add_box(head, Vector3(0.65, 0.48, 0.64), Vector3(0.0, -0.18, -0.68), dark)
	_add_sphere(head, 0.24, Vector3(0.42, 0.5, -0.05), dark)
	_add_sphere(head, 0.24, Vector3(-0.42, 0.5, -0.05), dark)
	_build_legs(body, 1.0, 0.42, dark, 0.58, 0.82)


func _build_legs(parent: Node3D, height: float, width: float, material: Material, x_offset: float, z_offset: float) -> void:
	var placements := [
		Vector3(-x_offset, height * 0.5, -z_offset),
		Vector3(x_offset, height * 0.5, -z_offset),
		Vector3(-x_offset, height * 0.5, z_offset),
		Vector3(x_offset, height * 0.5, z_offset),
	]
	for placement in placements:
		var pivot := Node3D.new()
		pivot.position = placement + Vector3.UP * height * 0.5
		parent.add_child(pivot)
		_add_box(pivot, Vector3(width, height, width), Vector3(0.0, -height * 0.5, 0.0), material)
		legs.append(pivot)


func _add_antler(parent: Node3D, side: float, material: Material) -> void:
	var root := Vector3(0.19 * side, 0.32, 0.02)
	_add_box(parent, Vector3(0.09, 0.86, 0.09), root + Vector3(0.12 * side, 0.35, 0.0), material, Vector3(0.0, 0.0, deg_to_rad(-18.0 * side)))
	_add_box(parent, Vector3(0.08, 0.5, 0.08), root + Vector3(0.32 * side, 0.62, -0.12), material, Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(-30.0 * side)))
	_add_box(parent, Vector3(0.08, 0.42, 0.08), root + Vector3(0.38 * side, 0.78, 0.17), material, Vector3(deg_to_rad(-32.0), 0.0, deg_to_rad(-25.0 * side)))


func _add_box(parent: Node3D, size: Vector3, local_position: Vector3, material: Material, local_rotation := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation = local_rotation
	parent.add_child(instance)


func _add_cone(parent: Node3D, radius: float, height: float, local_position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 5
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	parent.add_child(instance)


func _add_sphere(parent: Node3D, radius: float, local_position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	parent.add_child(instance)

