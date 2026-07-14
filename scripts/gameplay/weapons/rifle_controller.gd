class_name RifleController
extends Node3D

const REAL_RIFLE_SCENE := "res://assets/models/bolt_action_rifle_7_62/bolt_action_rifle_7_62_1k.gltf"

@export var definition: WeaponDefinition

var magazine := 0
var reserve := 0
var is_aiming := false
var is_reloading := false

var _camera: Camera3D
var _owner_body: CharacterBody3D
var _cooldown := 0.0
var _reload_remaining := 0.0
var _rng := RandomNumberGenerator.new()
var _base_fov := 75.0
var _weapon_rest_position := Vector3(0.27, -0.21, -0.66)
var _weapon_aim_position := Vector3(0.0, -0.10, -0.42)
var _wind_acceleration := Vector3(0.42, 0.0, 0.16)
var _muzzle_flash: OmniLight3D
var _visual_root: Node3D
var _visual_recoil := 0.0
var _sway_time := 0.0


func initialize(camera: Camera3D, owner_body: CharacterBody3D) -> void:
	_camera = camera
	_owner_body = owner_body
	_base_fov = float(SettingsService.get_value(&"field_of_view", 75.0))
	_rng.seed = 90210
	magazine = definition.magazine_size
	reserve = definition.starting_reserve
	_build_weapon_visual()
	_emit_ammo()


func _process(delta: float) -> void:
	if _camera == null or definition == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = move_toward(_muzzle_flash.light_energy, 0.0, delta * 55.0)
	_update_visual_motion(delta)
	if GameState.phase != GameState.Phase.PLAYING:
		return

	if is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()

	var wants_aim := InputRouter.is_action_held(&"aim") and not is_reloading
	if wants_aim != is_aiming:
		is_aiming = wants_aim
		EventBus.aiming_changed.emit(is_aiming)
	_update_aim(delta)

	if InputRouter.consume_action_pressed(&"reload"):
		_start_reload()
	if InputRouter.consume_action_pressed(&"fire"):
		_try_fire()


func add_reserve_ammo(amount: int) -> int:
	var accepted := maxi(0, amount)
	reserve += accepted
	_emit_ammo()
	return accepted


func _update_aim(delta: float) -> void:
	var target_fov := definition.scope_fov if is_aiming else _base_fov
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-delta * 13.0))
	var target_position := _weapon_aim_position if is_aiming else _weapon_rest_position
	position = position.lerp(target_position, 1.0 - exp(-delta * 15.0))


func _try_fire() -> void:
	if is_reloading or _cooldown > 0.0:
		return
	if magazine <= 0:
		AudioService.play_cue(&"dry_fire")
		EventBus.notification_requested.emit("Şarjör boş — R ile doldur", EventBus.NotificationSeverity.WARNING, 1.8)
		return

	magazine -= 1
	_cooldown = definition.fire_interval
	GameState.register_shot()
	_emit_ammo()
	AudioService.play_cue(&"rifle_shot", _camera.global_position)
	EventBus.shot_fired.emit(_camera.global_position, -_camera.global_transform.basis.z, definition.report_loudness)
	EventBus.player_noise_emitted.emit(_camera.global_position, definition.report_loudness, &"gunshot")
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = 4.5
	_visual_recoil = 1.0

	var spread := definition.aimed_spread_degrees if is_aiming else definition.hip_spread_degrees
	var shot_direction := _apply_spread(-_camera.global_transform.basis.z, spread)
	_trace_ballistic_path(_camera.global_position, shot_direction)
	var recoil_scale := 0.48 if is_aiming else 1.0
	var horizontal := _rng.randf_range(-0.35, 0.35) * recoil_scale
	_owner_body.call("apply_recoil", definition.recoil_pitch_degrees * recoil_scale, horizontal)


func _apply_spread(direction: Vector3, spread_degrees: float) -> Vector3:
	var yaw := deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees))
	var pitch := deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees))
	var basis := Basis(Vector3.UP, yaw) * Basis(_camera.global_transform.basis.x, pitch)
	return (basis * direction).normalized()


func _trace_ballistic_path(origin: Vector3, direction: Vector3) -> void:
	var points := BallisticsSolver.sample_trajectory(
		origin,
		direction,
		definition.muzzle_velocity,
		definition.gravity_scale,
		_wind_acceleration,
		definition.max_range,
		0.012
	)
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_owner_body.get_rid()]
	var space := get_world_3d().direct_space_state
	for index in range(1, points.size()):
		query.from = points[index - 1]
		query.to = points[index]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		_resolve_hit(hit, origin, direction)
		return


func _resolve_hit(hit: Dictionary, origin: Vector3, direction: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var hit_position: Vector3 = hit.get("position", origin)
	var distance := origin.distance_to(hit_position)
	var impact_velocity := BallisticsSolver.velocity_after_distance(
		definition.muzzle_velocity,
		definition.drag_coefficient,
		distance
	)
	var info := DamageInfo.new()
	info.source = _owner_body
	info.world_position = hit_position
	info.direction = direction
	info.distance_meters = distance
	info.energy_joules = BallisticsSolver.kinetic_energy_joules(definition.projectile_mass_kg(), impact_velocity)
	info.base_damage = definition.base_damage * (impact_velocity / definition.muzzle_velocity)
	if collider != null and collider.has_method("receive_ballistic_hit"):
		collider.call("receive_ballistic_hit", info)
	else:
		AudioService.play_cue(&"hit", hit_position)


func _start_reload() -> void:
	if is_reloading or magazine >= definition.magazine_size or reserve <= 0:
		return
	is_reloading = true
	is_aiming = false
	_reload_remaining = definition.reload_duration
	AudioService.play_cue(&"reload")
	_emit_ammo()


func _finish_reload() -> void:
	var needed := definition.magazine_size - magazine
	var transferred := mini(needed, reserve)
	magazine += transferred
	reserve -= transferred
	is_reloading = false
	_emit_ammo()


func _emit_ammo() -> void:
	EventBus.ammo_changed.emit(magazine, reserve, is_reloading)


func _build_weapon_visual() -> void:
	if get_child_count() > 0:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "Anadolu308Visual"
	add_child(_visual_root)
	var rifle_scene := load(REAL_RIFLE_SCENE) as PackedScene
	if rifle_scene != null:
		var imported_rifle := rifle_scene.instantiate() as Node3D
		if imported_rifle != null:
			imported_rifle.name = "PolyHavenBoltActionRifle"
			imported_rifle.rotation_degrees = Vector3(-2.0, 90.0, -4.0)
			imported_rifle.position = Vector3(-0.025, 0.0, 0.0)
			imported_rifle.scale = Vector3.ONE * 0.82
			_visual_root.add_child(imported_rifle)
			_create_muzzle_flash(Vector3(0.0, 0.045, -0.54))
			return
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color("#161b1c")
	dark_metal.metallic = 0.84
	dark_metal.roughness = 0.24
	var brushed_steel := StandardMaterial3D.new()
	brushed_steel.albedo_color = Color("#4f5758")
	brushed_steel.metallic = 0.92
	brushed_steel.roughness = 0.31
	var walnut := ShaderMaterial.new()
	walnut.shader = load("res://assets/shaders/walnut.gdshader")
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("#101211")
	rubber.roughness = 0.92
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.05, 0.17, 0.19, 0.72)
	lens.metallic = 0.42
	lens.roughness = 0.07
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_add_capsule("Receiver", 0.072, 0.49, Vector3(0.0, 0.0, -0.09), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal)
	_add_ellipsoid("Stock", Vector3(0.18, 0.205, 0.62), Vector3(0.0, -0.035, 0.31), Vector3(deg_to_rad(-4.0), 0.0, 0.0), walnut)
	_add_ellipsoid("CheekRest", Vector3(0.155, 0.105, 0.37), Vector3(0.0, 0.075, 0.29), Vector3(deg_to_rad(-3.0), 0.0, 0.0), walnut)
	_add_ellipsoid("ForeStock", Vector3(0.145, 0.145, 0.52), Vector3(0.0, -0.035, -0.39), Vector3.ZERO, walnut)
	_add_capsule("Grip", 0.055, 0.285, Vector3(0.0, -0.16, 0.03), Vector3(deg_to_rad(-18.0), 0.0, 0.0), walnut)
	_add_cylinder("Barrel", 0.019, 0.88, Vector3(0.0, 0.045, -0.82), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal, 20)
	_add_cylinder("MuzzleCrown", 0.028, 0.075, Vector3(0.0, 0.045, -1.295), Vector3(deg_to_rad(90.0), 0.0, 0.0), brushed_steel, 20)
	_add_cylinder("ScopeTube", 0.037, 0.44, Vector3(0.0, 0.145, -0.24), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal, 20)
	_add_cylinder("ScopeFront", 0.055, 0.105, Vector3(0.0, 0.145, -0.485), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal, 20)
	_add_cylinder("ScopeRear", 0.050, 0.095, Vector3(0.0, 0.145, 0.005), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal, 20)
	_add_cylinder("FrontLens", 0.047, 0.008, Vector3(0.0, 0.145, -0.541), Vector3(deg_to_rad(90.0), 0.0, 0.0), lens, 24)
	_add_cylinder("RearLens", 0.043, 0.008, Vector3(0.0, 0.145, 0.056), Vector3(deg_to_rad(90.0), 0.0, 0.0), lens, 24)
	_add_cylinder("ScopeMountFront", 0.018, 0.105, Vector3(0.0, 0.085, -0.36), Vector3.ZERO, brushed_steel, 12)
	_add_cylinder("ScopeMountRear", 0.018, 0.105, Vector3(0.0, 0.085, -0.10), Vector3.ZERO, brushed_steel, 12)
	_add_cylinder_between("BoltStem", Vector3(0.055, 0.045, -0.02), Vector3(0.14, 0.00, 0.02), 0.012, brushed_steel)
	_add_ellipsoid("BoltKnob", Vector3.ONE * 0.055, Vector3(0.16, -0.01, 0.03), Vector3.ZERO, dark_metal, 12, 6)
	_add_cylinder_between("TriggerFront", Vector3(0.0, -0.065, -0.01), Vector3(0.0, -0.135, 0.02), 0.008, brushed_steel)
	_add_cylinder_between("TriggerGuardA", Vector3(0.0, -0.075, -0.06), Vector3(0.0, -0.17, -0.02), 0.009, dark_metal)
	_add_cylinder_between("TriggerGuardB", Vector3(0.0, -0.17, -0.02), Vector3(0.0, -0.17, 0.10), 0.009, dark_metal)
	_add_cylinder_between("TriggerGuardC", Vector3(0.0, -0.17, 0.10), Vector3(0.0, -0.075, 0.12), 0.009, dark_metal)
	_add_ellipsoid("ButtPad", Vector3(0.17, 0.205, 0.055), Vector3(0.0, -0.045, 0.64), Vector3.ZERO, rubber, 16, 8)
	_create_muzzle_flash(Vector3(0.0, 0.045, -1.34))


func _create_muzzle_flash(local_position: Vector3) -> void:
	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.position = local_position
	_muzzle_flash.light_color = Color("#ffd28a")
	_muzzle_flash.omni_range = 4.0
	_muzzle_flash.light_energy = 0.0
	_visual_root.add_child(_muzzle_flash)


func _update_visual_motion(delta: float) -> void:
	if _visual_root == null:
		return
	_sway_time += delta
	_visual_recoil = move_toward(_visual_recoil, 0.0, delta * 7.8)
	var speed := 0.0
	if _owner_body != null:
		speed = Vector2(_owner_body.velocity.x, _owner_body.velocity.z).length()
	var movement_weight := clampf(speed / 7.0, 0.0, 1.0)
	var breathing := sin(_sway_time * 1.45) * 0.004
	var walk_sway := sin(_sway_time * (5.0 + speed)) * 0.008 * movement_weight
	_visual_root.position = Vector3(walk_sway, breathing, _visual_recoil * 0.105)
	if is_reloading:
		var reload_progress := 1.0 - clampf(_reload_remaining / definition.reload_duration, 0.0, 1.0)
		_visual_root.rotation = Vector3(deg_to_rad(-9.0), deg_to_rad(14.0), sin(reload_progress * PI) * deg_to_rad(-34.0))
	else:
		_visual_root.rotation = Vector3(deg_to_rad(-5.5) * _visual_recoil, walk_sway * 0.8, -walk_sway * 0.65)


func _visual_parent() -> Node3D:
	return _visual_root if _visual_root != null else self


func _add_ellipsoid(node_name: String, dimensions: Vector3, local_position: Vector3, local_rotation: Vector3, material: Material, radial_segments := 18, rings := 9) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	sphere.material = material
	mesh_instance.mesh = sphere
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_instance.scale = dimensions
	_visual_parent().add_child(mesh_instance)


func _add_capsule(node_name: String, radius: float, height: float, local_position: Vector3, local_rotation: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	capsule.radial_segments = 18
	capsule.rings = 8
	capsule.material = material
	mesh_instance.mesh = capsule
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	_visual_parent().add_child(mesh_instance)


func _add_cylinder(node_name: String, radius: float, height: float, local_position: Vector3, local_rotation: Vector3, material: Material, segments := 16) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	_visual_parent().add_child(mesh_instance)


func _add_cylinder_between(node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var direction := finish - start
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = direction.length()
	cylinder.radial_segments = 12
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), (start + finish) * 0.5)
	_visual_parent().add_child(mesh_instance)
