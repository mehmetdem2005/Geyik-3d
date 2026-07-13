class_name PickupDirector
extends Node

var _world: WorldStreamer
var _player: PlayerController
var _rng := RandomNumberGenerator.new()
var _timer := 0.0


func _ready() -> void:
	_rng.seed = 982451653
	EventBus.player_spawned.connect(func(player: Node) -> void: _player = player as PlayerController)


func configure(world: WorldStreamer) -> void:
	_world = world
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController


func _process(delta: float) -> void:
	if _world == null or _player == null or GameState.phase != GameState.Phase.PLAYING:
		return
	_timer += delta
	if _timer < 1.2:
		return
	_timer = 0.0
	var ammo_count := 0
	var medkit_count := 0
	for pickup in get_tree().get_nodes_in_group(&"pickups"):
		if pickup.pickup_type == &"ammo":
			ammo_count += 1
		else:
			medkit_count += 1
	if ammo_count < 6:
		_spawn_pickup(&"ammo", 15)
	elif medkit_count < 4:
		_spawn_pickup(&"medkit", 35)


func _spawn_pickup(type: StringName, amount: int) -> void:
	for attempt in 10:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(32.0, 135.0)
		var x := _player.global_position.x + sin(angle) * distance
		var z := _player.global_position.z + cos(angle) * distance
		if _world.is_water_xz(x, z) or _world.is_landmark_clearance(Vector2(x, z)):
			continue
		var pickup := PickupController.new()
		pickup.pickup_type = type
		pickup.amount = amount
		pickup.position = Vector3(x, _world.sample_height(x, z) + 1.0, z)
		add_child(pickup)
		return
