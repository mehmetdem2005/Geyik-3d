class_name WildlifeDirector
extends Node

const ANIMAL_SCENE := preload("res://scenes/animals/animal.tscn")
const DEER := preload("res://scripts/data/red_deer.tres")
const WOLF := preload("res://scripts/data/grey_wolf.tres")
const BEAR := preload("res://scripts/data/brown_bear.tres")

@export var deer_budget := 14
@export var wolf_budget := 4
@export var bear_budget := 2

var _world: WorldStreamer
var _player: PlayerController
var _rng := RandomNumberGenerator.new()
var _spawn_accumulator := 0.0
var _maintenance_accumulator := 0.0


func _ready() -> void:
	_rng.seed = 142857
	EventBus.player_spawned.connect(_on_player_spawned)


func configure(world: WorldStreamer) -> void:
	_world = world
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController


func _process(delta: float) -> void:
	if _player == null or _world == null or GameState.phase != GameState.Phase.PLAYING:
		return
	_spawn_accumulator += delta
	_maintenance_accumulator += delta
	if _spawn_accumulator >= 0.7:
		_spawn_accumulator = 0.0
		_fill_one_population_slot()
	if _maintenance_accumulator >= 3.0:
		_maintenance_accumulator = 0.0
		_despawn_far_animals()
		_emit_population()


func _on_player_spawned(player: Node) -> void:
	_player = player as PlayerController


func _fill_one_population_slot() -> void:
	var counts := _get_counts()
	var definition: AnimalDefinition
	if counts[&"deer"] < deer_budget:
		definition = DEER
	elif counts[&"wolf"] < wolf_budget:
		definition = WOLF
	elif counts[&"bear"] < bear_budget:
		definition = BEAR
	else:
		return
	_spawn_animal(definition)


func _spawn_animal(definition: AnimalDefinition) -> void:
	for attempt in 12:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(58.0, 145.0)
		var x := _player.global_position.x + sin(angle) * distance
		var z := _player.global_position.z + cos(angle) * distance
		if _world.is_water_xz(x, z) or _world.is_landmark_clearance(Vector2(x, z)):
			continue
		var y := _world.sample_height(x, z) + 0.2
		var actor: AnimalController = ANIMAL_SCENE.instantiate()
		actor.setup(definition, _world, Vector3(x, y, z), _rng.randi())
		add_child(actor)
		return


func _despawn_far_animals() -> void:
	for animal in get_tree().get_nodes_in_group(&"animals"):
		if not is_instance_valid(animal) or animal.state == AnimalController.State.DOWNED:
			continue
		if animal.global_position.distance_to(_player.global_position) > 230.0:
			animal.queue_free()


func _get_counts() -> Dictionary:
	return {
		&"deer": get_tree().get_nodes_in_group(&"deer").size(),
		&"wolf": get_tree().get_nodes_in_group(&"wolf").size(),
		&"bear": get_tree().get_nodes_in_group(&"bear").size(),
	}


func _emit_population() -> void:
	EventBus.animal_population_changed.emit(_get_counts())
