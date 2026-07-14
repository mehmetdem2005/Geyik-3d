class_name WeaponDefinition
extends Resource

@export_category("Identity")
@export var display_name := "Anadolu .308"

@export_category("Magazine")
@export_range(1, 30, 1) var magazine_size := 5
@export_range(0, 200, 1) var starting_reserve := 20
@export_range(0.1, 5.0, 0.05) var fire_interval := 0.82
@export_range(0.1, 8.0, 0.05) var reload_duration := 2.45

@export_category("Ballistics")
@export_range(50.0, 1500.0, 1.0) var muzzle_velocity := 815.0
@export_range(20.0, 800.0, 1.0) var max_range := 520.0
@export_range(0.0, 0.01, 0.00001) var drag_coefficient := 0.00042
@export_range(20.0, 300.0, 1.0) var zero_range := 100.0
@export_range(20.0, 400.0, 1.0) var projectile_mass_grains := 150.0
@export_range(0.0, 2.0, 0.01) var gravity_scale := 1.0
@export_range(1.0, 200.0, 1.0) var base_damage := 62.0

@export_category("Handling")
@export_range(0.0, 10.0, 0.05) var hip_spread_degrees := 1.8
@export_range(0.0, 2.0, 0.01) var aimed_spread_degrees := 0.08
@export_range(1.0, 120.0, 1.0) var scope_fov := 17.0
@export_range(0.0, 10.0, 0.05) var recoil_pitch_degrees := 2.2
@export_range(0.0, 200.0, 1.0) var report_loudness := 145.0


func projectile_mass_kg() -> float:
	return projectile_mass_grains * 0.00006479891

