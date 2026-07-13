class_name GameRoot
extends Node3D

@onready var world: WorldStreamer = %WorldStreamer
@onready var wildlife: WildlifeDirector = %WildlifeDirector
@onready var pickups: PickupDirector = %PickupDirector
@onready var player: PlayerController = %Player


func _ready() -> void:
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.MAIN_MENU)
	var spawn_x := 48.0
	var spawn_z := 22.0
	player.position = Vector3(spawn_x, world.sample_height(spawn_x, spawn_z) + 1.5, spawn_z)
	wildlife.configure(world)
	pickups.configure(world)
	world.set_player(player)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if "--ci-smoke" in OS.get_cmdline_user_args():
		GameState.start_hunt()
