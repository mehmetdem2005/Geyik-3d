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
		if "--capture-showcase" in user_arguments:
			call_deferred("_capture_showcase")
	elif "--ci-touch-smoke" in user_arguments:
		GameState.start_hunt()
		call_deferred("_run_touch_smoke")
	elif "--ci-smoke" in user_arguments:
		GameState.start_hunt()


func _run_touch_smoke() -> void:
	# Exercise the real HUD callbacks instead of writing directly to player
	# velocity. This catches touch-layer regressions on headless CI.
	await get_tree().process_frame
	var joystick := find_child("MovementJoystick", true, false) as HuntVirtualJoystick
	var fire_button := find_child("FireButton", true, false) as Button
	if joystick == null or fire_button == null:
		push_error("Mobile controls were not created.")
		get_tree().quit(1)
		return
	var start_xz := Vector2(player.global_position.x, player.global_position.z)
	var center := HuntVirtualJoystick.fixed_center_for_size(joystick.size, joystick.center_from_bottom_left, joystick.radius)
	joystick.call("_begin", center + Vector2.UP * joystick.radius)
	await get_tree().create_timer(0.7).timeout
	joystick.call("_end")
	var end_xz := Vector2(player.global_position.x, player.global_position.z)
	if start_xz.distance_to(end_xz) < 0.45:
		push_error("The fixed mobile joystick did not move the player.")
		get_tree().quit(1)
		return
	var ammo_before := player.rifle.magazine
	fire_button.button_down.emit()
	await get_tree().create_timer(0.2).timeout
	fire_button.button_up.emit()
	if player.rifle.magazine != ammo_before - 1:
		push_error("The mobile fire button did not reach the rifle controller.")
		get_tree().quit(1)
		return
	print("Geyik 3D mobile touch smoke passed: joystick movement and fire button.")
	get_tree().quit(0)
func _stage_render_showcase() -> void:
	# Deterministic capture setup used by release screenshots. It exercises the
	# real animal scene and materials without changing normal hunt population.
	var outpost := world.get_node_or_null("ForestOutpost")
	if outpost != null:
		outpost.hide()
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var showcase_position := player.global_position + forward * 16.0 + right * 2.2
	showcase_position.y = world.sample_height(showcase_position.x, showcase_position.z) + 0.18
	var deer: AnimalController = ANIMAL_SCENE.instantiate()
	deer.setup(RED_DEER, world, showcase_position, 70413)
	wildlife.add_child(deer)
	deer.rotation.y = player.rotation.y + PI * 0.5
	deer.process_mode = Node.PROCESS_MODE_DISABLED


func _capture_showcase() -> void:
	# Capture the rendered viewport directly. Root-window screenshots can contain
	# stale damage rectangles under Xvfb/llvmpipe even when the game frame is fine.
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://artifacts/geyik3d-godot47-mobile-pbr.png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Showcase capture failed with error %s." % error)
		get_tree().quit(1)
		return
	print("Geyik 3D showcase captured: ", output_path)
	get_tree().quit(0)
