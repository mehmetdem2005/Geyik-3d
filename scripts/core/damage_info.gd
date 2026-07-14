class_name DamageInfo
extends RefCounted

var source: Node
var world_position := Vector3.ZERO
var direction := Vector3.FORWARD
var distance_meters := 0.0
var energy_joules := 0.0
var base_damage := 0.0
var hit_zone: StringName = &"body"


func to_dictionary() -> Dictionary:
	return {
		"world_position": world_position,
		"direction": direction,
		"distance_meters": distance_meters,
		"energy_joules": energy_joules,
		"base_damage": base_damage,
		"hit_zone": hit_zone,
	}

