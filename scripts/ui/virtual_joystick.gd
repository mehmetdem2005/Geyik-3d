class_name HuntVirtualJoystick
extends Control

@export var radius := 70.0
@export var deadzone := 0.12
@export var center_from_bottom_left := Vector2(112.0, 116.0)

var _finger_id := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _mouse_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	set_process_unhandled_input(false)
	resized.connect(_reset_idle_center)
	call_deferred("_reset_idle_center")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			_begin(event.position)
			accept_event()
		elif not event.pressed and event.index == _finger_id:
			_end()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		_update_stick(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_begin(event.position)
		else:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_stick(event.position)
		accept_event()


func _draw() -> void:
	var active := _finger_id != -1 or _mouse_active
	draw_circle(_center, radius, Color(0.04, 0.07, 0.06, 0.48 if active else 0.28))
	draw_arc(_center, radius, 0.0, TAU, 48, Color(0.89, 0.82, 0.67, 0.55 if active else 0.34), 3.0, true)
	draw_circle(_knob, radius * 0.39, Color(0.88, 0.82, 0.69, 0.72 if active else 0.44))
	draw_arc(_knob, radius * 0.39, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.62 if active else 0.4), 2.0, true)


func _reset_idle_center() -> void:
	if _finger_id != -1 or _mouse_active or size.is_zero_approx():
		return
	_center = fixed_center_for_size(size, center_from_bottom_left, radius)
	_knob = _center
	queue_redraw()


func _begin(position: Vector2) -> void:
	# The movement control is deliberately fixed in the lower-left corner. This
	# keeps muscle memory stable and prevents a second touch from moving the base.
	_center = fixed_center_for_size(size, center_from_bottom_left, radius)
	_update_stick(position)


func _update_stick(position: Vector2) -> void:
	var offset := (position - _center).limit_length(radius)
	_knob = _center + offset
	var normalized := vector_from_touch(position, _center, radius, deadzone)
	InputRouter.set_move_vector(normalized, true)
	queue_redraw()


func _end() -> void:
	_finger_id = -1
	_mouse_active = false
	_center = fixed_center_for_size(size, center_from_bottom_left, radius)
	_knob = _center
	InputRouter.release_move()
	queue_redraw()


static func fixed_center_for_size(control_size: Vector2, offset: Vector2, minimum_radius: float) -> Vector2:
	return Vector2(
		clampf(offset.x, minimum_radius + 8.0, control_size.x - minimum_radius - 8.0),
		clampf(control_size.y - offset.y, minimum_radius + 8.0, control_size.y - minimum_radius - 8.0)
	)


static func vector_from_touch(position: Vector2, center: Vector2, maximum_radius: float, input_deadzone: float) -> Vector2:
	if maximum_radius <= 0.0:
		return Vector2.ZERO
	var raw := (position - center) / maximum_radius
	var strength := minf(raw.length(), 1.0)
	if strength <= input_deadzone:
		return Vector2.ZERO
	var remapped_strength := inverse_lerp(input_deadzone, 1.0, strength)
	return raw.normalized() * remapped_strength
