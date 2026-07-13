class_name PickupController
extends Area3D

@export var pickup_type: StringName = &"ammo"
@export var amount := 15

var _base_y := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_build_visual()
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	add_to_group(&"pickups")


func _process(delta: float) -> void:
	rotate_y(delta * 1.35)
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.0024 + get_instance_id()) * 0.18


func _on_body_entered(body: Node) -> void:
	if body is not PlayerController:
		return
	var applied := 0
	if pickup_type == &"ammo":
		applied = body.add_ammo(amount)
	else:
		applied = body.heal(amount)
	if applied <= 0:
		return
	EventBus.pickup_collected.emit(pickup_type, applied)
	EventBus.notification_requested.emit("%s +%s" % ["Mermi" if pickup_type == &"ammo" else "Sağlık", applied], EventBus.NotificationSeverity.SUCCESS, 1.6)
	AudioService.play_cue(&"ui_confirm")
	queue_free()


func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d1a84d") if pickup_type == &"ammo" else Color("#d84b4b")
	material.metallic = 0.35 if pickup_type == &"ammo" else 0.0
	material.roughness = 0.4
	var visual := MeshInstance3D.new()
	if pickup_type == &"ammo":
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 0.45, 0.55)
		mesh.material = material
		visual.mesh = mesh
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.72, 0.72)
		mesh.material = material
		visual.mesh = mesh
	add_child(visual)
	var light := OmniLight3D.new()
	light.light_color = material.albedo_color
	light.light_energy = 0.45
	light.omni_range = 2.8
	add_child(light)

