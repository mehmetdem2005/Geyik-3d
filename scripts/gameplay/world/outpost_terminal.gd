class_name OutpostTerminal
extends StaticBody3D

var _material_wood: StandardMaterial3D
var _material_roof: StandardMaterial3D


func _ready() -> void:
	collision_layer = 17
	collision_mask = 0
	_build_visual()


func get_interaction_text() -> String:
	return "KARAKOLU KULLAN"


func interact(_player: Node) -> void:
	EventBus.outpost_interacted.emit()


func _build_visual() -> void:
	_material_wood = StandardMaterial3D.new()
	_material_wood.albedo_color = Color("#62472f")
	_material_wood.roughness = 0.92
	_material_roof = StandardMaterial3D.new()
	_material_roof.albedo_color = Color("#26352b")
	_material_roof.roughness = 0.86
	_add_box("Cabin", Vector3(7.5, 3.8, 5.8), Vector3(0.0, 1.9, 0.0), _material_wood, true)
	_add_box("Roof", Vector3(8.3, 0.55, 6.6), Vector3(0.0, 4.15, 0.0), _material_roof, false, Vector3(0.0, 0.0, deg_to_rad(6.0)))
	_add_box("Counter", Vector3(2.8, 1.1, 0.65), Vector3(0.0, 0.55, -3.15), _material_wood, true)
	var sign_label := Label3D.new()
	sign_label.text = "ORMAN KARAKOLU"
	sign_label.font_size = 46
	sign_label.outline_size = 8
	sign_label.modulate = Color("#f3dfb7")
	sign_label.position = Vector3(0.0, 3.05, -3.02)
	sign_label.rotation.y = PI
	add_child(sign_label)


func _add_box(node_name: String, size: Vector3, local_position: Vector3, material: Material, add_collision: bool, local_rotation := Vector3.ZERO) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	visual.position = local_position
	visual.rotation = local_rotation
	add_child(visual)
	if add_collision:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = local_position
		collision.rotation = local_rotation
		add_child(collision)
