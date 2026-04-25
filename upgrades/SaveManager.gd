extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1




func save_game(currency: float, dots_destroyed: int) -> void:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"currency": currency,
		"dots_destroyed": dots_destroyed,
		"upgrade_levels": UpgradeManager.levels.duplicate(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open save file for reading")
		return {}

	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("SaveManager: corrupt save file")
		return {}

	return parsed


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Returns offline earnings and elapsed seconds.
## Caller is responsible for applying the currency.
func calculate_offline_progress(saved_timestamp: float) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var elapsed := now - saved_timestamp

	# Cap offline time at 4 hours so early players aren't overwhelmed
	var capped := minf(elapsed, 4.0 * 3600.0)

	# Estimate kills per second based on current upgrade state
	var kills_per_second := _estimate_kills_per_second()
	var offline_kills := int(kills_per_second * capped)
	var offline_currency := offline_kills * UpgradeManager.get_dot_value()

	return {
		"elapsed_seconds": elapsed,
		"capped_seconds": capped,
		"kills": offline_kills,
		"currency": offline_currency,
	}


func _estimate_kills_per_second() -> float:
	# Bullets fired per second * hit probability (assume ~70% hit rate on static dots)
	var fire_rate := UpgradeManager.get_fire_rate()
	var hit_chance := 0.70
	return fire_rate * hit_chance
