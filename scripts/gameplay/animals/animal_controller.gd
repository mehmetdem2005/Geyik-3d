class_name AnimalController
extends CharacterBody3D

enum State {
	IDLE,
	WANDER,
	ALERT,
	FLEE,
	CHASE,
	ATTACK,
	DOWNED,
}

@export var definition: AnimalDefinition

@onready var collision_shape: CollisionShape3D = %BodyCollision
@onready var health: HealthComponent = %Health

var actor_seed := 0
var state := State.IDLE
var _world: WorldStreamer
var _player: PlayerController
var _visual: AnimalVisual
var _rng := RandomNumberGenerator.new()
var _state_time := 0.0
var _perception_time := 0.0
var _attack_time := 0.0
var _desired_direction := Vector3.FORWARD
var _threat_position := Vector3.ZERO
var _last_hit_zone: StringName = &"body"
var _shot_count := 0
var _trophy_score := 0.0
var _harvested := false
var _current_speed := 0.0


func setup(animal_definition: AnimalDefinition, world: WorldStreamer, spawn_position: Vector3, seed: int) -> void:
	definition = animal_definition
	_world = world
	actor_seed = seed
	position = spawn_position


func _ready() -> void:
	if definition == null:
		definition = load("res://scripts/data/red_deer.tres")
	if _world == null:
		_world = get_tree().get_first_node_in_group(&"world_streamer") as WorldStreamer
	_rng.seed = actor_seed if actor_seed != 0 else int(get_instance_id())
	_trophy_score = _rng.randf_range(definition.minimum_trophy, definition.maximum_trophy)
	health.maximum_health = definition.maximum_health
	health.reset()
	health.died.connect(_on_died)
	_configure_collision()
	_visual = AnimalVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	_visual.build(definition)
	add_to_group(&"animals")
	add_to_group(definition.species_id)
	EventBus.player_noise_emitted.connect(_on_noise_heard)
	_set_state(State.IDLE, _rng.randf_range(1.5, 4.5))


func _physics_process(delta: float) -> void:
	if state == State.DOWNED:
		_visual.animate_motion(0.0, delta, true)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as PlayerController
	_state_time -= delta
	_perception_time -= delta
	_attack_time -= delta
	if _perception_time <= 0.0:
		_perception_time = _rng.randf_range(0.22, 0.42)
		_evaluate_perception()
	_tick_state()
	_apply_locomotion(delta)
	_visual.animate_motion(_current_speed, delta, false)


func receive_ballistic_hit(info: DamageInfo) -> void:
	if state == State.DOWNED:
		return
	_shot_count += 1
	_last_hit_zone = _classify_hit_zone(info.world_position)
	info.hit_zone = _last_hit_zone
	var multiplier := 1.0
	match _last_hit_zone:
		&"brain": multiplier = 3.0
		&"spine": multiplier = 2.25
		&"heart_lung": multiplier = 1.8
		&"limb": multiplier = 0.48
	var damage := info.base_damage * multiplier
	health.apply_damage(damage, info)
	GameState.register_hit()
	EventBus.animal_hit.emit(self, {
		"species": definition.species_id,
		"zone": _last_hit_zone,
		"damage": damage,
		"distance": info.distance_meters,
		"lethal": health.is_dead,
	})
	EventBus.hit_marker_requested.emit(health.is_dead)
	AudioService.play_cue(&"hit", info.world_position)
	if not health.is_dead:
		_threat_position = (info.source as Node3D).global_position if info.source is Node3D else info.world_position - info.direction
		_set_state(State.CHASE if definition.is_predator else State.FLEE, definition.calm_after_seconds)


func get_interaction_text() -> String:
	if state == State.DOWNED and not _harvested:
		return "AVı DOĞRULA"
	return ""


func interact(_player_actor: Node) -> void:
	if state != State.DOWNED or _harvested:
		return
	_harvested = true
	var vital_hit := _last_hit_zone in [&"brain", &"spine", &"heart_lung"]
	var ethical := vital_hit and _shot_count <= 2
	var base_score := int(round(_trophy_score * (1.0 if ethical else 0.58)))
	var report := {
		"species": definition.species_id,
		"species_name": definition.species_name,
		"trophy": _trophy_score,
		"hit_zone": _last_hit_zone,
		"shots": _shot_count,
		"ethical": ethical,
		"score": base_score,
	}
	GameState.register_harvest(report)
	EventBus.animal_harvested.emit(report)
	EventBus.notification_requested.emit("%s doğrulandı: +%s" % [definition.species_name, base_score], EventBus.NotificationSeverity.SUCCESS, 3.0)
	AudioService.play_cue(&"ui_confirm")
	queue_free()


func _tick_state() -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	match state:
		State.IDLE:
			_current_speed = 0.0
			if _state_time <= 0.0:
				_choose_wander()
		State.WANDER:
			_current_speed = definition.walk_speed
			if _state_time <= 0.0:
				_set_state(State.IDLE, _rng.randf_range(1.5, 5.0))
		State.ALERT:
			_current_speed = 0.0
			_desired_direction = (_threat_position - global_position).normalized()
			if _state_time <= 0.0:
				_set_state(State.CHASE if definition.is_predator else State.FLEE, definition.calm_after_seconds)
		State.FLEE:
			_desired_direction = (global_position - _threat_position).normalized()
			_current_speed = definition.flee_speed
			if _state_time <= 0.0 and global_position.distance_to(_threat_position) > 85.0:
				_choose_wander()
		State.CHASE:
			_desired_direction = flat_to_player.normalized()
			_current_speed = definition.flee_speed
			if flat_to_player.length() <= definition.attack_range:
				_set_state(State.ATTACK, 0.4)
			elif _state_time <= 0.0 and flat_to_player.length() > definition.aggression_range * 1.8:
				_choose_wander()
		State.ATTACK:
			_desired_direction = flat_to_player.normalized()
			_current_speed = 0.0
			if flat_to_player.length() > definition.attack_range * 1.25:
				_set_state(State.CHASE, definition.calm_after_seconds)
			elif _attack_time <= 0.0:
				_attack_time = definition.attack_cooldown
				_player.receive_melee_damage(definition.attack_damage, self)


func _apply_locomotion(delta: float) -> void:
	var horizontal := Vector3(_desired_direction.x, 0.0, _desired_direction.z).normalized()
	if _current_speed > 0.0 and not horizontal.is_zero_approx():
		var desired_yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 4.8))
		var forward := -global_transform.basis.z
		velocity.x = forward.x * _current_speed
		velocity.z = forward.z * _current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	if _world != null and global_position.y < _world.sample_height(global_position.x, global_position.z) - 1.0:
		global_position.y = _world.sample_height(global_position.x, global_position.z) + 0.1
	if absf(global_position.x) > 100000.0 or absf(global_position.z) > 100000.0:
		queue_free()


func _evaluate_perception() -> void:
	if _player == null or state in [State.DOWNED, State.CHASE, State.ATTACK, State.FLEE]:
		return
	var offset := _player.global_position - global_position
	var distance := offset.length()
	if definition.is_predator and distance <= definition.aggression_range:
		_threat_position = _player.global_position
		_set_state(State.CHASE, definition.calm_after_seconds)
		return
	var visibility_modifier := 0.58 if _player.is_crouching else 1.0
	if distance > definition.vision_range * visibility_modifier:
		return
	var forward := -global_transform.basis.z
	var direction := offset.normalized()
	var required_dot := cos(deg_to_rad(definition.field_of_view_degrees * 0.5))
	if forward.dot(direction) < required_dot:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, _player.global_position + Vector3.UP * 1.2, 1)
	query.exclude = [get_rid()]
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		return
	_threat_position = _player.global_position
	_set_state(State.CHASE if definition.is_predator else State.ALERT, 0.8)


func _on_noise_heard(noise_position: Vector3, loudness: float, _category: StringName) -> void:
	if state == State.DOWNED:
		return
	var effective_range := minf(definition.hearing_range, loudness)
	if global_position.distance_to(noise_position) > effective_range:
		return
	_threat_position = noise_position
	if definition.is_predator and loudness >= 35.0:
		_set_state(State.CHASE, definition.calm_after_seconds)
	else:
		_set_state(State.FLEE if state == State.ALERT else State.ALERT, 0.75)


func _choose_wander() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	_desired_direction = Vector3(sin(angle), 0.0, cos(angle))
	_set_state(State.WANDER, _rng.randf_range(3.0, 8.0))


func _set_state(next_state: State, duration: float) -> void:
	if state != next_state:
		state = next_state
		EventBus.animal_state_changed.emit(self, State.keys()[state].to_lower())
	_state_time = duration


func _classify_hit_zone(world_position: Vector3) -> StringName:
	var local := to_local(world_position)
	var scale_factor := 1.0 if definition.species_id != &"bear" else 1.25
	if local.y > 2.15 * scale_factor:
		return &"brain"
	if local.y > 1.55 * scale_factor and absf(local.x) < 0.28 * scale_factor:
		return &"spine"
	if local.y > 0.85 * scale_factor and local.z < 0.55:
		return &"heart_lung"
	if local.y < 0.8 * scale_factor:
		return &"limb"
	return &"body"


func _configure_collision() -> void:
	var shape := CapsuleShape3D.new()
	if definition.species_id == &"bear":
		shape.radius = 0.9
		shape.height = 2.6
		collision_shape.position.y = 1.3
	elif definition.species_id == &"wolf":
		shape.radius = 0.45
		shape.height = 1.8
		collision_shape.position.y = 0.9
	else:
		shape.radius = 0.52
		shape.height = 2.8
		collision_shape.position.y = 1.4
	collision_shape.shape = shape


func _on_died(_info: DamageInfo) -> void:
	velocity = Vector3.ZERO
	_set_state(State.DOWNED, 0.0)
	collision_layer = 4
	collision_mask = 1
