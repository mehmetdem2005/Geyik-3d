class_name HealthComponent
extends Node

signal damaged(amount: float, remaining: float, info: DamageInfo)
signal died(info: DamageInfo)

@export var maximum_health := 100.0
var current_health := 100.0
var is_dead := false


func _ready() -> void:
	current_health = maximum_health


func reset() -> void:
	current_health = maximum_health
	is_dead = false


func apply_damage(amount: float, info: DamageInfo) -> bool:
	if is_dead or amount <= 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, current_health, info)
	if is_zero_approx(current_health):
		is_dead = true
		died.emit(info)
	return true

