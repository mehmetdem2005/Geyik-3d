class_name RifleController
extends Node3D

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
var _weapon_rest_position := Vector3(0.28, -0.24, -0.52)
var _weapon_aim_position := Vector3(0.0, -0.17, -0.38)
var _wind_acceleration := Vector3(0.42, 0.0, 0.16)
var _muzzle_flash: OmniLight3D


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
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color("#202522")
	dark_metal.metallic = 0.72
	dark_metal.roughness = 0.28
	var walnut := StandardMaterial3D.new()
	walnut.albedo_color = Color("#6b3d22")
	walnut.roughness = 0.65

	_add_box("Receiver", Vector3(0.12, 0.12, 0.48), Vector3(0.0, 0.0, -0.12), dark_metal)
	_add_box("Stock", Vector3(0.16, 0.18, 0.46), Vector3(0.0, -0.03, 0.29), walnut)
	_add_cylinder("Barrel", 0.025, 0.74, Vector3(0.0, 0.045, -0.72), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal)
	_add_cylinder("Scope", 0.042, 0.42, Vector3(0.0, 0.15, -0.25), Vector3(deg_to_rad(90.0), 0.0, 0.0), dark_metal)
	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	_muzzle_flash.position = Vector3(0.0, 0.045, -1.1)
	_muzzle_flash.light_color = Color("#ffd28a")
	_muzzle_flash.omni_range = 4.0
	_muzzle_flash.light_energy = 0.0
	add_child(_muzzle_flash)


func _add_box(node_name: String, size: Vector3, local_position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	add_child(mesh_instance)


func _add_cylinder(node_name: String, radius: float, height: float, local_position: Vector3, local_rotation: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.material = material
	mesh_instance.mesh = cylinder
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	add_child(mesh_instance)
