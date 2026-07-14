class_name AnimalVisual
extends Node3D

const FUR_SHADER: Shader = preload("res://assets/shaders/fur.gdshader")

var legs: Array[Node3D] = []
var head: Node3D
var body: Node3D
var _walk_phase := 0.0
var _downed_amount := 0.0


func build(definition: AnimalDefinition) -> void:
	var body_material := _fur_material(definition.body_color, definition.body_color.darkened(0.48))
	var dark_material := _fur_material(definition.body_color.darkened(0.42), definition.body_color.darkened(0.68))
	var horn_material := _standard_material(Color("#c9b991"), 0.86)
	var eye_material := _standard_material(Color("#080706"), 0.22)

	match definition.species_id:
		&"bear":
			_build_bear(body_material, dark_material, eye_material)
		&"wolf":
			_build_wolf(body_material, dark_material, eye_material)
		_:
			_build_deer(body_material, dark_material, horn_material, eye_material)


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
		head.rotation.x = lerpf(head.rotation.x, sin(Time.get_ticks_msec() * 0.0013) * 0.055, delta * 2.0)
		for leg in legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, delta * 6.0)


func _build_deer(main: Material, dark: Material, horn: Material, eye: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_ellipsoid(body, "Torso", Vector3(1.04, 1.08, 2.35), Vector3(0.0, 1.62, 0.05), main)
	_add_ellipsoid(body, "Chest", Vector3(1.10, 1.22, 1.18), Vector3(0.0, 1.72, -0.64), main)
	_add_tapered(body, "Neck", 0.21, 0.29, 1.34, Vector3(0.0, 2.22, -0.92), Vector3(deg_to_rad(-24.0), 0.0, 0.0), main)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 2.92, -1.27)
	body.add_child(head)
	_add_ellipsoid(head, "Skull", Vector3(0.55, 0.58, 0.86), Vector3.ZERO, main)
	_add_ellipsoid(head, "Muzzle", Vector3(0.39, 0.31, 0.55), Vector3(0.0, -0.11, -0.54), dark)
	_add_ellipsoid(head, "Nose", Vector3(0.29, 0.18, 0.19), Vector3(0.0, -0.12, -0.82), eye, Vector3.ZERO, 12, 6)
	_add_ellipsoid(head, "EarL", Vector3(0.46, 0.17, 0.29), Vector3(0.38, 0.24, 0.03), main, Vector3(0.0, deg_to_rad(-8.0), deg_to_rad(24.0)), 12, 6)
	_add_ellipsoid(head, "EarR", Vector3(0.46, 0.17, 0.29), Vector3(-0.38, 0.24, 0.03), main, Vector3(0.0, deg_to_rad(8.0), deg_to_rad(-24.0)), 12, 6)
	_add_eye_pair(head, Vector3(0.215, 0.08, -0.34), 0.045, eye)
	_add_antler(head, 1.0, horn)
	_add_antler(head, -1.0, horn)
	_add_ellipsoid(body, "Tail", Vector3(0.27, 0.38, 0.52), Vector3(0.0, 1.78, 1.21), dark, Vector3(deg_to_rad(-26.0), 0.0, 0.0), 12, 6)
	_build_legs(body, 1.32, 0.105, 0.075, dark, 0.34, 0.78, 1.33)


func _build_wolf(main: Material, dark: Material, eye: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_ellipsoid(body, "Torso", Vector3(0.78, 0.82, 1.95), Vector3(0.0, 1.02, 0.05), main)
	_add_ellipsoid(body, "Chest", Vector3(0.86, 1.02, 0.92), Vector3(0.0, 1.10, -0.61), main)
	_add_tapered(body, "Neck", 0.25, 0.33, 0.72, Vector3(0.0, 1.40, -0.72), Vector3(deg_to_rad(-38.0), 0.0, 0.0), main)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.58, -1.06)
	body.add_child(head)
	_add_ellipsoid(head, "Skull", Vector3(0.61, 0.56, 0.72), Vector3.ZERO, main)
	_add_tapered(head, "Muzzle", 0.11, 0.18, 0.58, Vector3(0.0, -0.10, -0.50), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark)
	_add_ellipsoid(head, "Nose", Vector3(0.24, 0.18, 0.18), Vector3(0.0, -0.10, -0.80), eye, Vector3.ZERO, 12, 6)
	_add_cone(head, "EarL", 0.16, 0.47, Vector3(0.22, 0.42, 0.02), dark, Vector3(0.0, 0.0, deg_to_rad(-8.0)))
	_add_cone(head, "EarR", 0.16, 0.47, Vector3(-0.22, 0.42, 0.02), dark, Vector3(0.0, 0.0, deg_to_rad(8.0)))
	_add_eye_pair(head, Vector3(0.20, 0.07, -0.31), 0.04, eye)
	_add_cylinder_between(body, "Tail", Vector3(0.0, 1.15, 0.88), Vector3(0.0, 0.83, 1.78), 0.13, main, 14)
	_add_ellipsoid(body, "TailTip", Vector3(0.29, 0.29, 0.47), Vector3(0.0, 0.77, 1.86), dark, Vector3(deg_to_rad(-22.0), 0.0, 0.0), 12, 6)
	_build_legs(body, 0.86, 0.10, 0.075, dark, 0.26, 0.62, 0.94)


func _build_bear(main: Material, dark: Material, eye: Material) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_add_ellipsoid(body, "Torso", Vector3(1.82, 1.62, 2.70), Vector3(0.0, 1.42, 0.08), main)
	_add_ellipsoid(body, "ShoulderHump", Vector3(1.72, 1.36, 1.52), Vector3(0.0, 1.92, -0.54), main)
	_add_tapered(body, "Neck", 0.48, 0.62, 0.82, Vector3(0.0, 1.72, -1.02), Vector3(deg_to_rad(-58.0), 0.0, 0.0), main)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.76, -1.61)
	body.add_child(head)
	_add_ellipsoid(head, "Skull", Vector3(1.08, 0.98, 1.10), Vector3.ZERO, main)
	_add_ellipsoid(head, "Muzzle", Vector3(0.72, 0.52, 0.72), Vector3(0.0, -0.18, -0.65), dark)
	_add_ellipsoid(head, "Nose", Vector3(0.48, 0.27, 0.21), Vector3(0.0, -0.13, -1.0), eye, Vector3.ZERO, 14, 7)
	_add_ellipsoid(head, "EarL", Vector3(0.34, 0.39, 0.22), Vector3(0.43, 0.52, -0.02), dark, Vector3.ZERO, 12, 6)
	_add_ellipsoid(head, "EarR", Vector3(0.34, 0.39, 0.22), Vector3(-0.43, 0.52, -0.02), dark, Vector3.ZERO, 12, 6)
	_add_eye_pair(head, Vector3(0.31, 0.10, -0.48), 0.052, eye)
	_build_legs(body, 1.0, 0.27, 0.22, dark, 0.58, 0.82, 1.17)


func _build_legs(parent: Node3D, total_height: float, upper_radius: float, lower_radius: float, material: Material, x_offset: float, z_offset: float, hip_height: float) -> void:
	var placements := [
		Vector3(-x_offset, hip_height, -z_offset),
		Vector3(x_offset, hip_height, -z_offset),
		Vector3(-x_offset, hip_height, z_offset),
		Vector3(x_offset, hip_height, z_offset),
	]
	var upper_height := total_height * 0.53
	var lower_height := total_height * 0.47
	for index in placements.size():
		var pivot := Node3D.new()
		pivot.name = "Leg_%s" % index
		pivot.position = placements[index]
		parent.add_child(pivot)
		_add_tapered(pivot, "Upper", lower_radius * 1.12, upper_radius, upper_height, Vector3(0.0, -upper_height * 0.5, 0.0), Vector3.ZERO, material)
		_add_tapered(pivot, "Lower", lower_radius * 0.82, lower_radius, lower_height, Vector3(0.0, -upper_height - lower_height * 0.5, 0.0), Vector3.ZERO, material)
		_add_ellipsoid(pivot, "Hoof", Vector3(lower_radius * 2.25, lower_radius * 1.35, lower_radius * 2.9), Vector3(0.0, -total_height, -lower_radius * 0.42), material, Vector3.ZERO, 10, 5)
		legs.append(pivot)


func _add_antler(parent: Node3D, side: float, material: Material) -> void:
	var root := Vector3(0.18 * side, 0.24, 0.04)
	var crown := Vector3(0.34 * side, 1.08, 0.05)
	_add_cylinder_between(parent, "AntlerMain", root, crown, 0.045, material, 10)
	_add_cylinder_between(parent, "AntlerFront", Vector3(0.25 * side, 0.62, 0.03), Vector3(0.44 * side, 0.88, -0.30), 0.035, material, 10)
	_add_cylinder_between(parent, "AntlerMid", Vector3(0.30 * side, 0.80, 0.05), Vector3(0.58 * side, 1.14, 0.02), 0.035, material, 10)
	_add_cylinder_between(parent, "AntlerBack", Vector3(0.33 * side, 0.91, 0.06), Vector3(0.52 * side, 1.24, 0.30), 0.032, material, 10)


func _add_eye_pair(parent: Node3D, placement: Vector3, radius: float, material: Material) -> void:
	_add_ellipsoid(parent, "EyeL", Vector3.ONE * radius * 2.0, Vector3(placement.x, placement.y, placement.z), material, Vector3.ZERO, 10, 5)
	_add_ellipsoid(parent, "EyeR", Vector3.ONE * radius * 2.0, Vector3(-placement.x, placement.y, placement.z), material, Vector3.ZERO, 10, 5)


func _fur_material(base_color: Color, shadow_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FUR_SHADER
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"shadow_color", shadow_color)
	return material


func _standard_material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_ellipsoid(parent: Node3D, node_name: String, dimensions: Vector3, local_position: Vector3, material: Material, local_rotation := Vector3.ZERO, radial_segments := 16, rings := 8) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation = local_rotation
	instance.scale = dimensions
	parent.add_child(instance)
	return instance


func _add_tapered(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, local_position: Vector3, local_rotation: Vector3, material: Material, segments := 14) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation = local_rotation
	parent.add_child(instance)
	return instance


func _add_cone(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, material: Material, local_rotation := Vector3.ZERO) -> MeshInstance3D:
	return _add_tapered(parent, node_name, 0.015, radius, height, local_position, local_rotation, material, 14)


func _add_cylinder_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material, segments := 12) -> MeshInstance3D:
	var direction := finish - start
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = segments
	mesh.material = material
	instance.mesh = mesh
	instance.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), (start + finish) * 0.5)
	parent.add_child(instance)
	return instance
