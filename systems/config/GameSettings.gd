extends RefCounted

const SETTINGS_PATH := "user://settings.json"

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"fullscreen": false,
	"particles_enabled": true,
	"resolution_index": 0,
	"show_fps": false,
	"show_cpu": false,
}


static func load_settings() -> Dictionary:
	var settings := DEFAULT_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return settings

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return settings

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in settings.keys():
			settings[key] = parsed.get(key, settings[key])

	return settings


static func save_settings(settings: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()


static func apply_display_and_audio(settings: Dictionary) -> void:
	var volume := clampf(float(settings.get("master_volume", 1.0)), 0.0001, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))

	if bool(settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
