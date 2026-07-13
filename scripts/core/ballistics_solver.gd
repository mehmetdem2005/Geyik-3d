class_name BallisticsSolver
extends RefCounted

const EARTH_GRAVITY := 9.80665


static func trajectory_position(
	origin: Vector3,
	direction: Vector3,
	muzzle_velocity: float,
	gravity_scale: float,
	wind_acceleration: Vector3,
	time_seconds: float
) -> Vector3:
	var initial_velocity := direction.normalized() * muzzle_velocity
	var acceleration := Vector3.DOWN * EARTH_GRAVITY * gravity_scale + wind_acceleration
	return origin + initial_velocity * time_seconds + 0.5 * acceleration * time_seconds * time_seconds


static func sample_trajectory(
	origin: Vector3,
	direction: Vector3,
	muzzle_velocity: float,
	gravity_scale: float,
	wind_acceleration: Vector3,
	max_range: float,
	step_seconds := 0.015
) -> PackedVector3Array:
	var points := PackedVector3Array([origin])
	var time := step_seconds
	var travelled := 0.0
	var previous := origin
	while travelled < max_range:
		var current := trajectory_position(origin, direction, muzzle_velocity, gravity_scale, wind_acceleration, time)
		travelled += previous.distance_to(current)
		points.append(current)
		previous = current
		time += step_seconds
	return points


static func kinetic_energy_joules(projectile_mass_kg: float, velocity_mps: float) -> float:
	return 0.5 * projectile_mass_kg * velocity_mps * velocity_mps


static func velocity_after_distance(muzzle_velocity: float, drag_coefficient: float, distance_meters: float) -> float:
	return muzzle_velocity * exp(-maxf(0.0, drag_coefficient) * maxf(0.0, distance_meters))


static func estimate_flight_time(distance_meters: float, muzzle_velocity: float, drag_coefficient: float) -> float:
	var average_velocity := (muzzle_velocity + velocity_after_distance(muzzle_velocity, drag_coefficient, distance_meters)) * 0.5
	return distance_meters / maxf(average_velocity, 1.0)

