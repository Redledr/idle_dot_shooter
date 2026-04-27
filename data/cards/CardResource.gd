extends Resource
class_name CardResource

const CardEffectResource = preload("res://data/cards/CardEffectResource.gd")

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
@export var category: String = "wildcard"
@export var effects: Array[CardEffectResource] = []
@export var tags: PackedStringArray = PackedStringArray()


func to_card_dict() -> Dictionary:
	var primary_effect: Dictionary = {}
	if not effects.is_empty() and effects[0] != null:
		primary_effect = effects[0].to_effect_dict()

	var effect_dicts: Array = []
	for effect in effects:
		if effect != null:
			effect_dicts.append(effect.to_effect_dict())

	return {
		"id": id,
		"name": display_name,
		"description": description,
		"rarity": rarity,
		"category": category,
		"effect_key": primary_effect.get("effect_type", ""),
		"effect_value": primary_effect.get("value", 0.0),
		"effects": effect_dicts,
		"tags": Array(tags),
	}
