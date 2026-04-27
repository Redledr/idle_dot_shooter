extends SceneTree

const CARD_JSON_PATH := "res://data/runtime/cards.json"
const CARD_OUTPUT_DIR := "res://data/cards"
const CardResource = preload("res://data/cards/CardResource.gd")
const CardEffectResource = preload("res://data/cards/CardEffectResource.gd")


func _initialize() -> void:
	var cards := _load_legacy_cards()
	if cards.is_empty():
		push_error("No cards found in legacy JSON")
		quit(1)
		return

	_ensure_output_dir()

	for card_data in cards:
		var card_resource := CardResource.new()
		card_resource.id = String(card_data.get("id", ""))
		card_resource.display_name = String(card_data.get("name", ""))
		card_resource.description = String(card_data.get("description", ""))
		card_resource.rarity = String(card_data.get("rarity", "common"))
		card_resource.category = String(card_data.get("category", "wildcard"))
		card_resource.effects = _build_effect_resources(card_data)

		var output_path := "%s/%s.tres" % [CARD_OUTPUT_DIR, card_resource.id]
		var save_result := ResourceSaver.save(card_resource, output_path)
		if save_result != OK:
			push_error("Failed to save %s: %s" % [output_path, error_string(save_result)])
			quit(1)
			return

	print("migrated_cards=%d" % cards.size())
	quit()


func _load_legacy_cards() -> Array:
	if not FileAccess.file_exists(CARD_JSON_PATH):
		return []

	var file := FileAccess.open(CARD_JSON_PATH, FileAccess.READ)
	if file == null:
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("cards"):
		return parsed["cards"]
	return []


func _ensure_output_dir() -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		return

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(CARD_OUTPUT_DIR)):
		dir.make_dir_recursive(CARD_OUTPUT_DIR)


func _build_effect_resources(card_data: Dictionary) -> Array[CardEffectResource]:
	var effect := CardEffectResource.new()
	effect.effect_type = String(card_data.get("effect_key", ""))
	effect.value = float(card_data.get("effect_value", 0.0))
	effect.metadata = {
		"legacy_category": String(card_data.get("category", "")),
		"legacy_rarity": String(card_data.get("rarity", "")),
	}
	return [effect]
