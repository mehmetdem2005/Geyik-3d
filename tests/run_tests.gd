extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ballistic_origin_and_drop()
	_test_drag_is_monotonic()
	_test_weapon_mass_conversion()
	_test_damage_lifecycle()
	_test_input_edge_consumption()
	if _failures.is_empty():
		print("Geyik 3D checks passed (5 suites).")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_ballistic_origin_and_drop() -> void:
	var origin := Vector3(4.0, 12.0, -3.0)
	var direction := Vector3.FORWARD
	var at_zero := BallisticsSolver.trajectory_position(origin, direction, 800.0, 1.0, Vector3.ZERO, 0.0)
	_expect(at_zero.is_equal_approx(origin), "Ballistics must start at the muzzle origin.")
	var after_one := BallisticsSolver.trajectory_position(origin, direction, 800.0, 1.0, Vector3.ZERO, 1.0)
	_expect(after_one.y < origin.y - 4.8 and after_one.y > origin.y - 5.0, "Gravity drop should use physical acceleration.")


func _test_drag_is_monotonic() -> void:
	var muzzle := 815.0
	var at_100 := BallisticsSolver.velocity_after_distance(muzzle, 0.00042, 100.0)
	var at_300 := BallisticsSolver.velocity_after_distance(muzzle, 0.00042, 300.0)
	_expect(at_100 < muzzle and at_300 < at_100 and at_300 > 0.0, "Projectile velocity must decay monotonically.")


func _test_weapon_mass_conversion() -> void:
	var weapon: WeaponDefinition = load("res://scripts/data/anadolu_308.tres")
	_expect(absf(weapon.projectile_mass_kg() - 0.0097198) < 0.00001, "150 grain projectile conversion is incorrect.")


func _test_damage_lifecycle() -> void:
	var health := HealthComponent.new()
	health.maximum_health = 100.0
	health.reset()
	var info := DamageInfo.new()
	_expect(health.apply_damage(40.0, info), "Positive damage should be applied.")
	_expect(is_equal_approx(health.current_health, 60.0), "Health should retain the remaining value.")
	health.apply_damage(80.0, info)
	_expect(health.is_dead and is_zero_approx(health.current_health), "Lethal damage should produce a stable dead state.")
	_expect(not health.apply_damage(10.0, info), "Dead targets must reject repeated damage.")
	health.free()


func _test_input_edge_consumption() -> void:
	InputRouter.clear_gameplay_input()
	InputRouter.set_action(&"test_action", true)
	InputRouter.set_action(&"test_action", false)
	_expect(InputRouter.consume_action_pressed(&"test_action"), "Touch press edge should survive button release.")
	_expect(not InputRouter.consume_action_pressed(&"test_action"), "Touch press edge must be consumed exactly once.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

