extends RefCounted

const CardResource = preload("res://data/cards/CardResource.gd")
const CardEffectResource = preload("res://data/cards/CardEffectResource.gd")


static func from_legacy_card(card_data: Dictionary) -> CardResource:
	var card_resource := CardResource.new()
	populate_card_resource(card_resource, card_data)
	return card_resource


static func populate_card_resource(card_resource: CardResource, card_data: Dictionary) -> CardResource:
	card_resource.id = String(card_data.get("id", ""))
	card_resource.display_name = String(card_data.get("display_name", card_data.get("name", "")))
	card_resource.description = String(card_data.get("description", ""))
	card_resource.rarity = String(card_data.get("rarity", "common"))
	card_resource.category = String(card_data.get("category", "wildcard"))
	card_resource.tags = PackedStringArray(card_data.get("tags", []))
	card_resource.effects = build_effect_resources(card_data)
	return card_resource


static func build_effect_resources(card_data: Dictionary) -> Array[CardEffectResource]:
	var effect_resources: Array[CardEffectResource] = []
	var effect_dicts: Array = card_data.get("effects", [])

	if effect_dicts.is_empty():
		var legacy_key: String = String(card_data.get("effect_key", ""))
		if not legacy_key.is_empty():
			effect_dicts = [{
				"effect_type": legacy_key,
				"value": float(card_data.get("effect_value", 0.0)),
				"metadata": {
					"legacy_category": String(card_data.get("category", "wildcard")),
					"legacy_rarity": String(card_data.get("rarity", "common")),
				}
			}]

	for effect_data in effect_dicts:
		if effect_data is Dictionary:
			effect_resources.append(_build_effect_resource(effect_data as Dictionary))

	return effect_resources


static func _build_effect_resource(effect_data: Dictionary) -> CardEffectResource:
	var effect_resource := CardEffectResource.new()
	effect_resource.effect_type = String(effect_data.get("effect_type", ""))
	effect_resource.element = StringName(String(effect_data.get("element", "")))
	effect_resource.value = float(effect_data.get("value", 0.0))
	effect_resource.duration = float(effect_data.get("duration", 0.0))
	effect_resource.radius = float(effect_data.get("radius", 0.0))
	effect_resource.stacks = int(effect_data.get("stacks", 1))
	effect_resource.interval = int(effect_data.get("interval", 0))
	effect_resource.operation = String(effect_data.get("operation", ""))
	effect_resource.property_name = StringName(String(effect_data.get("property_name", "")))
	effect_resource.upgrade_id = StringName(String(effect_data.get("upgrade_id", "")))
	effect_resource.metadata = (effect_data.get("metadata", {}) as Dictionary).duplicate(true)
	return effect_resource
