class_name PlayerController
extends CharacterBody3D

@export_category("Movement")
@export var walk_speed := 4.6
@export var sprint_speed := 7.35
@export var crouch_speed := 2.25
@export var swim_speed := 3.1
@export var acceleration := 10.5
@export var deceleration := 19.0
@export var air_control := 3.0
@export var jump_velocity := 6.0

@export_category("Stamina")
@export var maximum_stamina := 100.0
@export var sprint_drain_per_second := 18.0
@export var recovery_per_second := 14.0

@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera
@onready var rifle: RifleController = %Rifle
@onready var interaction_ray: RayCast3D = %InteractionRay
@onready var health: HealthComponent = %Health

var stamina := 100.0
var is_crouching := false
var is_sprinting := false
var is_swimming := false
var _pitch := 0.0
var _step_distance := 0.0
var _last_position := Vector3.ZERO
var _base_head_height := 1.66
var _bob_phase := 0.0
var _last_prompt := ""
var _status_emit_accumulator := 0.0
var _world_streamer: Node


func _ready() -> void:
	add_to_group(&"player")
	stamina = maximum_stamina
	_last_position = global_position
	camera.fov = float(SettingsService.get_value(&"field_of_view", 75.0))
	health.maximum_health = 100.0
	health.reset()
	health.died.connect(_on_died)
	rifle.initialize(camera, self)
	_world_streamer = get_tree().get_first_node_in_group(&"world_streamer")
	EventBus.player_spawned.emit(self)
	EventBus.stamina_changed.emit(stamina, maximum_stamina)
	EventBus.player_health_changed.emit(health.current_health, health.maximum_health)


func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING or health.is_dead:
		velocity = Vector3.ZERO
		return
	_apply_look()
	_update_water_state()
	_handle_movement(delta)
	_update_camera_motion(delta)
	_update_noise()
	_update_interaction()


func receive_melee_damage(amount: float, source: Node) -> void:
	if health.is_dead:
		return
	var info := DamageInfo.new()
	info.source = source
	info.world_position = global_position
	info.base_damage = amount
	health.apply_damage(amount, info)
	EventBus.player_health_changed.emit(health.current_health, health.maximum_health)
	EventBus.notification_requested.emit("Yaralandın!", EventBus.NotificationSeverity.ERROR, 1.2)
	AudioService.play_cue(&"hurt")


func heal(amount: float) -> int:
	if health.is_dead:
		return 0
	var previous := health.current_health
	health.current_health = minf(health.maximum_health, health.current_health + amount)
	var applied := int(round(health.current_health - previous))
	if applied > 0:
		EventBus.player_health_changed.emit(health.current_health, health.maximum_health)
	return applied


func add_ammo(amount: int) -> int:
	return rifle.add_reserve_ammo(amount)


func apply_recoil(pitch_degrees: float, horizontal_degrees: float) -> void:
	_pitch = clampf(_pitch + deg_to_rad(pitch_degrees), deg_to_rad(-84.0), deg_to_rad(84.0))
	rotate_y(deg_to_rad(horizontal_degrees))
	head.rotation.x = _pitch


func get_camera() -> Camera3D:
	return camera


func _apply_look() -> void:
	var look_delta := InputRouter.consume_look_delta()
	if look_delta.is_zero_approx():
		return
	var sensitivity := float(SettingsService.get_value(&"touch_sensitivity", 0.0038))
	rotate_y(-look_delta.x * sensitivity)
	_pitch = clampf(_pitch - look_delta.y * sensitivity, deg_to_rad(-84.0), deg_to_rad(84.0))
	head.rotation.x = _pitch


func _handle_movement(delta: float) -> void:
	var input_vector := InputRouter.get_move_vector()
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	is_crouching = InputRouter.is_action_held(&"crouch") and not is_swimming
	var wants_sprint := InputRouter.is_action_held(&"sprint") and input_vector.y < -0.1 and not is_crouching and not is_swimming
	is_sprinting = wants_sprint and stamina > 1.0

	if is_sprinting and not world_direction.is_zero_approx():
		stamina = maxf(0.0, stamina - sprint_drain_per_second * delta)
	else:
		stamina = minf(maximum_stamina, stamina + recovery_per_second * delta)

	var target_speed := walk_speed
	if is_swimming:
		target_speed = swim_speed
	elif is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	var target_velocity := world_direction * target_speed * clampf(input_vector.length(), 0.0, 1.0)
	var has_input := not target_velocity.is_zero_approx()
	var ground_control := acceleration if has_input else deceleration
	var control := ground_control if is_on_floor() or is_swimming else air_control
	velocity.x = move_toward(velocity.x, target_velocity.x, control * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, control * delta)

	if is_swimming:
		var water_level := float(_world_streamer.call("get_water_level")) if _world_streamer != null else -0.6
		var desired_body_y := water_level - 0.25
		velocity.y = move_toward(velocity.y, (desired_body_y - global_position.y) * 2.4, delta * 6.0)
	elif not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)) * delta
	elif InputRouter.consume_action_pressed(&"jump") and not is_crouching:
		velocity.y = jump_velocity

	move_and_slide()
	_recover_from_streamed_terrain()
	_status_emit_accumulator += delta
	if _status_emit_accumulator >= 0.1:
		_status_emit_accumulator = 0.0
		EventBus.stamina_changed.emit(stamina, maximum_stamina)


func _recover_from_streamed_terrain() -> void:
	if _world_streamer == null or is_swimming:
		return
	var ground_height := float(_world_streamer.call("sample_height", global_position.x, global_position.z))
	if global_position.y >= ground_height + 0.08:
		return
	# Procedural collision is streamed one chunk per frame. Keep the player's
	# feet on the analytical terrain surface if a collider is not ready yet.
	global_position.y = ground_height + 0.08
	velocity.y = maxf(velocity.y, 0.0)


func _update_camera_motion(delta: float) -> void:
	var target_height := 1.1 if is_crouching else _base_head_height
	if is_swimming:
		target_height = 1.2
	head.position.y = move_toward(head.position.y, target_height, delta * 3.8)
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var bob_strength := float(SettingsService.get_value(&"camera_bob", 0.65))
	if (is_on_floor() or is_swimming) and horizontal_speed > 0.3:
		_bob_phase += delta * horizontal_speed * (1.0 if is_swimming else 1.48)
		var sprint_weight := 1.28 if is_sprinting else 1.0
		camera.position.y = sin(_bob_phase * 2.0) * 0.022 * bob_strength * sprint_weight
		camera.position.x = cos(_bob_phase) * 0.016 * bob_strength * sprint_weight
		camera.rotation.z = lerpf(camera.rotation.z, sin(_bob_phase) * 0.006 * bob_strength, minf(1.0, delta * 8.0))
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, minf(1.0, delta * 8.0))


func _update_noise() -> void:
	var moved := Vector3(global_position.x, 0.0, global_position.z).distance_to(Vector3(_last_position.x, 0.0, _last_position.z))
	_last_position = global_position
	_step_distance += moved
	var stride := 2.3 if is_sprinting else (1.45 if not is_crouching else 1.05)
	if _step_distance < stride or (not is_on_floor() and not is_swimming):
		return
	_step_distance = 0.0
	var loudness := 22.0
	var surface: StringName = &"grass"
	if is_swimming:
		loudness = 34.0
		surface = &"water"
	elif is_sprinting:
		loudness = 58.0
	elif is_crouching:
		loudness = 8.0
	EventBus.player_noise_emitted.emit(global_position, loudness, surface)
	AudioService.play_cue(&"footstep", global_position)


func _update_interaction() -> void:
	interaction_ray.force_raycast_update()
	var prompt := ""
	var collider := interaction_ray.get_collider()
	if collider != null and collider.has_method("get_interaction_text"):
		prompt = String(collider.call("get_interaction_text"))
		if InputRouter.consume_action_pressed(&"interact"):
			collider.call("interact", self)
	if prompt != _last_prompt:
		_last_prompt = prompt
		EventBus.interaction_prompt_changed.emit(prompt, not prompt.is_empty())


func _update_water_state() -> void:
	if _world_streamer == null:
		_world_streamer = get_tree().get_first_node_in_group(&"world_streamer")
		return
	var next_state := bool(_world_streamer.call("is_swimmable_position", global_position))
	if next_state != is_swimming:
		is_swimming = next_state
		EventBus.swimming_changed.emit(is_swimming)


func _on_died(_info: DamageInfo) -> void:
	InputRouter.clear_gameplay_input()
	EventBus.player_health_changed.emit(0.0, health.maximum_health)
	EventBus.player_died.emit()
	GameState.set_phase(GameState.Phase.RESULTS)
