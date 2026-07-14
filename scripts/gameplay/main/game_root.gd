class_name GameRoot
extends Node3D

const ANIMAL_SCENE := preload("res://scenes/animals/animal.tscn")
const RED_DEER := preload("res://scripts/data/red_deer.tres")

@onready var world: WorldStreamer = %WorldStreamer
@onready var wildlife: WildlifeDirector = %WildlifeDirector
@onready var pickups: PickupDirector = %PickupDirector
@onready var player: PlayerController = %Player


func _ready() -> void:
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.MAIN_MENU)
	# Begin outside the outpost clearance, looking toward the river valley.
	# This keeps the first playable frame readable on narrow mobile displays.
	var spawn_x := 50.0
	var spawn_z := 6.0
	# Start above the analytical surface while the first streamed collider settles.
	player.position = Vector3(spawn_x, world.sample_height(spawn_x, spawn_z) + 1.5, spawn_z)
	player.rotation.y = deg_to_rad(78.0)
	wildlife.configure(world)
	pickups.configure(world)
	world.set_player(player)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	var user_arguments := OS.get_cmdline_user_args()
	if "--render-showcase" in user_arguments:
		_stage_render_showcase()
		GameState.start_hunt()
	elif "--ci-smoke" in user_arguments:
		GameState.start_hunt()


func _stage_render_showcase() -> void:
	# Deterministic capture setup used by release screenshots. It exercises the
	# real animal scene and materials without changing normal hunt population.
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var showcase_position := player.global_position + forward * 21.0 + right * 3.0
	showcase_position.y = world.sample_height(showcase_position.x, showcase_position.z) + 0.12
	var deer: AnimalController = ANIMAL_SCENE.instantiate()
	deer.setup(RED_DEER, world, showcase_position, 70413)
	wildlife.add_child(deer)
	deer.rotation.y = player.rotation.y + PI * 0.5
	deer.process_mode = Node.PROCESS_MODE_DISABLED
