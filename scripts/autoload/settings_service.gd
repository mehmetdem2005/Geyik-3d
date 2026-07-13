extends Node

const SETTINGS_PATH := "user://settings.json"

const DEFAULTS := {
	"master_volume": 0.82,
	"sfx_volume": 0.9,
	"ambience_volume": 0.72,
	"mouse_sensitivity": 0.0022,
	"touch_sensitivity": 0.0038,
	"field_of_view": 75.0,
	"camera_bob": 0.65,
	"fullscreen": true,
	"render_scale": 0.85,
	"vegetation_quality": 1,
}

var _settings: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	_load_settings()
	_apply_window_mode()
	call_deferred("_announce_settings")


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _settings.get(String(key), DEFAULTS.get(String(key), fallback))


func get_all() -> Dictionary:
	return _settings.duplicate(true)


func set_value(key: StringName, value: Variant, persist := true) -> void:
	var normalized_key := String(key)
	if not DEFAULTS.has(normalized_key):
		push_warning("Unknown setting ignored: %s" % normalized_key)
		return
	_settings[normalized_key] = value
	if normalized_key == "fullscreen":
		_apply_window_mode()
	if persist:
		_save_settings()
	EventBus.settings_changed.emit(get_all())


func reset_to_defaults() -> void:
	_settings = DEFAULTS.duplicate(true)
	_apply_window_mode()
	_save_settings()
	EventBus.settings_changed.emit(get_all())


func _announce_settings() -> void:
	EventBus.settings_changed.emit(get_all())


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Settings could not be opened: %s" % FileAccess.get_open_error())
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("Settings file is invalid; defaults will be used.")
		return
	for key in DEFAULTS:
		if parsed.has(key):
			_settings[key] = parsed[key]


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Settings could not be saved: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(_settings, "\t"))


func _apply_window_mode() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if bool(_settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
