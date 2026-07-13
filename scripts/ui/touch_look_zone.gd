class_name TouchLookZone
extends Control

var _finger_id := -1
var _mouse_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			accept_event()
		elif not event.pressed and event.index == _finger_id:
			_finger_id = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		InputRouter.add_look_delta(event.relative)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		InputRouter.add_look_delta(event.relative)
		accept_event()

