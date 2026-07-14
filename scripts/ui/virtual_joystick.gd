class_name HuntVirtualJoystick
extends Control

@export var radius := 70.0
@export var deadzone := 0.12

var _finger_id := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _mouse_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_center = Vector2(minf(150.0, size.x * 0.28), maxf(radius + 24.0, size.y - 145.0))
	_knob = _center
	queue_redraw()


func _begin(position: Vector2) -> void:
	_center = position
	_knob = position
	InputRouter.set_move_vector(Vector2.ZERO, true)
	queue_redraw()


func _update_stick(position: Vector2) -> void:
	var offset := (position - _center).limit_length(radius)
	_knob = _center + offset
	var normalized := offset / radius
	if normalized.length() < deadzone:
		normalized = Vector2.ZERO
	InputRouter.set_move_vector(normalized, true)
	queue_redraw()


func _end() -> void:
	_finger_id = -1
	_mouse_active = false
	InputRouter.release_move()
	queue_redraw()
