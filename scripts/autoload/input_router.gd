extends Node

## Unified input boundary. Mobile controls write normalized values here while
## gameplay reads actions without knowing whether they came from touch, a test,
## or the optional editor keyboard fallback.

var _move_vector := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _touch_move_active := false
var _actions_held: Dictionary = {}
var _actions_pressed: Dictionary = {}


func set_move_vector(value: Vector2, active := true) -> void:
	_move_vector = value.limit_length(1.0)
	_touch_move_active = active


func release_move() -> void:
	_move_vector = Vector2.ZERO
	_touch_move_active = false


func get_move_vector() -> Vector2:
	if _touch_move_active:
		return _move_vector
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func add_look_delta(delta: Vector2) -> void:
	_look_delta += delta


func consume_look_delta() -> Vector2:
	var result := _look_delta
	_look_delta = Vector2.ZERO
	return result


func set_action(action: StringName, pressed: bool) -> void:
	var was_pressed := bool(_actions_held.get(action, false))
	_actions_held[action] = pressed
	if pressed and not was_pressed:
		_actions_pressed[action] = true


func pulse_action(action: StringName) -> void:
	## Records a one-shot touch action without relying on a later release event.
	## This is important on Android when a second finger leaves the screen first.
	_actions_pressed[action] = true


func toggle_action(action: StringName) -> bool:
	var next_value := not bool(_actions_held.get(action, false))
	set_action(action, next_value)
	return next_value


func is_action_held(action: StringName) -> bool:
	var keyboard_or_gamepad := Input.is_action_pressed(action) if InputMap.has_action(action) else false
	return bool(_actions_held.get(action, false)) or keyboard_or_gamepad


func consume_action_pressed(action: StringName) -> bool:
	if bool(_actions_pressed.get(action, false)):
		_actions_pressed[action] = false
		return true
	return Input.is_action_just_pressed(action) if InputMap.has_action(action) else false


func clear_gameplay_input() -> void:
	_move_vector = Vector2.ZERO
	_look_delta = Vector2.ZERO
	_touch_move_active = false
	_actions_held.clear()
	_actions_pressed.clear()
