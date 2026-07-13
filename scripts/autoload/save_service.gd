extends Node

const SAVE_PATH := "user://geyik_3d_save.json"
const TEMP_PATH := "user://geyik_3d_save.tmp"
const CURRENT_SCHEMA_VERSION := 1


func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _default_progress()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Save file could not be opened: %s" % FileAccess.get_open_error())
		return _default_progress()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		_backup_corrupt_save()
		return _default_progress()
	return _migrate(parsed)


func save_progress(progress: Dictionary) -> bool:
	var payload := progress.duplicate(true)
	payload["schema_version"] = CURRENT_SCHEMA_VERSION
	payload["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_error("Could not create temporary save file.")
		return false
	temp_file.store_string(JSON.stringify(payload, "\t"))
	temp_file.close()
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(absolute_save)
	var result := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if result != OK:
		push_error("Atomic save rename failed with code %s." % result)
		return false
	return true


func _default_progress() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"best_score": 0,
		"best_trophy": 0.0,
		"successful_hunts": 0,
		"total_harvests": 0,
	}


func _migrate(raw: Dictionary) -> Dictionary:
	var migrated := _default_progress()
	for key in migrated:
		if raw.has(key):
			migrated[key] = raw[key]
	return migrated


func _backup_corrupt_save() -> void:
	var source := ProjectSettings.globalize_path(SAVE_PATH)
	var backup := "%s.corrupt.%s" % [source, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(source, backup)
